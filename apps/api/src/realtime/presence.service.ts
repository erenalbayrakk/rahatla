import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Tek süreç içinde socket sayısı: aynı kullanıcı birden fazla sekme açabilir.
 * Yalnızca `presenceOverride === auto` iken `isOnline` alanını günceller.
 */
@Injectable()
export class PresenceService {
  private readonly log = new Logger(PresenceService.name);
  private readonly socketRefCount = new Map<string, number>();

  constructor(private readonly prisma: PrismaService) {}

  handleSocketConnected(userId: string) {
    const n = (this.socketRefCount.get(userId) ?? 0) + 1;
    this.socketRefCount.set(userId, n);
    if (n === 1) {
      void this.applySocketPresence(userId, true);
    }
  }

  handleSocketDisconnected(userId: string) {
    const prev = this.socketRefCount.get(userId) ?? 0;
    if (prev <= 1) {
      this.socketRefCount.delete(userId);
      void this.applySocketPresence(userId, false);
    } else {
      this.socketRefCount.set(userId, prev - 1);
    }
  }

  private async applySocketPresence(userId: string, online: boolean) {
    try {
      const lp = await this.prisma.listenerProfile.findUnique({
        where: { userId },
        select: { presenceOverride: true },
      });
      if (!lp || lp.presenceOverride !== 'auto') {
        return;
      }
      await this.prisma.listenerProfile.update({
        where: { userId },
        data: { isOnline: online },
      });
    } catch (e) {
      this.log.warn(`presence sync failed for ${userId}: ${e}`);
    }
  }
}
