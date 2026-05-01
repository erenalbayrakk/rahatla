import { Inject, Logger, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { GroupChatService } from '../group-chat/group-chat.service';
import { JwtPayload } from '../auth/strategies/jwt.strategy';
import { SessionsService } from '../sessions/sessions.service';
import { PresenceService } from './presence.service';

type TypingKey = string;

interface AuthenticatedSocketData {
  userId: string;
  joinedRooms: string[];
}

function socketData(client: Socket): AuthenticatedSocketData {
  return client.data as AuthenticatedSocketData;
}

@WebSocketGateway({
  namespace: '/realtime',
  cors: { origin: true, credentials: true },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly log = new Logger(ChatGateway.name);
  /** Docker / API loglarında `GroupChat` ile filtrele (mobil teşhis korelasyonu). */
  private readonly groupDiag = new Logger('GroupChat');
  private readonly typingTimers = new Map<TypingKey, NodeJS.Timeout>();

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    @Inject(forwardRef(() => SessionsService))
    private readonly sessions: SessionsService,
    private readonly groups: GroupChatService,
    private readonly presence: PresenceService,
  ) {}

  /** HTTP üzerinden oluşan sohbet mesajlarını odaya yayınlar. */
  broadcastSessionMessage(sessionId: string, message: unknown) {
    this.server.to(`session:${sessionId}`).emit('session:message', message);
  }

  handleConnection(client: Socket) {
    try {
      const raw =
        (client.handshake.auth?.token as string | undefined) ||
        client.handshake.headers.authorization;
      if (!raw) {
        client.disconnect(true);
        return;
      }
      const token = raw.replace(/^Bearer\s+/i, '').trim();
      const payload = this.jwt.verify<JwtPayload>(token, {
        secret: this.config.getOrThrow<string>('JWT_SECRET'),
      });
      const data = socketData(client);
      data.userId = payload.sub;
      data.joinedRooms = [];
      this.presence.handleSocketConnected(payload.sub);
    } catch (e) {
      this.log.warn(`Socket auth failed: ${e}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const d = socketData(client);
    if (d.userId) {
      this.presence.handleSocketDisconnected(d.userId);
    }
    const rooms = d.joinedRooms ?? [];
    if (d.userId) {
      for (const r of rooms) {
        this.clearTypingForUser(r, d.userId);
      }
    }
  }

  @SubscribeMessage('session:join')
  async onSessionJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { sessionId: string },
  ) {
    const userId = socketData(client).userId;
    await this.sessions.assertSessionParticipant(body.sessionId, userId);
    const room = `session:${body.sessionId}`;
    await client.join(room);
    socketData(client).joinedRooms.push(room);
    return { ok: true };
  }

  @SubscribeMessage('session:message')
  async onSessionMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: { sessionId: string; content: string; clientMessageId?: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.sessions.addMessage(body.sessionId, userId, {
      content: body.content,
      clientMessageId: body.clientMessageId,
    });
    this.server.to(`session:${body.sessionId}`).emit('session:message', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('session:image')
  async onSessionImage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: { sessionId: string; imageUrl: string; clientMessageId?: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.sessions.addMessage(body.sessionId, userId, {
      messageType: 'image',
      content: '',
      imageUrl: body.imageUrl,
      clientMessageId: body.clientMessageId,
    });
    this.server.to(`session:${body.sessionId}`).emit('session:message', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('session:gift')
  async onSessionGift(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { sessionId: string; giftCode: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.sessions.recordGiftAndSystemMessage(
      body.sessionId,
      userId,
      body.giftCode,
    );
    return { ok: true, message: msg };
  }

  @SubscribeMessage('session:typing')
  onSessionTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { sessionId: string; isTyping: boolean },
  ) {
    const userId = socketData(client).userId;
    const room = `session:${body.sessionId}`;
    const key = `${room}:${userId}`;
    const existing = this.typingTimers.get(key);
    if (existing) clearTimeout(existing);
    if (body.isTyping) {
      const t = setTimeout(() => {
        this.typingTimers.delete(key);
        this.server.to(room).emit('session:typing', {
          sessionId: body.sessionId,
          userId,
          isTyping: false,
        });
      }, 4000);
      this.typingTimers.set(key, t);
    }
    client.to(room).emit('session:typing', {
      sessionId: body.sessionId,
      userId,
      isTyping: body.isTyping,
    });
    return { ok: true };
  }

  @SubscribeMessage('session:delivered')
  async onSessionDelivered(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { sessionId: string; messageId: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.sessions.markSessionMessageDelivered(
      body.sessionId,
      body.messageId,
      userId,
    );
    this.server.to(`session:${body.sessionId}`).emit('session:delivered', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('session:read')
  async onSessionRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { sessionId: string; messageId: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.sessions.markSessionMessageRead(
      body.sessionId,
      body.messageId,
      userId,
    );
    this.server.to(`session:${body.sessionId}`).emit('session:read', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('group:join')
  async onGroupJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: string },
  ) {
    const userId = socketData(client).userId;
    await this.groups.assertGroupParticipant(body.roomId, userId);
    const room = `group:${body.roomId}`;
    await client.join(room);
    socketData(client).joinedRooms.push(room);
    this.groupDiag.log(
      `join ok roomId=${body.roomId} userId=${userId} socket=${client.id}`,
    );
    return { ok: true };
  }

  @SubscribeMessage('group:message')
  async onGroupMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: { roomId: string; content: string; clientMessageId?: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.groups.addGroupMessage(body.roomId, userId, {
      messageType: 'text',
      content: body.content,
      clientMessageId: body.clientMessageId,
    });
    this.groupDiag.log(
      `message saved roomId=${body.roomId} messageId=${msg.id} userId=${userId} emitBroadcast`,
    );
    this.server.to(`group:${body.roomId}`).emit('group:message', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('group:image')
  async onGroupImage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: { roomId: string; imageUrl: string; clientMessageId?: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.groups.addGroupMessage(body.roomId, userId, {
      messageType: 'image',
      imageUrl: body.imageUrl,
      clientMessageId: body.clientMessageId,
    });
    this.groupDiag.log(
      `image saved roomId=${body.roomId} messageId=${msg.id} userId=${userId} emitBroadcast`,
    );
    this.server.to(`group:${body.roomId}`).emit('group:message', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('group:typing')
  onGroupTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: string; isTyping: boolean },
  ) {
    const userId = socketData(client).userId;
    const room = `group:${body.roomId}`;
    const key = `${room}:${userId}`;
    const existing = this.typingTimers.get(key);
    if (existing) clearTimeout(existing);
    if (body.isTyping) {
      const t = setTimeout(() => {
        this.typingTimers.delete(key);
        this.server.to(room).emit('group:typing', {
          roomId: body.roomId,
          userId,
          isTyping: false,
        });
      }, 4000);
      this.typingTimers.set(key, t);
    }
    client.to(room).emit('group:typing', {
      roomId: body.roomId,
      userId,
      isTyping: body.isTyping,
    });
    this.log.debug(
      `[GroupChat] typing roomId=${body.roomId} userId=${userId} isTyping=${body.isTyping}`,
    );
    return { ok: true };
  }

  @SubscribeMessage('group:delivered')
  async onGroupDelivered(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: string; messageId: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.groups.markGroupMessageDelivered(
      body.roomId,
      body.messageId,
      userId,
    );
    this.groupDiag.log(
      `ws delivered broadcast roomId=${body.roomId} messageId=${body.messageId}`,
    );
    this.server.to(`group:${body.roomId}`).emit('group:delivered', msg);
    return { ok: true, message: msg };
  }

  @SubscribeMessage('group:read')
  async onGroupRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: string; messageId: string },
  ) {
    const userId = socketData(client).userId;
    const msg = await this.groups.markGroupMessageRead(
      body.roomId,
      body.messageId,
      userId,
    );
    this.groupDiag.log(
      `ws read broadcast roomId=${body.roomId} messageId=${body.messageId}`,
    );
    this.server.to(`group:${body.roomId}`).emit('group:read', msg);
    return { ok: true, message: msg };
  }

  private clearTypingForUser(room: string, userId: string) {
    const key = `${room}:${userId}`;
    const t = this.typingTimers.get(key);
    if (t) clearTimeout(t);
    this.typingTimers.delete(key);
  }
}
