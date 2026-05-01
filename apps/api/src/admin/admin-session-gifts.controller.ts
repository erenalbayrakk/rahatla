import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { PrismaService } from '../prisma/prisma.service';

const userForGiftSelect = {
  id: true,
  email: true,
  profile: { select: { displayName: true } },
} as const;

@Controller('admin/session-gifts')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminSessionGiftsController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Birebir sohbet hediye kayıtları (session_gifts), yeniden eskiye.
   */
  @Get()
  async list(@Query('limit') limitRaw?: string) {
    const limit = Math.min(
      500,
      Math.max(1, Number.parseInt(limitRaw ?? '200', 10) || 200),
    );
    const rows = await this.prisma.sessionGift.findMany({
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        sender: { select: userForGiftSelect },
        session: {
          select: {
            id: true,
            requester: { select: userForGiftSelect },
            listener: { select: userForGiftSelect },
          },
        },
      },
    });

    return rows.map((g) => {
      const s = g.session;
      const req = s.requester;
      const lst = s.listener;
      const recipientUser =
        g.senderId === req.id
          ? lst
          : g.senderId === lst.id
            ? req
            : lst;
      return {
        id: g.id,
        createdAt: g.createdAt,
        giftCode: g.giftCode,
        priceMinor: g.priceMinor,
        recipientEarnedMinor: g.recipientEarnedMinor,
        platformFeeMinor: g.platformFeeMinor,
        sessionId: s.id,
        sender: {
          id: g.sender.id,
          email: g.sender.email,
          displayName: g.sender.profile?.displayName ?? null,
        },
        recipient: {
          id: recipientUser.id,
          email: recipientUser.email,
          displayName: recipientUser.profile?.displayName ?? null,
        },
      };
    });
  }
}
