import {
  Body,
  Controller,
  ForbiddenException,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { SetListenerPresenceOverrideDto } from './dto/set-listener-presence-override.dto';

@Controller('admin/listeners')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminListenerPresenceController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Dinleyen çevrimiçi göstergesi: `auto` = socket yönetir;
   * `force_online` / `force_offline` = admin (socket yazmaz).
   */
  @Patch(':userId/presence-override')
  async setPresenceOverride(
    @Param('userId', new ParseUUIDPipe({ version: '4' })) userId: string,
    @Body() dto: SetListenerPresenceOverrideDto,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        role: true,
        listenerProfile: { select: { userId: true } },
      },
    });
    if (!user?.listenerProfile) {
      throw new NotFoundException('Dinleyen profili yok');
    }
    if (user.role !== UserRole.approved_listener) {
      throw new ForbiddenException(
        'Yalnızca onaylı dinleyen hesapları için kullanılır',
      );
    }

    const data =
      dto.override === 'force_online'
        ? { presenceOverride: dto.override, isOnline: true }
        : dto.override === 'force_offline'
          ? { presenceOverride: dto.override, isOnline: false }
          : { presenceOverride: dto.override };

    return this.prisma.listenerProfile.update({
      where: { userId },
      data,
      select: {
        userId: true,
        isOnline: true,
        presenceOverride: true,
      },
    });
  }
}
