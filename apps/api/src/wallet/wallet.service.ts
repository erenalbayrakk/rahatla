import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  PayoutRequestStatus,
  Prisma,
  WalletLedgerType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class WalletService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private giftFeeBps(): number {
    const n = Number(this.config.get<string>('WALLET_GIFT_FEE_BPS') ?? '1000');
    if (!Number.isFinite(n) || n < 0 || n > 10000) {
      return 1000;
    }
    return n;
  }

  minPayoutMinor(): number {
    const n = Number(
      this.config.get<string>('WALLET_MIN_PAYOUT_MINOR') ?? '10000',
    );
    return Number.isFinite(n) && n > 0 ? n : 10000;
  }

  normalizeIban(raw: string): string {
    return raw.replace(/\s+/g, '').toUpperCase();
  }

  async getBalanceMinor(userId: string): Promise<number> {
    const w = await this.prisma.userWallet.findUnique({
      where: { userId },
      select: { balanceMinor: true },
    });
    return w?.balanceMinor ?? 0;
  }

  async getGiftCatalog() {
    return this.prisma.giftCatalogItem.findMany({
      where: { active: true },
      orderBy: { sortOrder: 'asc' },
      select: {
        code: true,
        label: true,
        priceMinor: true,
        sortOrder: true,
      },
    });
  }

  async walletSummary(userId: string) {
    const balanceMinor = await this.getBalanceMinor(userId);
    return {
      balance_minor: balanceMinor,
      currency: 'TRY',
      min_payout_minor: this.minPayoutMinor(),
    };
  }

  private static readonly allowedTopupAmounts = new Set([100, 500, 1000, 5000]);

  /**
   * MVP / test: kullanıcı kendi cüzdanına sabit paketlerle bakiye ekler.
   * Üretimde ödeme doğrulaması (IAP / PSP) ile değiştirilmeli.
   */
  async selfServiceTopup(userId: string, amountMinor: number) {
    if (
      !Number.isInteger(amountMinor) ||
      !WalletService.allowedTopupAmounts.has(amountMinor)
    ) {
      throw new BadRequestException(
        'Geçersiz tutar; yalnızca 100, 500, 1000 veya 5000 seçilebilir.',
      );
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.userWallet.upsert({
        where: { userId },
        create: { userId, balanceMinor: 0, currency: 'TRY' },
        update: {},
      });
      await tx.userWallet.update({
        where: { userId },
        data: { balanceMinor: { increment: amountMinor } },
      });
      await tx.walletLedgerEntry.create({
        data: {
          userId,
          amountMinor,
          type: WalletLedgerType.topup,
          referenceType: 'balance_purchase',
        },
      });
      const w = await tx.userWallet.findUniqueOrThrow({
        where: { userId },
        select: { balanceMinor: true },
      });
      return { balance_minor: w.balanceMinor };
    });
  }

  async listLedger(userId: string, take: number, cursor?: string) {
    const t = Math.min(Math.max(take, 1), 50);
    const rows = await this.prisma.walletLedgerEntry.findMany({
      where: { userId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: t + 1,
      ...(cursor
        ? {
            cursor: { id: cursor },
            skip: 1,
          }
        : {}),
      select: {
        id: true,
        amountMinor: true,
        type: true,
        referenceType: true,
        referenceId: true,
        createdAt: true,
      },
    });
    const hasMore = rows.length > t;
    const items = hasMore ? rows.slice(0, t) : rows;
    const nextCursor = hasMore ? items[items.length - 1]?.id : null;
    return {
      items: items.map((r) => ({
        id: r.id,
        amount_minor: r.amountMinor,
        type: r.type,
        reference_type: r.referenceType,
        reference_id: r.referenceId,
        created_at: r.createdAt.toISOString(),
      })),
      next_cursor: nextCursor,
    };
  }

  /**
   * Birebir sohbetlerde kullanıcının alıcı olduğu hediye kayıtları.
   * (Sender oturumdaki diğer taraftır; aynı oturumda gönderdiklerin dahil değil.)
   */
  async listReceivedSessionGifts(userId: string, limitRaw?: string) {
    const limit = Math.min(
      100,
      Math.max(1, Number.parseInt(limitRaw ?? '50', 10) || 50),
    );
    const where: Prisma.SessionGiftWhereInput = {
      NOT: { senderId: userId },
      session: {
        OR: [{ requesterId: userId }, { listenerId: userId }],
      },
    };
    const [agg, count, rows] = await Promise.all([
      this.prisma.sessionGift.aggregate({
        where,
        _sum: { recipientEarnedMinor: true },
      }),
      this.prisma.sessionGift.count({ where }),
      this.prisma.sessionGift.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: limit,
        include: {
          sender: {
            select: {
              id: true,
              email: true,
              profile: {
                select: { displayName: true, preferAnonymous: true },
              },
            },
          },
          session: { select: { id: true } },
        },
      }),
    ]);
    const codes = [...new Set(rows.map((r) => r.giftCode))];
    const catalog =
      codes.length === 0
        ? []
        : await this.prisma.giftCatalogItem.findMany({
            where: { code: { in: codes } },
            select: { code: true, label: true },
          });
    const labelMap = new Map(catalog.map((c) => [c.code, c.label]));
    return {
      total_recipient_earned_minor: agg._sum.recipientEarnedMinor ?? 0,
      gift_count: count,
      items: rows.map((g) => ({
        id: g.id,
        created_at: g.createdAt.toISOString(),
        gift_code: g.giftCode,
        gift_label: labelMap.get(g.giftCode) ?? g.giftCode,
        price_minor: g.priceMinor,
        recipient_earned_minor: g.recipientEarnedMinor,
        platform_fee_minor: g.platformFeeMinor,
        session_id: g.sessionId,
        sender: {
          id: g.sender.id,
          display_name: WalletService.senderDisplayNameForGift(g.sender),
        },
      })),
    };
  }

  private static senderDisplayNameForGift(sender: {
    profile: { displayName: string; preferAnonymous: boolean } | null;
  }): string {
    const p = sender.profile;
    if (p?.preferAnonymous === true) {
      return 'Anonim kullanıcı';
    }
    const d = p?.displayName?.trim();
    if (d != null && d.length > 0) {
      return d;
    }
    return 'Kullanıcı';
  }

  private async istanbulWindow(
    period: 'today' | 'month',
  ): Promise<{ start: Date; end: Date }> {
    if (period === 'today') {
      const rows = await this.prisma.$queryRaw<
        [{ t0: Date; t1: Date }]
      >`
        SELECT
          (((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::date) AT TIME ZONE 'Europe/Istanbul') AS t0,
          ((((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Istanbul')::date) + INTERVAL '1 day') AT TIME ZONE 'Europe/Istanbul') AS t1
      `;
      return { start: rows[0].t0, end: rows[0].t1 };
    }
    const rows = await this.prisma.$queryRaw<
      [{ t0: Date; t1: Date }]
    >`
      SELECT
        (date_trunc('month', timezone('Europe/Istanbul', CURRENT_TIMESTAMP)) AT TIME ZONE 'Europe/Istanbul') AS t0,
        ((date_trunc('month', timezone('Europe/Istanbul', CURRENT_TIMESTAMP)) + INTERVAL '1 month') AT TIME ZONE 'Europe/Istanbul') AS t1
    `;
    return { start: rows[0].t0, end: rows[0].t1 };
  }

  private async enrichLeaderboard(rows: { userId: string; totalMinor: number }[]) {
    if (rows.length === 0) {
      return [] as Array<{
        rank: number;
        user_id: string;
        display_name: string;
        total_minor: number;
      }>;
    }
    const ids = rows.map((r) => r.userId);
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: ids } },
      select: { userId: true, displayName: true, preferAnonymous: true },
    });
    const pmap = new Map(profiles.map((p) => [p.userId, p]));
    return rows.map((r, i) => {
      const p = pmap.get(r.userId);
      const name =
        p?.preferAnonymous === true
          ? 'Anonim kullanıcı'
          : (p?.displayName?.trim() || 'Kullanıcı');
      return {
        rank: i + 1,
        user_id: r.userId,
        display_name: name,
        total_minor: r.totalMinor,
      };
    });
  }

  /**
   * Hediye geliri (`gift_received`) ve hediye harcaması (`gift_sent`), İstanbul takvim günü veya ayına göre.
   */
  async leaderboard(period: 'today' | 'month') {
    const { start, end } = await this.istanbulWindow(period);
    const leaderLimit = 20;
    const [earnerGroups, senderGroups] = await Promise.all([
      this.prisma.walletLedgerEntry.groupBy({
        by: ['userId'],
        where: {
          type: WalletLedgerType.gift_received,
          createdAt: { gte: start, lt: end },
        },
        _sum: { amountMinor: true },
        orderBy: { _sum: { amountMinor: 'desc' } },
        take: leaderLimit,
      }),
      this.prisma.walletLedgerEntry.groupBy({
        by: ['userId'],
        where: {
          type: WalletLedgerType.gift_sent,
          createdAt: { gte: start, lt: end },
        },
        _sum: { amountMinor: true },
        orderBy: { _sum: { amountMinor: 'asc' } },
        take: leaderLimit,
      }),
    ]);
    const earners = earnerGroups
      .map((r) => ({
        userId: r.userId,
        totalMinor: r._sum.amountMinor ?? 0,
      }))
      .filter((r) => r.totalMinor > 0);
    const senders = senderGroups
      .map((r) => ({
        userId: r.userId,
        totalMinor: -(r._sum.amountMinor ?? 0),
      }))
      .filter((r) => r.totalMinor > 0);
    const [top_earners, top_gift_senders] = await Promise.all([
      this.enrichLeaderboard(earners),
      this.enrichLeaderboard(senders),
    ]);
    return {
      period,
      timezone: 'Europe/Istanbul',
      top_earners,
      top_gift_senders,
    };
  }

  /**
   * Birebir hediye: gönderen bakiyesinden düşer, alıcıya net yazar, deftere işler.
   */
  async executeSessionGiftPurchase(
    tx: Prisma.TransactionClient,
    params: {
      sessionId: string;
      senderId: string;
      recipientId: string;
      giftCode: string;
    },
  ): Promise<{ label: string; priceMinor: number; giftId: string }> {
    const { sessionId, senderId, recipientId, giftCode } = params;
    const code = giftCode.trim();
    const item = await tx.giftCatalogItem.findFirst({
      where: { code, active: true },
    });
    if (!item) {
      throw new BadRequestException('Geçersiz veya kapalı hediye kodu');
    }
    const price = item.priceMinor;
    const feeBps = this.giftFeeBps();
    const platformFee = Math.floor((price * feeBps) / 10000);
    const earned = price - platformFee;

    await tx.userWallet.upsert({
      where: { userId: senderId },
      create: { userId: senderId, balanceMinor: 0, currency: 'TRY' },
      update: {},
    });
    await tx.userWallet.upsert({
      where: { userId: recipientId },
      create: { userId: recipientId, balanceMinor: 0, currency: 'TRY' },
      update: {},
    });

    const dec = await tx.userWallet.updateMany({
      where: { userId: senderId, balanceMinor: { gte: price } },
      data: { balanceMinor: { decrement: price } },
    });
    if (dec.count !== 1) {
      throw new BadRequestException(
        `Yetersiz bakiye. Bu hediye ${price} birim; bakiyeni yükle veya başka hediye seç.`,
      );
    }

    await tx.userWallet.update({
      where: { userId: recipientId },
      data: { balanceMinor: { increment: earned } },
    });

    const gift = await tx.sessionGift.create({
      data: {
        sessionId,
        senderId,
        giftCode: code,
        priceMinor: price,
        recipientEarnedMinor: earned,
        platformFeeMinor: platformFee,
      },
    });

    await tx.walletLedgerEntry.createMany({
      data: [
        {
          userId: senderId,
          amountMinor: -price,
          type: WalletLedgerType.gift_sent,
          referenceType: 'session_gift',
          referenceId: gift.id,
          idempotencyKey: `gift_send_${gift.id}`,
        },
        {
          userId: recipientId,
          amountMinor: earned,
          type: WalletLedgerType.gift_received,
          referenceType: 'session_gift',
          referenceId: gift.id,
          idempotencyKey: `gift_recv_${gift.id}`,
        },
      ],
    });

    return { label: item.label, priceMinor: price, giftId: gift.id };
  }

  async createPayoutRequest(userId: string, amountMinor: number, ibanRaw: string) {
    const min = this.minPayoutMinor();
    if (amountMinor < min) {
      throw new BadRequestException(
        `Minimum çekim tutarı ${min} birim (ör. kuruş).`,
      );
    }
    const iban = this.normalizeIban(ibanRaw);
    if (iban.length < 15 || iban.length > 34) {
      throw new BadRequestException('Geçersiz IBAN uzunluğu');
    }

    const existing = await this.prisma.payoutRequest.findFirst({
      where: { userId, status: PayoutRequestStatus.pending },
    });
    if (existing) {
      throw new ConflictException(
        'Zaten bekleyen bir çekim talebin var; sonuçlanmasını bekle.',
      );
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.userWallet.upsert({
        where: { userId },
        create: { userId, balanceMinor: 0, currency: 'TRY' },
        update: {},
      });
      const dec = await tx.userWallet.updateMany({
        where: { userId, balanceMinor: { gte: amountMinor } },
        data: { balanceMinor: { decrement: amountMinor } },
      });
      if (dec.count !== 1) {
        throw new BadRequestException('Yetersiz bakiye');
      }

      const payout = await tx.payoutRequest.create({
        data: {
          userId,
          amountMinor,
          iban,
          status: PayoutRequestStatus.pending,
        },
      });

      await tx.walletLedgerEntry.create({
        data: {
          userId,
          amountMinor: -amountMinor,
          type: WalletLedgerType.payout_hold,
          referenceType: 'payout_request',
          referenceId: payout.id,
          idempotencyKey: `payout_hold_${payout.id}`,
        },
      });

      return {
        id: payout.id,
        amount_minor: payout.amountMinor,
        status: payout.status,
        created_at: payout.createdAt.toISOString(),
      };
    });
  }

  async adminCreditWallet(
    userId: string,
    amountMinor: number,
    note?: string,
  ) {
    if (amountMinor === 0) {
      throw new BadRequestException('Tutar 0 olamaz');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) {
      throw new NotFoundException('Kullanıcı bulunamadı');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.userWallet.upsert({
        where: { userId },
        create: { userId, balanceMinor: 0, currency: 'TRY' },
        update: {},
      });
      await tx.userWallet.update({
        where: { userId },
        data: { balanceMinor: { increment: amountMinor } },
      });
      await tx.walletLedgerEntry.create({
        data: {
          userId,
          amountMinor,
          type:
            amountMinor > 0
              ? WalletLedgerType.admin_credit
              : WalletLedgerType.admin_debit,
          referenceType: 'admin',
          ...(note != null && note.trim()
            ? { metaJson: { note: note.trim() } as Prisma.InputJsonValue }
            : {}),
        },
      });
      const w = await tx.userWallet.findUniqueOrThrow({
        where: { userId },
        select: { balanceMinor: true },
      });
      return { balance_minor: w.balanceMinor };
    });
  }

  async listPayoutRequestsForAdmin() {
    return this.prisma.payoutRequest.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true,
        userId: true,
        amountMinor: true,
        iban: true,
        status: true,
        adminNote: true,
        processedAt: true,
        createdAt: true,
      },
    });
  }

  async adminSetPayoutStatus(
    payoutId: string,
    status: 'paid' | 'rejected',
    adminNote?: string,
  ) {
    const payout = await this.prisma.payoutRequest.findUnique({
      where: { id: payoutId },
    });
    if (!payout) {
      throw new NotFoundException('Çekim talebi yok');
    }
    if (payout.status !== PayoutRequestStatus.pending) {
      throw new ConflictException('Bu talep zaten işlendi');
    }

    if (status === 'paid') {
      await this.prisma.payoutRequest.update({
        where: { id: payoutId },
        data: {
          status: PayoutRequestStatus.paid,
          processedAt: new Date(),
          adminNote: adminNote?.trim() || null,
        },
      });
      return { ok: true as const, status: 'paid' as const };
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.userWallet.upsert({
        where: { userId: payout.userId },
        create: {
          userId: payout.userId,
          balanceMinor: payout.amountMinor,
          currency: 'TRY',
        },
        update: { balanceMinor: { increment: payout.amountMinor } },
      });
      await tx.walletLedgerEntry.create({
        data: {
          userId: payout.userId,
          amountMinor: payout.amountMinor,
          type: WalletLedgerType.payout_refund,
          referenceType: 'payout_request',
          referenceId: payout.id,
          idempotencyKey: `payout_refund_${payout.id}`,
        },
      });
      await tx.payoutRequest.update({
        where: { id: payoutId },
        data: {
          status: PayoutRequestStatus.rejected,
          processedAt: new Date(),
          adminNote: adminNote?.trim() || null,
        },
      });
    });
    return { ok: true as const, status: 'rejected' as const };
  }
}
