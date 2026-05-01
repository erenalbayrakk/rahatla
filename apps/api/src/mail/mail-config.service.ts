import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Prisma } from '@prisma/client';
import { AdminUpdateMailSettingsDto } from '../admin/dto/admin-update-mail-settings.dto';
import { PrismaService } from '../prisma/prisma.service';

export type ResolvedMailConfig = {
  host: string | null;
  port: number;
  secure: boolean;
  user: string | undefined;
  pass: string;
  from: string;
  baseUrl: string;
};

@Injectable()
export class MailConfigService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async resolve(): Promise<ResolvedMailConfig> {
    const row = await this.prisma.siteMailSettings.findUnique({
      where: { id: 'default' },
    });
    const envHost = this.config.get<string>('SMTP_HOST')?.trim();
    const host = row?.smtpHost?.trim() || envHost || null;

    const envPortRaw = Number(this.config.get<string>('SMTP_PORT') ?? '587');
    const envPort = Number.isFinite(envPortRaw) ? envPortRaw : 587;
    const port = row?.smtpPort ?? envPort;

    let secure: boolean;
    if (row?.smtpSecure === true || row?.smtpSecure === false) {
      secure = row.smtpSecure;
    } else {
      secure =
        this.config.get<string>('SMTP_SECURE') === 'true' || port === 465;
    }

    const user =
      row?.smtpUser?.trim() || this.config.get<string>('SMTP_USER')?.trim();
    const pass = this.config.get<string>('SMTP_PASS') ?? '';
    const from =
      row?.mailFrom?.trim() ||
      this.config.get<string>('MAIL_FROM')?.trim() ||
      'Rahatla <no-reply@rahatla.local>';
    const baseUrl =
      row?.appPublicApiUrl?.trim() ||
      this.config.get<string>('APP_PUBLIC_API_URL')?.trim() ||
      `http://127.0.0.1:${this.config.get<string>('PORT') ?? '3000'}`;

    return { host, port, secure, user, pass, from, baseUrl };
  }

  async getAdminPayload() {
    const row = await this.prisma.siteMailSettings.findUnique({
      where: { id: 'default' },
    });
    const effective = await this.resolve();
    const smtpSecureStored =
      row?.smtpSecure === true
        ? 'on'
        : row?.smtpSecure === false
          ? 'off'
          : 'inherit';
    return {
      stored: {
        smtpHost: row?.smtpHost ?? null,
        smtpPort: row?.smtpPort ?? null,
        smtpSecure: smtpSecureStored,
        smtpUser: row?.smtpUser ?? null,
        mailFrom: row?.mailFrom ?? null,
        appPublicApiUrl: row?.appPublicApiUrl ?? null,
        providerDocsUrl: row?.providerDocsUrl ?? null,
        updatedAt: row?.updatedAt?.toISOString() ?? null,
      },
      effective: {
        smtpHost: effective.host,
        smtpPort: effective.port,
        smtpSecure: effective.secure,
        smtpUser: effective.user ?? null,
        smtpPasswordConfigured: effective.pass.length > 0,
        mailFrom: effective.from,
        appPublicApiUrl: effective.baseUrl,
      },
    };
  }

  async patch(dto: AdminUpdateMailSettingsDto) {
    const update: Prisma.SiteMailSettingsUpdateInput = {};
    const create: Prisma.SiteMailSettingsUncheckedCreateInput = {
      id: 'default',
    };

    if (dto.smtpHost !== undefined) {
      const v = dto.smtpHost.trim() ? dto.smtpHost.trim() : null;
      update.smtpHost = v;
      create.smtpHost = v;
    }
    if (dto.smtpPort !== undefined) {
      update.smtpPort = dto.smtpPort;
      create.smtpPort = dto.smtpPort;
    }
    if (dto.smtpSecure !== undefined) {
      const v =
        dto.smtpSecure === 'inherit'
          ? null
          : dto.smtpSecure === 'on'
            ? true
            : false;
      update.smtpSecure = v;
      create.smtpSecure = v;
    }
    if (dto.smtpUser !== undefined) {
      const v = dto.smtpUser.trim() ? dto.smtpUser.trim() : null;
      update.smtpUser = v;
      create.smtpUser = v;
    }
    if (dto.mailFrom !== undefined) {
      const v = dto.mailFrom.trim() ? dto.mailFrom.trim() : null;
      update.mailFrom = v;
      create.mailFrom = v;
    }
    if (dto.appPublicApiUrl !== undefined) {
      const v = dto.appPublicApiUrl.trim() ? dto.appPublicApiUrl.trim() : null;
      update.appPublicApiUrl = v;
      create.appPublicApiUrl = v;
    }
    if (dto.providerDocsUrl !== undefined) {
      const v = dto.providerDocsUrl.trim() ? dto.providerDocsUrl.trim() : null;
      update.providerDocsUrl = v;
      create.providerDocsUrl = v;
    }

    if (Object.keys(update).length === 0) {
      return this.getAdminPayload();
    }

    await this.prisma.siteMailSettings.upsert({
      where: { id: 'default' },
      create,
      update,
    });

    return this.getAdminPayload();
  }
}
