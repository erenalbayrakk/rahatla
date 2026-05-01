import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBlockDto } from './dto/create-block.dto';
import { CreateReportDto } from './dto/create-report.dto';

@Injectable()
export class SafetyService {
  constructor(private readonly prisma: PrismaService) {}

  async createReport(reporterId: string, dto: CreateReportDto) {
    if (dto.reportedUserId === reporterId) {
      throw new BadRequestException('Kendinizi şikayet edemezsiniz');
    }
    const reported = await this.prisma.user.findUnique({
      where: { id: dto.reportedUserId },
      select: { id: true },
    });
    if (!reported) {
      throw new NotFoundException('Kullanıcı bulunamadı');
    }
    if (dto.sessionId) {
      const session = await this.prisma.session.findUnique({
        where: { id: dto.sessionId },
        select: { requesterId: true, listenerId: true },
      });
      if (!session) {
        throw new NotFoundException('Oturum bulunamadı');
      }
      const inSession =
        (session.requesterId === reporterId ||
          session.listenerId === reporterId) &&
        (session.requesterId === dto.reportedUserId ||
          session.listenerId === dto.reportedUserId);
      if (!inSession) {
        throw new BadRequestException(
          'Bu oturum için şikayet koşulları sağlanmıyor',
        );
      }
    }
    return this.prisma.report.create({
      data: {
        reporterId,
        reportedUserId: dto.reportedUserId,
        sessionId: dto.sessionId ?? null,
        reason: dto.reason,
        description: dto.description?.trim() || null,
      },
      select: {
        id: true,
        status: true,
        createdAt: true,
      },
    });
  }

  async createBlock(blockerId: string, dto: CreateBlockDto) {
    if (dto.blockedId === blockerId) {
      throw new BadRequestException('Kendinizi engelleyemezsiniz');
    }
    const other = await this.prisma.user.findUnique({
      where: { id: dto.blockedId },
      select: { id: true },
    });
    if (!other) {
      throw new NotFoundException('Kullanıcı bulunamadı');
    }
    try {
      return await this.prisma.block.create({
        data: { blockerId, blockedId: dto.blockedId },
        select: { id: true, createdAt: true },
      });
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException('Bu kullanıcı zaten engellenmiş');
      }
      throw e;
    }
  }

  async removeBlock(blockerId: string, blockedId: string) {
    const res = await this.prisma.block.deleteMany({
      where: { blockerId, blockedId },
    });
    if (res.count === 0) {
      throw new NotFoundException('Engel kaydı bulunamadı');
    }
    return { ok: true };
  }
}
