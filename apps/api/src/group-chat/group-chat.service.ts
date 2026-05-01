import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  GroupChatParticipantRole,
  MessageType,
  Prisma,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const groupMessageSelect = {
  id: true,
  roomId: true,
  senderId: true,
  messageType: true,
  content: true,
  imageUrl: true,
  clientMessageId: true,
  deliveredAt: true,
  readAt: true,
  hiddenByModeration: true,
  createdAt: true,
} as const;

function inboxPreviewFromGroupMessage(
  msg: {
    messageType: MessageType;
    content: string | null;
    imageUrl: string | null;
  } | null,
): string | null {
  if (!msg) return null;
  switch (msg.messageType) {
    case 'image':
      return 'Fotoğraf';
    case 'audio':
      return 'Sesli mesaj';
    case 'system':
      return msg.content?.trim()
        ? msg.content.trim().slice(0, 120)
        : 'Bildirim';
    case 'text':
    default:
      return msg.content?.trim() ? msg.content.trim().slice(0, 120) : null;
  }
}

@Injectable()
export class GroupChatService {
  private readonly logger = new Logger(GroupChatService.name);

  constructor(private readonly prisma: PrismaService) {}

  async createRoom(adminId: string, title: string, description?: string) {
    return this.prisma.groupChatRoom.create({
      data: {
        title: title.trim(),
        description: description?.trim() || null,
        createdById: adminId,
        status: 'open',
      },
      select: {
        id: true,
        title: true,
        description: true,
        status: true,
        createdById: true,
        createdAt: true,
      },
    });
  }

