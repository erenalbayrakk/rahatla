import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import {
  App,
  cert,
  getApp,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import {
  Message,
  MulticastMessage,
  getMessaging,
} from 'firebase-admin/messaging';
import { readFile } from 'node:fs/promises';
import { PrismaService } from '../prisma/prisma.service';
import { AdminFilterPushDto } from './dto/admin-filter-push.dto';
import { AdminTestPushDto } from './dto/admin-test-push.dto';

@Injectable()
export class AdminPushService {
  private static readonly firebaseAppName = 'rahatla-admin-push';
  private app?: App;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async sendTestPush(dto: AdminTestPushDto) {
    const app = await this.getFirebaseApp();
    const data: Record<string, string> = {};
    for (const [key, value] of Object.entries(dto.data ?? {})) {
      if (value == null) continue;
      data[key] = String(value);
    }

    const message: Message = {
      token: dto.token,
      notification: {
        title: dto.title,
        body: dto.body,
      },
      ...(Object.keys(data).length > 0 ? { data } : {}),
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    try {
      const messageId = await getMessaging(app).send(message);
      return { ok: true as const, messageId };
    } catch (error) {
      const e = error as { code?: string; message?: string };
      throw new BadRequestException({
        ok: false,
        code: e.code ?? 'messaging_error',
        message: e.message ?? 'Push gonderimi basarisiz oldu.',
      });
    }
  }

  async sendByFilter(dto: AdminFilterPushDto) {
    this.assertFilterPresent(dto);
    const where = this.buildUserWhere(dto);
    const users = await this.prisma.user.findMany({
      where,
      select: { id: true, email: true },
    });
    if (users.length === 0) {
      return {
        ok: true as const,
        matchedUserCount: 0,
        tokenCount: 0,
        successCount: 0,
        failureCount: 0,
        message: 'Filtre ile eslesen kullanici yok',
      };
    }
    const idList = users.map((u) => u.id);
    const tokenRows = await this.prisma.userFcmToken.findMany({
      where: { userId: { in: idList } },
      select: { fcmToken: true },
    });
    if (tokenRows.length === 0) {
      return {
        ok: true as const,
        matchedUserCount: users.length,
        tokenCount: 0,
        successCount: 0,
        failureCount: 0,
        message:
          'Eslesen kullanicilarda kayitli FCM token yok. Mobil uygulamada giris sonrasi token APIye gonderilir.',
      };
    }
    const uniqueTokens = [...new Set(tokenRows.map((t) => t.fcmToken))];
    const data: Record<string, string> = {};
    for (const [key, value] of Object.entries(dto.data ?? {})) {
      if (value == null) continue;
      data[key] = String(value);
    }
    const app = await this.getFirebaseApp();
    const messaging = getMessaging(app);
    const base: Omit<MulticastMessage, 'tokens'> = {
      notification: { title: dto.title, body: dto.body },
      ...(Object.keys(data).length > 0 ? { data } : {}),
      apns: {
        payload: {
          aps: { sound: 'default' },
        },
      },
    };
    const batch = 500;
    let successCount = 0;
    let failureCount = 0;
    for (let i = 0; i < uniqueTokens.length; i += batch) {
      const tokens = uniqueTokens.slice(i, i + batch);
      const res = await messaging.sendEachForMulticast({ ...base, tokens });
      successCount += res.successCount;
      failureCount += res.failureCount;
    }
    return {
      ok: true as const,
      matchedUserCount: users.length,
      tokenCount: uniqueTokens.length,
      successCount,
      failureCount,
    };
  }

  private assertFilterPresent(dto: AdminFilterPushDto) {
    const has =
      (dto.userIds?.length ?? 0) > 0 ||
      (dto.emailContains?.trim() ?? '') !== '' ||
      dto.role != null ||
      dto.status != null ||
      dto.onlyOnlineListeners === true;
    if (!has) {
      throw new BadRequestException(
        'En az bir filtre verin: userIds, emailContains, role, status veya onlyOnlineListeners: true',
      );
    }
  }

  private buildUserWhere(dto: AdminFilterPushDto): Prisma.UserWhereInput {
    const and: Prisma.UserWhereInput[] = [];
    if (dto.userIds && dto.userIds.length > 0) {
      and.push({ id: { in: dto.userIds } });
    }
    const q = dto.emailContains?.trim();
    if (q) {
      and.push({ email: { contains: q, mode: 'insensitive' } });
    }
    if (dto.role) {
      and.push({ role: dto.role });
    }
    if (dto.status) {
      and.push({ status: dto.status });
    }
    if (dto.onlyOnlineListeners) {
      and.push({ listenerProfile: { is: { isOnline: true } } });
    }
    return { AND: and };
  }

  private async getFirebaseApp(): Promise<App> {
    if (this.app) return this.app;
    const existing = getApps().find(
      (a) => a.name === AdminPushService.firebaseAppName,
    );
    if (existing) {
      this.app = getApp(AdminPushService.firebaseAppName);
      return this.app;
    }

    const serviceAccount = await this.readServiceAccountFromEnv();
    this.app = initializeApp(
      {
        credential: cert({
          projectId: serviceAccount.project_id,
          clientEmail: serviceAccount.client_email,
          privateKey: serviceAccount.private_key?.replace(/\\n/g, '\n'),
        }),
      },
      AdminPushService.firebaseAppName,
    );
    return this.app;
  }

  private async readServiceAccountFromEnv() {
    const inline = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    const path = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');
    const raw = inline?.trim()
      ? inline
      : path?.trim()
        ? await readFile(path, 'utf8')
        : null;
    if (!raw) {
      throw new InternalServerErrorException(
        'Firebase push ayarlari eksik. FIREBASE_SERVICE_ACCOUNT_JSON veya FIREBASE_SERVICE_ACCOUNT_PATH saglanmali.',
      );
    }

    const normalized = raw.trim().startsWith('{')
      ? raw
      : Buffer.from(raw, 'base64').toString('utf8');
    try {
      const json = JSON.parse(normalized) as {
        project_id?: string;
        client_email?: string;
        private_key?: string;
      };
      if (!json.project_id || !json.client_email || !json.private_key) {
        throw new Error('missing_fields');
      }
      return json;
    } catch {
      throw new InternalServerErrorException(
        'Firebase service account JSON gecersiz.',
      );
    }
  }
}
