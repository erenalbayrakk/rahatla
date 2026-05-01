import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UserRole, UserStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { AdminCreateUserDto } from './dto/admin-create-user.dto';
import { AdminUpdateUserDto } from './dto/admin-update-user.dto';

const adminUserSelect = {
  id: true,
  email: true,
  gender: true,
  role: true,
  status: true,
  isVerified: true,
  createdAt: true,
  updatedAt: true,
  profile: {
    select: {
      displayName: true,
      preferredLanguage: true,
      verifySelfieUrl: true,
      verifySelfieStatus: true,
      verifySelfieSubmittedAt: true,
      verifySelfieReviewedAt: true,
      verifySelfieRejectReason: true,
    },
  },
  listenerProfile: {
    select: {
      isOnline: true,
      presenceOverride: true,
      isAvailable: true,
      ratingAvg: true,
      ratingCount: true,
      adminRecognitionLabels: true,
    },
  },
  listenerApplication: {
    select: {
      status: true,
    },
  },
} as const;

const defaultListenerProfileData = {
  languages: ['tr'],
  supportCategories: [] as string[],
  communicationTypes: ['text_chat'],
  availabilityJson: {} as Record<string, never>,
};

@Injectable()
export class AdminUsersService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: adminUserSelect,
    });
  }

  /**
   * `listener_profile.is_online = true` — socket (presence auto) veya admin `force_online`.
   * Yalnızca dinleyen profili olan hesaplar için anlamlıdır.
   */
  listOnlineListeners() {
    return this.prisma.user.findMany({
      where: {
        listenerProfile: { is: { isOnline: true } },
      },
      orderBy: { email: 'asc' },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        isVerified: true,
        profile: { select: { displayName: true } },
        listenerProfile: {
          select: {
            isOnline: true,
            presenceOverride: true,
            isAvailable: true,
            ratingAvg: true,
            ratingCount: true,
            updatedAt: true,
          },
        },
      },
    });
  }

  /** `discover_listings` satırları — keşfet havuzunda kim var, görünür mü. */
  listDiscoverUsers() {
    return this.prisma.discoverListing.findMany({
      orderBy: { updatedAt: 'desc' },
      select: {
        userId: true,
        visibleInDiscover: true,
        createdAt: true,
        updatedAt: true,
        user: {
          select: {
            id: true,
            email: true,
            gender: true,
            role: true,
            status: true,
            isVerified: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });
  }

  listVerifySelfies(status: 'pending' | 'approved' | 'rejected' = 'pending') {
    return this.prisma.user.findMany({
      where: {
        profile: {
          verifySelfieStatus: status,
          verifySelfieUrl: { not: null },
        },
      },
      orderBy: { updatedAt: 'desc' },
      take: 200,
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        profile: {
          select: {
            displayName: true,
            verifySelfieUrl: true,
            verifySelfieStatus: true,
            verifySelfieSubmittedAt: true,
            verifySelfieReviewedAt: true,
            verifySelfieRejectReason: true,
          },
        },
      },
    });
  }

  async reviewVerifySelfie(
    userId: string,
    adminId: string,
    input: { status: 'approved' | 'rejected'; reason?: string },
  ) {
    const existing = await this.prisma.profile.findUnique({
      where: { userId },
      select: { userId: true, verifySelfieUrl: true },
    });
    if (!existing) {
      throw new NotFoundException('Kullanıcı profili bulunamadı.');
    }
    if (!existing.verifySelfieUrl) {
      throw new NotFoundException('Bu kullanıcı için selfie kaydı yok.');
    }
    const reason = input.status === 'rejected' ? input.reason?.trim() || null : null;
    await this.prisma.profile.update({
      where: { userId },
      data: {
        verifySelfieStatus: input.status,
        verifySelfieReviewedAt: new Date(),
        verifySelfieReviewedBy: adminId,
        verifySelfieRejectReason: reason,
      },
    });
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        profile: {
          select: {
            displayName: true,
            verifySelfieUrl: true,
            verifySelfieStatus: true,
            verifySelfieSubmittedAt: true,
            verifySelfieReviewedAt: true,
            verifySelfieRejectReason: true,
          },
        },
      },
    });
  }

  async create(dto: AdminCreateUserDto) {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException('Bu e-posta zaten kayıtlı.');
    }
    const passwordHash = await bcrypt.hash(dto.password, 10);
    const displayName =
      dto.displayName?.trim() || email.split('@')[0] || 'Kullanıcı';

    const base = {
      email,
      passwordHash,
      role: dto.role,
      status: UserStatus.active,
      isVerified: dto.isVerified ?? false,
      profile: {
        create: {
          displayName,
          preferredLanguage: 'tr',
        },
      },
      discoverListing: {
        create: { visibleInDiscover: true },
      },
    };
    if (dto.role === UserRole.approved_listener) {
      await this.prisma.user.create({
        data: {
          ...base,
          listenerProfile: { create: defaultListenerProfileData },
        },
      });
    } else {
      await this.prisma.user.create({ data: base });
    }

    return this.prisma.user.findUniqueOrThrow({
      where: { email },
      select: adminUserSelect,
    });
  }

  async update(userId: string, dto: AdminUpdateUserDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true },
    });
    if (!user) {
      throw new NotFoundException('Kullanıcı bulunamadı.');
    }

    if (dto.email) {
      const email = dto.email.trim().toLowerCase();
      const clash = await this.prisma.user.findFirst({
        where: { email, NOT: { id: userId } },
        select: { id: true },
      });
      if (clash) {
        throw new ConflictException(
          'Bu e-posta başka bir hesapta kullanılıyor.',
        );
      }
    }

    const nextRole = dto.role ?? user.role;

    const userData: {
      email?: string;
      passwordHash?: string;
      role?: UserRole;
      status?: UserStatus;
      isVerified?: boolean;
    } = {};
    if (dto.email) userData.email = dto.email.trim().toLowerCase();
    if (dto.password != null && dto.password.length > 0) {
      userData.passwordHash = await bcrypt.hash(dto.password, 10);
    }
    if (dto.role !== undefined) userData.role = dto.role;
    if (dto.status !== undefined) userData.status = dto.status;
    if (dto.isVerified !== undefined) userData.isVerified = dto.isVerified;

    await this.prisma.$transaction(async (tx) => {
      if (Object.keys(userData).length > 0) {
        await tx.user.update({
          where: { id: userId },
          data: userData,
        });
      }
      if (dto.displayName !== undefined) {
        const dn = dto.displayName.trim();
        await tx.profile.upsert({
          where: { userId },
          create: {
            userId,
            displayName: dn || 'Kullanıcı',
            preferredLanguage: 'tr',
          },
          update: { displayName: dn || 'Kullanıcı' },
        });
      }
      if (nextRole === UserRole.approved_listener) {
        await tx.listenerProfile.upsert({
          where: { userId },
          create: {
            userId,
            ...defaultListenerProfileData,
          },
          update: {},
        });
      }
    });

    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: adminUserSelect,
    });
  }
}
