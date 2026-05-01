import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  BadRequestException,
  forwardRef,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MessageType, SessionType } from '@prisma/client';
import { resolvePinnedListenerEmail } from '../config/pinned-listener-email';
import { ListenersService } from '../listeners/listeners.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { ChatGateway } from '../realtime/chat.gateway';
import { WalletService } from '../wallet/wallet.service';
import { CreateMessageDto } from './dto/create-message.dto';
import { FromRandomListenerDto } from './dto/from-random-listener.dto';
import { FromSelectionDto } from './dto/from-selection.dto';
function inboxPreviewFromMessage(
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

const messageSelect = {
  id: true,
  sessionId: true,
  senderId: true,
  messageType: true,
  content: true,
  audioUrl: true,
  imageUrl: true,
  clientMessageId: true,
  deliveredAt: true,
  readAt: true,
  createdAt: true,
} as const;

@Injectable()
export class SessionsService {
  private readonly log = new Logger(SessionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly listeners: ListenersService,
    private readonly notifications: NotificationsService,
    private readonly wallet: WalletService,
    @Optional()
    @Inject(forwardRef(() => ChatGateway))
    private readonly chatGateway?: ChatGateway,
  ) {}

  async assertSessionParticipant(sessionId: string, userId: string) {
    const row = await this.prisma.sessionParticipant.findFirst({
      where: { sessionId, userId },
    });
    if (!row) {
      throw new ForbiddenException('Bu oturuma erişiminiz yok');
    }
    return row;
  }

  async fromSelection(requesterId: string, dto: FromSelectionDto) {
    if (requesterId === dto.listenerUserId) {
      throw new BadRequestException('Kendinizi dinleyen olarak seçemezsiniz');
    }

    const pinnedEmail = resolvePinnedListenerEmail(this.config);

    const listener = await this.prisma.user.findFirst({
      where: {
        id: dto.listenerUserId,
        status: 'active',
        OR: [
          { role: 'approved_listener' },
          { role: 'listener_applicant' },
          ...(pinnedEmail != null
            ? [
                {
                  role: 'admin' as const,
                  email: {
                    equals: pinnedEmail,
                    mode: 'insensitive' as const,
                  },
                },
              ]
            : []),
        ],
      },
      include: { listenerProfile: true },
    });

    if (!listener) {
      throw new NotFoundException('Dinleyen bulunamadı');
    }

    let supportRequestId: string | null = null;
    if (dto.supportRequestId) {
      const sr = await this.prisma.supportRequest.findFirst({
        where: {
          id: dto.supportRequestId,
          requesterId,
          status: { in: ['queued', 'matching'] },
        },
      });
      if (!sr) {
        throw new NotFoundException('Destek talebi bulunamadı veya kapatılmış');
      }
      if (sr.matchedListenerId && sr.matchedListenerId !== listener.id) {
        throw new ConflictException('Bu talep başka bir dinleyene bağlı');
      }
      supportRequestId = sr.id;
    }

    const sessionType: SessionType = dto.type ?? 'text_chat';

    const session = await this.prisma.$transaction(async (tx) => {
      const created = await tx.session.create({
        data: {
          supportRequestId,
          requesterId,
          listenerId: listener.id,
          type: sessionType,
          status: 'active',
          startedAt: new Date(),
          maxDurationSeconds: 900,
          provider: 'socket',
        },
      });

      await tx.sessionParticipant.createMany({
        data: [
          {
            sessionId: created.id,
            userId: requesterId,
            role: 'requester',
            joinedAt: new Date(),
          },
          {
            sessionId: created.id,
            userId: listener.id,
            role: 'listener',
            joinedAt: new Date(),
          },
        ],
      });

      if (supportRequestId) {
        await tx.supportRequest.update({
          where: { id: supportRequestId },
          data: {
            matchedListenerId: listener.id,
            status: 'matched',
          },
        });
      }

      return created;
    });

    return {
      id: session.id,
      requesterId: session.requesterId,
      listenerId: session.listenerId,
      type: session.type,
      status: session.status,
      startedAt: session.startedAt,
      maxDurationSeconds: session.maxDurationSeconds,
    };
  }

  async fromRandomListener(requesterId: string, dto: FromRandomListenerDto) {
    const listenerId = await this.listeners.pickRandomListenerId(requesterId);
    if (!listenerId) {
      throw new ConflictException(
        'Şu an rastgele atanabilecek uygun dinleyen yok; listeyi deneyebilirsin.',
      );
    }
    return this.fromSelection(requesterId, {
      listenerUserId: listenerId,
      supportRequestId: dto.supportRequestId,
      type: dto.type,
    });
  }

  /** Birebir sohbet sekmesi: katıldığın oturumlar (son mesaja göre sıralı). */
  async listMineForChats(userId: string) {
    const sessions = await this.prisma.session.findMany({
      where: {
        OR: [{ requesterId: userId }, { listenerId: userId }],
        status: { not: 'cancelled' },
      },
      select: {
        id: true,
        status: true,
        requesterId: true,
        listenerId: true,
        updatedAt: true,
        requester: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true, preferAnonymous: true } },
          },
        },
        listener: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true, preferAnonymous: true } },
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            messageType: true,
            content: true,
            imageUrl: true,
            createdAt: true,
          },
        },
      },
      take: 200,
    });

    const items = sessions.map((s) => {
      const peer = s.requesterId === userId ? s.listener : s.requester;
      const peerId = peer.id;
      const dn = peer.profile?.displayName?.trim();
      const fromEmail = peer.email.includes('@')
        ? peer.email.split('@')[0]
        : peer.email;
      const peerDisplayName =
        peer.profile?.preferAnonymous === true
          ? 'Anonim kullanıcı'
          : dn != null && dn.length > 0
            ? dn
            : fromEmail || 'Kullanıcı';
      const last = s.messages[0] ?? null;
      const lastAt = last?.createdAt ?? s.updatedAt;
      return {
        kind: 'session' as const,
        sessionId: s.id,
        peerUserId: peerId,
        peerDisplayName,
        status: s.status,
        lastMessageAt: lastAt.toISOString(),
        lastMessagePreview: inboxPreviewFromMessage(last),
      };
    });

    items.sort(
      (a, b) =>
        new Date(b.lastMessageAt).getTime() -
        new Date(a.lastMessageAt).getTime(),
    );
    return { items };
  }

  /**
   * Karşı taraftan gelen, henüz okunmamış mesaj sayısı (birebir + grup).
   * Mobil alt sekme rozeti için.
   */
  async countUnreadIncomingMessages(userId: string): Promise<number> {
    const [direct, group] = await Promise.all([
      this.prisma.message.count({
        where: {
          readAt: null,
          senderId: { not: userId },
          session: {
            status: { not: 'cancelled' },
            OR: [
              { requesterId: userId },
              { listenerId: userId },
              { participants: { some: { userId } } },
            ],
          },
        },
      }),
      this.prisma.groupChatMessage.count({
        where: {
          readAt: null,
          senderId: { not: userId },
          hiddenByModeration: false,
          room: {
            status: 'open',
            participants: {
              some: {
                userId,
                leftAt: null,
              },
            },
          },
        },
      }),
    ]);
    return direct + group;
  }

  async getById(sessionId: string, userId: string) {
    await this.assertSessionParticipant(sessionId, userId);
    const session = await this.prisma.session.findUniqueOrThrow({
      where: { id: sessionId },
      select: {
        id: true,
        requesterId: true,
        listenerId: true,
        type: true,
        status: true,
        startedAt: true,
        endedAt: true,
        maxDurationSeconds: true,
        provider: true,
        supportRequestId: true,
        createdAt: true,
        listener: {
          select: {
            profile: { select: { displayName: true } },
            listenerProfile: {
              select: { adminRecognitionLabels: true },
            },
          },
        },
        requester: {
          select: {
            profile: { select: { displayName: true, preferAnonymous: true } },
          },
        },
      },
    });
    const lp = session.listener.listenerProfile;
    const listenerDisplayName =
      session.listener.profile?.displayName?.trim() ||
      `Dinleyen ${session.listenerId.replace(/-/g, '').slice(0, 8)}`;
    const requesterDisplayName =
      session.requester.profile?.preferAnonymous === true
        ? 'Anonim kullanıcı'
        : session.requester.profile?.displayName?.trim() ||
          `Kullanıcı ${session.requesterId.replace(/-/g, '').slice(0, 8)}`;
    return {
      id: session.id,
      requesterId: session.requesterId,
      listenerId: session.listenerId,
      type: session.type,
      status: session.status,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      maxDurationSeconds: session.maxDurationSeconds,
      provider: session.provider,
      supportRequestId: session.supportRequestId,
      createdAt: session.createdAt,
      listenerDisplayName,
      requesterDisplayName,
      listenerRecognitionLabels: lp?.adminRecognitionLabels ?? [],
    };
  }

  async listMessages(sessionId: string, userId: string) {
    await this.assertSessionParticipant(sessionId, userId);
    return this.prisma.message.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
      select: messageSelect,
    });
  }

  async addMessage(sessionId: string, userId: string, dto: CreateMessageDto) {
    await this.assertSessionParticipant(sessionId, userId);
    const session = await this.prisma.session.findUniqueOrThrow({
      where: { id: sessionId },
      select: { status: true },
    });
    if (!['pending', 'matched', 'active'].includes(session.status)) {
      throw new ConflictException('Oturum bu mesaj için uygun değil');
    }

    const messageType: MessageType = dto.messageType ?? 'text';
    const content = dto.content?.trim() ?? null;
    const imageUrl = dto.imageUrl?.trim() ?? null;
    if (messageType === MessageType.image) {
      if (!imageUrl) {
        throw new BadRequestException('image tipinde imageUrl gerekli');
      }
    } else if (!content) {
      throw new BadRequestException('content boş olamaz');
    }

    if (dto.clientMessageId) {
      const existing = await this.prisma.message.findUnique({
        where: {
          sessionId_clientMessageId: {
            sessionId,
            clientMessageId: dto.clientMessageId,
          },
        },
      });
      if (existing) {
        return this.prisma.message.findUniqueOrThrow({
          where: { id: existing.id },
          select: messageSelect,
        });
      }
    }

    return this.prisma.message.create({
      data: {
        sessionId,
        senderId: userId,
        messageType,
        content,
        imageUrl,
        clientMessageId: dto.clientMessageId ?? null,
      },
      select: messageSelect,
    });
  }

  async endSession(sessionId: string, userId: string) {
    await this.assertSessionParticipant(sessionId, userId);
    const session = await this.prisma.session.findUniqueOrThrow({
      where: { id: sessionId },
    });
    if (session.status === 'ended' || session.status === 'cancelled') {
      return {
        id: session.id,
        status: session.status,
        endedAt: session.endedAt,
      };
    }
    const updated = await this.prisma.session.update({
      where: { id: sessionId },
      data: { status: 'ended', endedAt: new Date() },
      select: {
        id: true,
        status: true,
        endedAt: true,
      },
    });
    return updated;
  }

  async markSessionMessageDelivered(
    sessionId: string,
    messageId: string,
    userId: string,
  ) {
    await this.assertSessionParticipant(sessionId, userId);
    const msg = await this.prisma.message.findFirst({
      where: { id: messageId, sessionId },
    });
    if (!msg) {
      throw new NotFoundException('Mesaj bulunamadı');
    }
    if (msg.senderId === userId) {
      throw new BadRequestException('Gönderen teslim alınamaz');
    }
    if (msg.deliveredAt) {
      return this.prisma.message.findUniqueOrThrow({
        where: { id: messageId },
        select: messageSelect,
      });
    }
    return this.prisma.message.update({
      where: { id: messageId },
      data: { deliveredAt: new Date() },
      select: messageSelect,
    });
  }

  async markSessionMessageRead(
    sessionId: string,
    messageId: string,
    userId: string,
  ) {
    await this.assertSessionParticipant(sessionId, userId);
    const msg = await this.prisma.message.findFirst({
      where: { id: messageId, sessionId },
    });
    if (!msg) {
      throw new NotFoundException('Mesaj bulunamadı');
    }
    if (msg.senderId === userId) {
      throw new BadRequestException(
        'Kendi mesajın okunmadı olarak işaretlenemez',
      );
    }
    if (msg.readAt) {
      return this.prisma.message.findUniqueOrThrow({
        where: { id: messageId },
        select: messageSelect,
      });
    }
    return this.prisma.message.update({
      where: { id: messageId },
      data: { readAt: new Date() },
      select: messageSelect,
    });
  }

  /**
   * Yönetici panelinden birebir sohbete moderatör olarak katılım.
   * Katılımcı kaydı oluşunca mevcut socket / REST mesaj akışı aynen çalışır.
   */
  async joinAsModerator(adminUserId: string, sessionId: string) {
    const admin = await this.prisma.user.findFirst({
      where: { id: adminUserId, role: 'admin', status: 'active' },
      select: { id: true },
    });
    if (!admin) {
      throw new ForbiddenException(
        'Yalnızca aktif yönetici hesapları katılabilir',
      );
    }

    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: { id: true, status: true },
    });
    if (!session) {
      throw new NotFoundException('Oturum bulunamadı');
    }
    if (!['pending', 'matched', 'active'].includes(session.status)) {
      throw new ConflictException('Bu oturum için sohbet kapalı');
    }

    const existing = await this.prisma.sessionParticipant.findUnique({
      where: {
        sessionId_userId: { sessionId, userId: adminUserId },
      },
    });
    if (existing) {
      return { ok: true as const, alreadyJoined: true };
    }

    await this.prisma.sessionParticipant.create({
      data: {
        sessionId,
        userId: adminUserId,
        role: 'moderator',
        joinedAt: new Date(),
      },
    });
    return { ok: true as const, alreadyJoined: false };
  }

  /** Hediye kaydı + sistem mesajı (socket üzerinden yayınlanır). */
  async recordGiftAndSystemMessage(
    sessionId: string,
    senderId: string,
    giftCode: string,
  ) {
    await this.assertSessionParticipant(sessionId, senderId);
    const session = await this.prisma.session.findUniqueOrThrow({
      where: { id: sessionId },
      select: { status: true, requesterId: true, listenerId: true },
    });
    if (!['pending', 'matched', 'active'].includes(session.status)) {
      throw new ConflictException('Bu oturumda hediye gönderilemez');
    }

    let recipientId: string;
    if (senderId === session.requesterId) {
      recipientId = session.listenerId;
    } else if (senderId === session.listenerId) {
      recipientId = session.requesterId;
    } else {
      throw new ForbiddenException(
        'Hediye yalnızca oturumdaki yardım isteyen veya dinleyenden gönderilebilir.',
      );
    }

    const sender = await this.prisma.user.findUnique({
      where: { id: senderId },
      select: {
        profile: { select: { displayName: true } },
        email: true,
      },
    });
    const name =
      sender?.profile?.displayName?.trim() ||
      sender?.email?.split('@')[0] ||
      'Biri';

    let giftLabel = '';
    const msg = await this.prisma.$transaction(async (tx) => {
      const purchase = await this.wallet.executeSessionGiftPurchase(tx, {
        sessionId,
        senderId,
        recipientId,
        giftCode,
      });
      giftLabel = purchase.label;
      return tx.message.create({
        data: {
          sessionId,
          senderId,
          messageType: MessageType.system,
          content: `${name} bir hediye gönderdi: ${purchase.label}`,
        },
        select: messageSelect,
      });
    });

    try {
      this.chatGateway?.broadcastSessionMessage(sessionId, msg);
    } catch (e) {
      this.log.warn(`Hediye socket yayını atlandı: ${String(e)}`);
    }

    try {
      await this.notifications.createInApp(
        recipientId,
        'Hediye',
        `${name} bir hediye gönderdi: ${giftLabel}`,
        {
          kind: 'session_gift',
          sessionId,
          giftCode,
          messageId: msg.id,
        },
      );
    } catch {
      // Hediye kaydı başarılı; bildirim yazılamazsa sessizce geç
    }

    return msg;
  }
}
