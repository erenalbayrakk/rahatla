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
import { SetListenerRecognitionDto } from './dto/set-listener-recognition.dto';

@Controller('admin/listeners')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminListenerRecognitionController {
  constructor(private readonly prisma: PrismaService) {}

  @Patch(':userId/recognition-labels')
  async setLabels(
    @Param('userId', new ParseUUIDPipe({ version: '4' })) userId: string,
    @Body() dto: SetListenerRecognitionDto,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        role: true,
        listenerProfile: { select: { userId: true } },
      },
    });
    if (!user) throw new NotFoundException('Kullanıcı bulunamadı');
    if (user.role !== UserRole.approved_listener) {
      throw new ForbiddenException(
        'Yalnızca onaylı dinleyen hesaplarına takdir ifadesi verilebilir',
      );
    }
    if (!user.listenerProfile) {
      throw new NotFoundException('Dinleyen profili yok');
    }

    const seen = new Set<string>();
    const labels: string[] = [];
    for (const raw of dto.labels) {
      const t = raw.trim().replace(/\s+/g, ' ');
      if (!t || t.length > 48) continue;
      const key = t.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      labels.push(t);
      if (labels.length >= 12) break;
    }

    await this.prisma.listenerProfile.update({
      where: { userId },
      data: { adminRecognitionLabels: labels },
      select: { userId: true, adminRecognitionLabels: true },
    });

    return { userId, recognitionLabels: labels };
  }
}
