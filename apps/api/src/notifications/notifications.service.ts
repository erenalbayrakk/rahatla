import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async createInApp(
    userId: string,
    title: string,
    body: string,
    dataJson?: Prisma.InputJsonValue,
  ) {
    return this.prisma.notification.create({
      data: {
        userId,
        channel: 'in_app',
        title,
        body,
        dataJson: dataJson ?? undefined,
      },
      select: {
        id: true,
        title: true,
        body: true,
        dataJson: true,
        readAt: true,
        createdAt: true,
      },
    });
  }

  async listMine(userId: string) {
    const [items, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId, channel: 'in_app' },
        orderBy: { createdAt: 'desc' },
        take: 100,
        select: {
          id: true,
          title: true,
          body: true,
          dataJson: true,
          readAt: true,
          createdAt: true,
        },
      }),
      this.prisma.notification.count({
        where: { userId, readAt: null },
      }),
    ]);
    return { items, unreadCount };
  }

  async getUnreadCount(userId: string) {
    const unreadCount = await this.prisma.notification.count({
      where: { userId, readAt: null },
    });
    return { unreadCount };
  }

  async markRead(userId: string, notificationId: string) {
    const row = await this.prisma.notification.findFirst({
      where: { id: notificationId, userId },
    });
    if (!row) {
      throw new NotFoundException('Bildirim bulunamadı');
    }
    if (row.readAt) {
      return this.prisma.notification.findUniqueOrThrow({
        where: { id: notificationId },
        select: {
          id: true,
          title: true,
          body: true,
          dataJson: true,
          readAt: true,
          createdAt: true,
        },
      });
    }
    return this.prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
      select: {
        id: true,
        title: true,
        body: true,
        dataJson: true,
        readAt: true,
        createdAt: true,
      },
    });
  }

  async markAllRead(userId: string) {
    const res = await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { updated: res.count };
  }

  /**
   * Aynı kullanıcının eski satırlarını ve bu token'ı başka kullanıcıda tutan satırı siler, yeniden yazar
   * (cihaz / token yenileme).
   */
  async registerFcmToken(
    userId: string,
    fcmToken: string,
    platform: 'ios' | 'android',
  ) {
    await this.prisma.$transaction([
      this.prisma.userFcmToken.deleteMany({
        where: {
          OR: [{ userId }, { fcmToken }],
        },
      }),
      this.prisma.userFcmToken.create({
        data: { userId, fcmToken, platform },
      }),
    ]);
    return { ok: true as const };
  }
}