  async listRoomsAdmin() {
    return this.prisma.groupChatRoom.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { participants: true, messages: true } },
      },
    });
  }

  async addParticipant(
    roomId: string,
    userId: string,
    role: GroupChatParticipantRole,
  ) {
    const room = await this.prisma.groupChatRoom.findUnique({
      where: { id: roomId },
    });
    if (!room) throw new NotFoundException('Oda bulunamadı');
    if (room.status !== 'open') {
      throw new ConflictException('Oda kapalı');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, status: true },
    });
    if (!user || user.status !== 'active') {
      throw new NotFoundException('Kullanıcı bulunamadı');
    }
    if (role === 'listener' && user.role !== UserRole.approved_listener) {
      throw new BadRequestException(
        'Dinleyen rolü yalnızca onaylı dinleyenlere verilir',
      );
    }
    if (role === 'moderator' && user.role !== UserRole.admin) {
      throw new BadRequestException(
        'Moderatör rolü yalnızca admin hesaplarına verilir',
      );
    }

    const existing = await this.prisma.groupChatParticipant.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (existing) {
      if (existing.leftAt == null) {
        throw new ConflictException('Kullanıcı zaten odada');
      }
      return this.prisma.groupChatParticipant.update({
        where: { id: existing.id },
        data: {
          leftAt: null,
          removedReason: null,
          role,
          joinedAt: new Date(),
        },
        select: {
          id: true,
          roomId: true,
          userId: true,
          role: true,
          joinedAt: true,
        },
      });
    }

    return this.prisma.groupChatParticipant.create({
      data: { roomId, userId, role },
      select: {
        id: true,
        roomId: true,
        userId: true,
        role: true,
        joinedAt: true,
      },
    });
  }

  async removeParticipant(
    roomId: string,
    targetUserId: string,
    reason?: string,
  ) {
    const p = await this.prisma.groupChatParticipant.findUnique({
      where: { roomId_userId: { roomId, userId: targetUserId } },
    });
    if (!p || p.leftAt) {
      throw new NotFoundException('Katılımcı bulunamadı');
    }
    return this.prisma.groupChatParticipant.update({
      where: { id: p.id },
      data: {
        leftAt: new Date(),
        removedReason: reason?.trim() || 'removed_by_admin',
      },
    });
  }

  async closeRoom(roomId: string) {
    const room = await this.prisma.groupChatRoom.findUnique({
      where: { id: roomId },
    });
    if (!room) throw new NotFoundException('Oda bulunamadı');
    return this.prisma.groupChatRoom.update({
      where: { id: roomId },
      data: { status: 'closed', closedAt: new Date() },
      select: {
        id: true,
        status: true,
        closedAt: true,
      },
    });
  }

  async listMessagesAdmin(roomId: string) {
    return this.prisma.groupChatMessage.findMany({
      where: { roomId },
      orderBy: { createdAt: 'asc' },
      select: groupMessageSelect,
    });
  }

  async setMessageModeration(
    roomId: string,
    messageId: string,
    hidden: boolean,
  ) {
    const msg = await this.prisma.groupChatMessage.findFirst({
      where: { id: messageId, roomId },
    });
    if (!msg) throw new NotFoundException('Mesaj bulunamadı');
    return this.prisma.groupChatMessage.update({
      where: { id: messageId },
      data: { hiddenByModeration: hidden },
      select: groupMessageSelect,
    });
  }

  async assertGroupParticipant(roomId: string, userId: string) {
    const p = await this.prisma.groupChatParticipant.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!p || p.leftAt) {
      throw new ForbiddenException('Bu gruba erişimin yok');
    }
    const room = await this.prisma.groupChatRoom.findUnique({
      where: { id: roomId },
    });
    if (!room || room.status !== 'open') {
      throw new ForbiddenException('Oda kapalı veya yok');
    }
    return { participant: p, room };
  }

  isModerator(role: GroupChatParticipantRole) {
    return role === 'moderator';
  }

  async listMyRooms(userId: string) {
    const rows = await this.prisma.groupChatParticipant.findMany({
      where: { userId, leftAt: null },
      include: {
        room: {
          select: {
            id: true,
            title: true,
            description: true,
            status: true,
            createdAt: true,
          },
        },
      },
    });
    const open = rows.filter((r) => r.room.status === 'open');
    const roomIds = open.map((r) => r.room.id);
    const lastByRoom = new Map<
      string,
      {
        messageType: MessageType;
        content: string | null;
        imageUrl: string | null;
        createdAt: Date;
      } | null
    >();
    if (roomIds.length > 0) {
      const lasts = await Promise.all(
        roomIds.map((roomId) =>
          this.prisma.groupChatMessage.findFirst({
            where: { roomId, hiddenByModeration: false },
            orderBy: { createdAt: 'desc' },
            select: {
              messageType: true,
              content: true,
              imageUrl: true,
              createdAt: true,
            },
          }),
        ),
      );
      for (let i = 0; i < roomIds.length; i++) {
        lastByRoom.set(roomIds[i], lasts[i]);
      }
    }
    return open.map((r) => {
      const last = lastByRoom.get(r.room.id) ?? null;
      return {
        ...r.room,
        myRole: r.role,
        lastMessageAt: last?.createdAt.toISOString() ?? null,
        lastMessagePreview: inboxPreviewFromGroupMessage(last),
      };
    });
  }

  /** Açık odaları keşfet: karışık sıra, üye olmayanlar da görebilir (katılım admin ile). */
  private static readonly DISCOVER_PAGE_SIZE = 10;

  async listDiscoverRooms(userId: string, pageRaw?: number) {
    const page = Math.max(1, pageRaw ?? 1);
    const pageSize = GroupChatService.DISCOVER_PAGE_SIZE;
    const total = await this.prisma.groupChatRoom.count({
      where: { status: 'open' },
    });
    const rooms = await this.prisma.groupChatRoom.findMany({
      where: { status: 'open' },
      select: {
        id: true,
        title: true,
        description: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });
    if (rooms.length === 0) {
      return { items: [], page, pageSize, total };
    }
    const roomIds = rooms.map((r) => r.id);
    const [counts, myMembership, pendingJoins] = await Promise.all([
      this.prisma.groupChatParticipant.groupBy({
        by: ['roomId'],
        where: { roomId: { in: roomIds }, leftAt: null },
        _count: { _all: true },
      }),
      this.prisma.groupChatParticipant.findMany({
        where: {
          userId,
          roomId: { in: roomIds },
          leftAt: null,
        },
        select: { roomId: true },
      }),
      this.prisma.groupChatJoinRequest.findMany({
        where: {
          userId,
          status: 'pending',
          roomId: { in: roomIds },
        },
        select: { roomId: true },
      }),
    ]);
    const countMap = new Map(counts.map((c) => [c.roomId, c._count._all]));
    const memberSet = new Set(myMembership.map((m) => m.roomId));
    const pendingSet = new Set(pendingJoins.map((p) => p.roomId));

    const mapped = rooms.map((r) => ({
      id: r.id,
      title: r.title,
      description: r.description,
      createdAt: r.createdAt,
      participantCount: countMap.get(r.id) ?? 0,
      isMember: memberSet.has(r.id),
      hasPendingRequest: pendingSet.has(r.id),
    }));

    if (page === 1 && mapped.length > 1) {
      for (let i = mapped.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [mapped[i], mapped[j]] = [mapped[j], mapped[i]];
      }
    }
    return { items: mapped, page, pageSize, total };
  }

  async getRoomForUser(roomId: string, userId: string) {
    const { participant, room } = await this.assertGroupParticipant(
      roomId,
      userId,
    );

    const rows = await this.prisma.groupChatParticipant.findMany({
      where: { roomId, leftAt: null },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true, preferAnonymous: true } },
          },
        },
      },
      orderBy: { joinedAt: 'asc' },
    });

    const participants = rows.map((r) => {
      const email = r.user.email;
      const dn = r.user.profile?.displayName?.trim();
      const fromEmail = email.includes('@') ? email.split('@')[0] : email;
      const displayName =
        r.user.profile?.preferAnonymous === true
          ? 'Anonim kullanıcı'
          : dn != null && dn.length > 0
            ? dn
            : fromEmail || 'Kullanıcı';
      return {
        userId: r.userId,
        displayName,
        role: r.role,
        joinedAt: r.joinedAt,
      };
    });

    participants.sort((a, b) => {
      const rank = (role: GroupChatParticipantRole) =>
        role === 'moderator' ? 0 : role === 'listener' ? 1 : 2;
      const d = rank(a.role) - rank(b.role);
      if (d !== 0) return d;
      return a.displayName.localeCompare(b.displayName, 'tr');
    });

    this.logger.log(
      `[GroupChat] getRoom roomId=${roomId} userId=${userId} participants=${participants.length} title=${room.title?.slice(0, 40) ?? ''}`,
    );

    return {
      id: room.id,
      title: room.title,
      description: room.description,
      status: room.status,
      createdAt: room.createdAt,
      myRole: participant.role,
      participants,
    };
  }

  async listMessagesForUser(roomId: string, userId: string) {
    const { participant } = await this.assertGroupParticipant(roomId, userId);
    const mod = this.isModerator(participant.role);
    const rows = await this.prisma.groupChatMessage.findMany({
      where: {
        roomId,
        ...(mod ? {} : { hiddenByModeration: false }),
      },
      orderBy: { createdAt: 'asc' },
      select: groupMessageSelect,
    });
    this.logger.log(
      `[GroupChat] listMessages roomId=${roomId} userId=${userId} count=${rows.length} moderatorView=${mod}`,
    );
    return rows;
  }

  async addGroupMessage(
    roomId: string,
    userId: string,
    payload: {
      messageType?: MessageType;
      content?: string;
      imageUrl?: string;
      clientMessageId?: string;
    },
  ) {
    await this.assertGroupParticipant(roomId, userId);
    const messageType = payload.messageType ?? MessageType.text;
    const content = payload.content?.trim() ?? null;
    const imageUrl = payload.imageUrl?.trim() ?? null;
    const clientMessageId = payload.clientMessageId;
    if (messageType === MessageType.image) {
      if (!imageUrl) {
        throw new BadRequestException('image tipinde imageUrl gerekli');
      }
    } else if (!content) {
      throw new BadRequestException('content boş olamaz');
    }

    if (clientMessageId) {
      const existing = await this.prisma.groupChatMessage.findUnique({
        where: {
          roomId_clientMessageId: { roomId, clientMessageId },
        },
      });
      if (existing) {
        const msg = await this.prisma.groupChatMessage.findUniqueOrThrow({
          where: { id: existing.id },
          select: groupMessageSelect,
        });
        this.logger.log(
          `[GroupChat] addMessage dedupe roomId=${roomId} messageId=${msg.id} clientMessageId=${clientMessageId}`,
        );
        return msg;
      }
    }

    const created = await this.prisma.groupChatMessage.create({
      data: {
        roomId,
        senderId: userId,
        messageType,
        content,
        imageUrl,
        clientMessageId: clientMessageId ?? null,
      },
      select: groupMessageSelect,
    });
    this.logger.log(
      `[GroupChat] addMessage roomId=${roomId} messageId=${created.id} senderId=${userId} type=${messageType} contentLen=${content?.length ?? 0} clientMessageId=${clientMessageId ?? 'none'}`,
    );
    return created;
  }

  async markGroupMessageDelivered(
    roomId: string,
    messageId: string,
    userId: string,
  ) {
    await this.assertGroupParticipant(roomId, userId);
    const msg = await this.prisma.groupChatMessage.findFirst({
      where: { id: messageId, roomId },
    });
    if (!msg) throw new NotFoundException('Mesaj bulunamadı');
    if (msg.senderId === userId) {
      throw new BadRequestException('Gönderen teslim alınamaz');
    }
    if (msg.deliveredAt) {
      return this.prisma.groupChatMessage.findUniqueOrThrow({
        where: { id: messageId },
        select: groupMessageSelect,
      });
    }
    const updated = await this.prisma.groupChatMessage.update({
      where: { id: messageId },
      data: { deliveredAt: new Date() },
      select: groupMessageSelect,
    });
    this.logger.log(
      `[GroupChat] delivered roomId=${roomId} messageId=${messageId} byUserId=${userId}`,
    );
    return updated;
  }

  async markGroupMessageRead(
    roomId: string,
    messageId: string,
    userId: string,
  ) {
    await this.assertGroupParticipant(roomId, userId);
    const msg = await this.prisma.groupChatMessage.findFirst({
      where: { id: messageId, roomId },
    });
    if (!msg) throw new NotFoundException('Mesaj bulunamadı');
    if (msg.senderId === userId) {
      throw new BadRequestException(
        'Kendi mesajın okunmadı olarak işaretlenemez',
      );
    }
    if (msg.readAt) {
      return this.prisma.groupChatMessage.findUniqueOrThrow({
        where: { id: messageId },
        select: groupMessageSelect,
      });
    }
    const updated = await this.prisma.groupChatMessage.update({
      where: { id: messageId },
      data: { readAt: new Date() },
      select: groupMessageSelect,
    });
    this.logger.log(
      `[GroupChat] read roomId=${roomId} messageId=${messageId} byUserId=${userId}`,
    );
    return updated;
  }

  async createJoinRequest(roomId: string, userId: string, message?: string) {
    const room = await this.prisma.groupChatRoom.findUnique({
      where: { id: roomId },
    });
    if (!room) throw new NotFoundException('Oda bulunamadı');
    if (room.status !== 'open') {
      throw new ConflictException('Oda kapalı; katılma isteği gönderilemez');
    }

    const activeMember = await this.prisma.groupChatParticipant.findFirst({
      where: { roomId, userId, leftAt: null },
    });
    if (activeMember) {
      throw new ConflictException('Zaten bu odanın üyesisin');
    }

    const pending = await this.prisma.groupChatJoinRequest.findFirst({
      where: { roomId, userId, status: 'pending' },
    });
    if (pending) {
      throw new ConflictException(
        'Bu oda için zaten bekleyen bir katılma isteğin var',
      );
    }

    const msg = message?.trim() ? message.trim().slice(0, 500) : null;

    return this.prisma.groupChatJoinRequest.create({
      data: {
        roomId,
        userId,
        message: msg,
        status: 'pending',
      },
      select: {
        id: true,
        roomId: true,
        status: true,
        createdAt: true,
      },
    });
  }

  listPendingJoinRequestsAdmin(roomId?: string) {
    return this.prisma.groupChatJoinRequest.findMany({
      where: {
        status: 'pending',
        ...(roomId ? { roomId } : {}),
      },
      orderBy: { createdAt: 'asc' },
      select: {
        id: true,
        roomId: true,
        userId: true,
        message: true,
        createdAt: true,
        room: { select: { id: true, title: true } },
        requester: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });
  }

  private async ensureGroupMemberAsUserTx(
    tx: Prisma.TransactionClient,
    roomId: string,
    userId: string,
  ) {
    const room = await tx.groupChatRoom.findUnique({ where: { id: roomId } });
    if (!room) throw new NotFoundException('Oda bulunamadı');
    if (room.status !== 'open') {
      throw new ConflictException('Oda kapalı');
    }

    const user = await tx.user.findUnique({
      where: { id: userId },
      select: { status: true },
    });
    if (!user || user.status !== 'active') {
      throw new NotFoundException('Kullanıcı bulunamadı veya pasif');
    }

    const existing = await tx.groupChatParticipant.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (existing) {
      if (existing.leftAt == null) {
        return;
      }
      await tx.groupChatParticipant.update({
        where: { id: existing.id },
        data: {
          leftAt: null,
          removedReason: null,
          role: GroupChatParticipantRole.member,
          joinedAt: new Date(),
        },
      });
      return;
    }

    await tx.groupChatParticipant.create({
      data: {
        roomId,
        userId,
        role: GroupChatParticipantRole.member,
      },
    });
  }

  async approveJoinRequest(requestId: string, adminUserId: string) {
    const jr = await this.prisma.groupChatJoinRequest.findUnique({
      where: { id: requestId },
      select: { id: true, roomId: true, userId: true, status: true },
    });
    if (!jr) throw new NotFoundException('İstek bulunamadı');
    if (jr.status !== 'pending') {
      throw new ConflictException('İstek artık beklemede değil');
    }

    await this.prisma.$transaction(async (tx) => {
      await this.ensureGroupMemberAsUserTx(tx, jr.roomId, jr.userId);
      await tx.groupChatJoinRequest.update({
        where: { id: requestId },
        data: {
          status: 'approved',
          reviewedById: adminUserId,
          reviewedAt: new Date(),
        },
      });
    });

    return { ok: true, roomId: jr.roomId, userId: jr.userId };
  }

  async rejectJoinRequest(requestId: string, adminUserId: string) {
    const jr = await this.prisma.groupChatJoinRequest.findUnique({
      where: { id: requestId },
      select: { id: true, status: true },
    });
    if (!jr) throw new NotFoundException('İstek bulunamadı');
    if (jr.status !== 'pending') {
      throw new ConflictException('İstek artık beklemede değil');
    }

    await this.prisma.groupChatJoinRequest.update({
      where: { id: requestId },
      data: {
        status: 'rejected',
        reviewedById: adminUserId,
        reviewedAt: new Date(),
      },
    });

    return { ok: true };
  }
}
