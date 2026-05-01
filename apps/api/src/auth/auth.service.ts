import { randomBytes, randomUUID } from 'node:crypto';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import {
  Gender,
  ListenerAvailabilityMode,
  SupportCategory,
  UserRole,
} from '@prisma/client';
import { MailService } from '../mail/mail.service';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { UpdateListenerAvailabilityDto } from './dto/update-listener-availability.dto';

@Injectable()
export class AuthService {
  private readonly log = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mail: MailService,
  ) {}

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existing) {
      throw new ConflictException('Bu e-posta zaten kayıtlı.');
    }
    const passwordHash = await bcrypt.hash(dto.password, 10);
    const displayName =
      dto.displayName?.trim() || email.split('@')[0] || 'Kullanıcı';

    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        role: UserRole.normal_user,
        ...(dto.gender != null ? { gender: dto.gender } : {}),
        profile: {
          create: {
            displayName,
            preferredLanguage: 'tr',
            preferAnonymous: dto.preferAnonymous === true,
          },
        },
        discoverListing: {
          create: { visibleInDiscover: true },
        },
      },
      select: {
        id: true,
        email: true,
        role: true,
        isVerified: true,
        gender: true,
        profile: {
          select: {
            moodCategory: true,
            avatarUrl: true,
            verifySelfieUrl: true,
            verifySelfieStatus: true,
            preferAnonymous: true,
            profileImageUrls: true,
          },
        },
        listenerProfile: { select: { availabilityMode: true } },
        discoverListing: { select: { visibleInDiscover: true } },
      },
    });

    try {
      await this.setEmailVerificationForUser(user.id, email, displayName);
    } catch (e) {
      this.log.warn(
        `Doğrulama e-postası gönderilemedi (${user.id}): ${String(e)}`,
      );
    }

    return this.buildAuthResponse({
      id: user.id,
      email: user.email,
      role: user.role,
      isVerified: user.isVerified,
      gender: user.gender ?? null,
      moodCategory: user.profile?.moodCategory ?? null,
      avatarUrl: user.profile?.avatarUrl ?? null,
      verifySelfieUrl: user.profile?.verifySelfieUrl ?? null,
      verifySelfieStatus: user.profile?.verifySelfieStatus ?? 'none',
      preferAnonymous: user.profile?.preferAnonymous ?? false,
      listenerAvailabilityMode: user.listenerProfile?.availabilityMode ?? null,
      visibleInDiscover:
        user.discoverListing?.visibleInDiscover ??
        true,
      profileImageUrls: user.profile?.profileImageUrls ?? [],
    });
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        email: true,
        role: true,
        isVerified: true,
        passwordHash: true,
        status: true,
        gender: true,
        profile: {
          select: {
            moodCategory: true,
            avatarUrl: true,
            verifySelfieUrl: true,
            verifySelfieStatus: true,
            preferAnonymous: true,
            profileImageUrls: true,
          },
        },
        listenerProfile: { select: { availabilityMode: true } },
        discoverListing: { select: { visibleInDiscover: true } },
      },
    });
    if (!user || user.status !== 'active') {
      throw new UnauthorizedException('E-posta veya şifre hatalı.');
    }
    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('E-posta veya şifre hatalı.');
    }
    return this.buildAuthResponse({
      id: user.id,
      email: user.email,
      role: user.role,
      isVerified: user.isVerified,
      gender: user.gender ?? null,
      moodCategory: user.profile?.moodCategory ?? null,
      avatarUrl: user.profile?.avatarUrl ?? null,
      verifySelfieUrl: user.profile?.verifySelfieUrl ?? null,
      verifySelfieStatus: user.profile?.verifySelfieStatus ?? 'none',
      preferAnonymous: user.profile?.preferAnonymous ?? false,
      listenerAvailabilityMode: user.listenerProfile?.availabilityMode ?? null,
      visibleInDiscover:
        user.discoverListing?.visibleInDiscover ??
        true,
      profileImageUrls: user.profile?.profileImageUrls ?? [],
    });
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        isVerified: true,
        gender: true,
        profile: {
          select: {
            moodCategory: true,
            avatarUrl: true,
            verifySelfieUrl: true,
            verifySelfieStatus: true,
            preferAnonymous: true,
            profileImageUrls: true,
          },
        },
        listenerProfile: { select: { availabilityMode: true } },
        discoverListing: { select: { visibleInDiscover: true } },
      },
    });
    if (!user) {
      throw new UnauthorizedException();
    }
    return {
      user: this.formatUser({
        id: user.id,
        email: user.email,
        role: user.role,
        isVerified: user.isVerified,
        gender: user.gender ?? null,
        moodCategory: user.profile?.moodCategory ?? null,
        avatarUrl: user.profile?.avatarUrl ?? null,
        verifySelfieUrl: user.profile?.verifySelfieUrl ?? null,
        verifySelfieStatus: user.profile?.verifySelfieStatus ?? 'none',
        preferAnonymous: user.profile?.preferAnonymous ?? false,
        listenerAvailabilityMode:
          user.listenerProfile?.availabilityMode ?? null,
        visibleInDiscover:
          user.discoverListing?.visibleInDiscover ??
          true,
        profileImageUrls: user.profile?.profileImageUrls ?? [],
      }),
    };
  }

  async updateProfileImages(userId: string, raw: string[]) {
    const MAX = 9;
    const MAX_URL = 2048;
    if (!Array.isArray(raw)) {
      throw new BadRequestException('imageUrls dizi olmalı.');
    }
    if (raw.length > MAX) {
      throw new BadRequestException(`En fazla ${MAX} görsel tanımlanabilir.`);
    }
    const urls: string[] = [];
    for (const item of raw) {
      if (typeof item !== 'string') {
        throw new BadRequestException('Her öğe metin olmalı.');
      }
      const u = item.trim();
      if (u.length === 0) {
        throw new BadRequestException('Boş URL kullanılamaz.');
      }
      if (u.length > MAX_URL) {
        throw new BadRequestException('URL çok uzun.');
      }
      urls.push(u);
    }
    await this.prisma.profile.update({
      where: { userId },
      data: { profileImageUrls: urls },
    });
    return this.me(userId);
  }

  async updateDiscoverVisibility(
    userId: string,
    visibleInDiscover: boolean,
  ) {
    await this.prisma.discoverListing.upsert({
      where: { userId },
      create: { userId, visibleInDiscover },
      update: { visibleInDiscover },
    });
    return this.me(userId);
  }

  async updatePreferAnonymous(userId: string, preferAnonymous: boolean) {
    await this.prisma.profile.update({
      where: { userId },
      data: { preferAnonymous },
    });
    return this.me(userId);
  }

  async updateGender(userId: string, body: { gender?: unknown }) {
    if (body == null || !('gender' in body)) {
      throw new BadRequestException(
        'gender alanı gerekli (kaldırmak için null gönderin).',
      );
    }
    const g = body.gender as Gender | null;
    const allowed = Object.values(Gender) as string[];
    if (g !== null && (typeof g !== 'string' || !allowed.includes(g))) {
      throw new BadRequestException('Geçersiz gender');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { gender: g },
    });
    return this.me(userId);
  }

  async updateMood(
    userId: string,
    body: { moodCategory?: SupportCategory | null },
  ) {
    if (body == null || !('moodCategory' in body)) {
      throw new BadRequestException(
        'moodCategory gerekli (temizlemek için null gönder)',
      );
    }
    const v = body.moodCategory;
    const allowed = Object.values(SupportCategory) as string[];
    if (v !== null && (typeof v !== 'string' || !allowed.includes(v))) {
      throw new BadRequestException('Geçersiz moodCategory');
    }
    const row = await this.prisma.profile.findUnique({
      where: { userId },
      select: { userId: true },
    });
    if (!row) {
      throw new NotFoundException('Profil bulunamadı');
    }
    await this.prisma.profile.update({
      where: { userId },
      data: { moodCategory: v },
    });
    return this.me(userId);
  }

  async updateListenerAvailability(
    userId: string,
    body: UpdateListenerAvailabilityDto,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true },
    });
    if (!user) {
      throw new UnauthorizedException();
    }
    if (
      user.role !== UserRole.approved_listener &&
      user.role !== UserRole.admin
    ) {
      throw new ForbiddenException(
        'Bu ayar yalnızca dinleyen hesaplar için geçerlidir.',
      );
    }
    const lp = await this.prisma.listenerProfile.findUnique({
      where: { userId },
      select: { userId: true },
    });
    if (!lp) {
      throw new NotFoundException('Dinleyen profili bulunamadı.');
    }
    await this.prisma.listenerProfile.update({
      where: { userId },
      data: { availabilityMode: body.availabilityMode },
    });
    return this.me(userId);
  }

  /**
   * Hesabı kapatır: kullanıcı `deleted`, e-posta serbest kalır (yeniden kayıt mümkün),
   * şifre geçersiz kılınır. Oturumlar bir sonraki istekte JWT doğrulamasında düşer.
   */
  async deleteAccount(userId: string, password: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        passwordHash: true,
        status: true,
      },
    });
    if (!user) {
      throw new UnauthorizedException();
    }
    if (user.status !== 'active') {
      throw new BadRequestException('Bu hesap zaten kapatılmış.');
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Şifre hatalı.');
    }
    const idCompact = user.id.replace(/-/g, '');
    const tombstoneEmail = `deleted_${idCompact}@users.deleted.rahatla`;
    const tombstoneHash = await bcrypt.hash(randomUUID(), 10);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        status: 'deleted',
        email: tombstoneEmail,
        passwordHash: tombstoneHash,
        emailVerificationToken: null,
        emailVerificationExpires: null,
        passwordResetToken: null,
        passwordResetExpires: null,
      },
    });
    return { ok: true as const };
  }

  async forgotPassword(emailRaw: string) {
    const email = emailRaw.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        status: true,
        email: true,
        profile: { select: { displayName: true } },
      },
    });
    if (!user || user.status !== 'active') {
      return { ok: true as const };
    }
    const token = randomBytes(32).toString('hex');
    const expires = new Date(Date.now() + 60 * 60 * 1000);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken: token,
        passwordResetExpires: expires,
      },
    });
    const name =
      user.profile?.displayName ?? user.email.split('@')[0] ?? 'Kullanıcı';
    try {
      await this.mail.sendPasswordReset(user.email, token, name);
    } catch (e) {
      this.log.warn(`Şifre sıfırlama e-postası gönderilemedi: ${String(e)}`);
    }
    return { ok: true as const };
  }

  async resetPassword(tokenRaw: string, newPassword: string) {
    const token = tokenRaw.trim();
    if (!token) {
      throw new BadRequestException('Geçersiz kod.');
    }
    const user = await this.prisma.user.findFirst({
      where: {
        passwordResetToken: token,
        passwordResetExpires: { gt: new Date() },
        status: 'active',
      },
      select: { id: true },
    });
    if (!user) {
      throw new BadRequestException('Kod geçersiz veya süresi dolmuş.');
    }
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        passwordResetToken: null,
        passwordResetExpires: null,
      },
    });
    return { ok: true as const };
  }

  async verifyEmailPost(tokenRaw: string) {
    const ok = await this.tryConsumeVerificationToken(tokenRaw);
    if (!ok) {
      throw new BadRequestException('Kod geçersiz veya süresi dolmuş.');
    }
    return { ok: true as const };
  }

  async verifyEmailFromBrowser(token: string | undefined): Promise<{
    statusCode: number;
    html: string;
  }> {
    const t = token?.trim() ?? '';
    if (!t) {
      return {
        statusCode: 400,
        html: this.emailVerifyHtmlPage(
          'Bağlantıda doğrulama kodu eksik veya geçersiz.',
        ),
      };
    }
    const ok = await this.tryConsumeVerificationToken(t);
    if (!ok) {
      return {
        statusCode: 400,
        html: this.emailVerifyHtmlPage(
          'Bağlantı geçersiz veya süresi dolmuş. Uygulamadan yeni doğrulama e-postası isteyebilirsin.',
        ),
      };
    }
    return {
      statusCode: 200,
      html: this.emailVerifyHtmlPage(
        'E-posta adresin doğrulandı. Uygulamaya dönebilirsin.',
      ),
    };
  }

  async resendVerificationByEmail(emailRaw: string) {
    const email = emailRaw.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        status: true,
        isVerified: true,
        email: true,
        profile: { select: { displayName: true } },
      },
    });
    if (!user || user.status !== 'active' || user.isVerified) {
      return { ok: true as const };
    }
    const name =
      user.profile?.displayName ?? user.email.split('@')[0] ?? 'Kullanıcı';
    try {
      await this.setEmailVerificationForUser(user.id, user.email, name);
    } catch (e) {
      this.log.warn(
        `Doğrulama e-postası (yeniden) gönderilemedi: ${String(e)}`,
      );
    }
    return { ok: true as const };
  }

  async resendVerificationForUserId(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        status: true,
        isVerified: true,
        email: true,
        profile: { select: { displayName: true } },
      },
    });
    if (!user || user.status !== 'active') {
      throw new UnauthorizedException();
    }
    if (user.isVerified) {
      return { ok: true as const, alreadyVerified: true as const };
    }
    const name =
      user.profile?.displayName ?? user.email.split('@')[0] ?? 'Kullanıcı';
    try {
      await this.setEmailVerificationForUser(user.id, user.email, name);
    } catch (e) {
      this.log.warn(`Doğrulama e-postası gönderilemedi: ${String(e)}`);
      throw new BadRequestException(
        'E-posta gönderilemedi. SMTP ayarlarını kontrol et veya daha sonra dene.',
      );
    }
    return { ok: true as const, alreadyVerified: false as const };
  }

  private async setEmailVerificationForUser(
    userId: string,
    email: string,
    displayName: string,
  ) {
    const token = randomBytes(32).toString('hex');
    const expires = new Date(Date.now() + 24 * 60 * 60 * 1000);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        emailVerificationToken: token,
        emailVerificationExpires: expires,
      },
    });
    await this.mail.sendEmailVerification(email, token, displayName);
  }

  private async tryConsumeVerificationToken(raw: string): Promise<boolean> {
    const token = raw.trim();
    if (!token) {
      return false;
    }
    const user = await this.prisma.user.findFirst({
      where: {
        emailVerificationToken: token,
        emailVerificationExpires: { gt: new Date() },
        status: 'active',
      },
      select: { id: true },
    });
    if (!user) {
      return false;
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        isVerified: true,
        emailVerificationToken: null,
        emailVerificationExpires: null,
      },
    });
    return true;
  }

  private emailVerifyHtmlPage(message: string): string {
    const esc = message
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    return `<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Rahatla</title><style>body{font-family:system-ui,sans-serif;padding:24px;line-height:1.5;color:#222}</style></head><body><p>${esc}</p></body></html>`;
  }

  private buildAuthResponse(user: {
    id: string;
    email: string;
    role: UserRole;
    isVerified: boolean;
    gender?: Gender | null;
    moodCategory?: SupportCategory | null;
    avatarUrl?: string | null;
    verifySelfieUrl?: string | null;
    verifySelfieStatus?: 'none' | 'pending' | 'approved' | 'rejected';
    preferAnonymous?: boolean;
    listenerAvailabilityMode?: ListenerAvailabilityMode | null;
    visibleInDiscover?: boolean;
    profileImageUrls?: string[];
  }) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      accessToken: this.jwt.sign(payload),
      user: this.formatUser(user),
    };
  }

  private formatUser(user: {
    id: string;
    email: string;
    role: UserRole;
    isVerified: boolean;
    gender?: Gender | null;
    moodCategory?: SupportCategory | null;
    avatarUrl?: string | null;
    verifySelfieUrl?: string | null;
    verifySelfieStatus?: 'none' | 'pending' | 'approved' | 'rejected';
    preferAnonymous?: boolean;
    listenerAvailabilityMode?: ListenerAvailabilityMode | null;
    visibleInDiscover?: boolean;
    profileImageUrls?: string[];
  }) {
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      is_verified: user.isVerified,
      gender: user.gender ?? null,
      mood_category: user.moodCategory ?? null,
      avatar_url: user.avatarUrl ?? null,
      verify_selfie_url: user.verifySelfieUrl ?? null,
      verify_selfie_status: user.verifySelfieStatus ?? 'none',
      prefer_anonymous: user.preferAnonymous ?? false,
      listener_availability_mode: user.listenerAvailabilityMode ?? null,
      visible_in_discover: user.visibleInDiscover ?? true,
      profile_image_urls: user.profileImageUrls ?? [],
    };
  }
}
