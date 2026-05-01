import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AdminUpdateAppSettingsDto } from '../admin/dto/admin-update-app-settings.dto';
import { PrismaService } from '../prisma/prisma.service';

/** Ortamda satır yokken kullanılan varsayılanlar (panel “fabrika” değerleri ile aynı). */
export const DEFAULT_REPLY_SPARK_SEC = 300;
export const DEFAULT_REPLY_SWIFT_SEC = 1800;
export const DEFAULT_REPLY_WARM_SEC = 21600;

export type ReplyPaceThresholdsSec = {
  spark: number;
  swift: number;
  warm: number;
};

@Injectable()
export class AppSettingsService {
  private readonly log = new Logger(AppSettingsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Dinleyen keşif `replyPace` hesabı için — DB yoksa varsayılan sabitler. */
  async getReplyPaceThresholdsSec(): Promise<ReplyPaceThresholdsSec> {
    const row = await this.prisma.siteAppSettings.findUnique({
      where: { id: 'default' },
    });
    return {
      spark: row?.replySparkMaxSeconds ?? DEFAULT_REPLY_SPARK_SEC,
      swift: row?.replySwiftMaxSeconds ?? DEFAULT_REPLY_SWIFT_SEC,
      warm: row?.replyWarmMaxSeconds ?? DEFAULT_REPLY_WARM_SEC,
    };
  }

  async getAdminPayload() {
    const row = await this.prisma.siteAppSettings.findUnique({
      where: { id: 'default' },
    });
    return {
      stored: row
        ? {
            replySparkMaxSeconds: row.replySparkMaxSeconds,
            replySwiftMaxSeconds: row.replySwiftMaxSeconds,
            replyWarmMaxSeconds: row.replyWarmMaxSeconds,
            updatedAt: row.updatedAt.toISOString(),
          }
        : null,
      defaults: {
        replySparkMaxSeconds: DEFAULT_REPLY_SPARK_SEC,
        replySwiftMaxSeconds: DEFAULT_REPLY_SWIFT_SEC,
        replyWarmMaxSeconds: DEFAULT_REPLY_WARM_SEC,
      },
      notes: {
        spark: 'Medyan yanıt gecikmesi ≤ bu saniye → spark',
        swift: '≤ bu saniye → swift',
        warm: '≤ bu saniye → warm; üzeri easy',
        unit: 'saniye',
      },
    };
  }

  async patch(dto: AdminUpdateAppSettingsDto) {
    const cur = await this.getReplyPaceThresholdsSec();
    const spark = dto.replySparkMaxSeconds ?? cur.spark;
    const swift = dto.replySwiftMaxSeconds ?? cur.swift;
    const warm = dto.replyWarmMaxSeconds ?? cur.warm;

    if (!(spark < swift && swift < warm)) {
      throw new BadRequestException(
        'Eşikler sıkı artan olmalı: spark < swift < warm (saniye).',
      );
    }

    const MIN_S = 60;
    const MAX_S = 14 * 24 * 60 * 60;
    for (const [name, v] of [
      ['replySparkMaxSeconds', spark],
      ['replySwiftMaxSeconds', swift],
      ['replyWarmMaxSeconds', warm],
    ] as const) {
      if (v < MIN_S || v > MAX_S) {
        throw new BadRequestException(
          `${name} ${MIN_S} ile ${MAX_S} saniye arasında olmalı.`,
        );
      }
    }

    const data: Prisma.SiteAppSettingsUpdateInput = {
      replySparkMaxSeconds: spark,
      replySwiftMaxSeconds: swift,
      replyWarmMaxSeconds: warm,
    };

    await this.prisma.siteAppSettings.upsert({
      where: { id: 'default' },
      create: {
        id: 'default',
        replySparkMaxSeconds: spark,
        replySwiftMaxSeconds: swift,
        replyWarmMaxSeconds: warm,
      },
      update: data,
    });

    this.log.log(
      `reply pace thresholds updated: spark≤${spark}s swift≤${swift}s warm≤${warm}s`,
    );

    return this.getAdminPayload();
  }
}
