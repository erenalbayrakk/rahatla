import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { SessionStatus } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { SessionsService } from '../sessions/sessions.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('admin/sessions')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminSessionsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sessions: SessionsService,
  ) {}

  @Get()
  list(@Query('status') statusRaw?: string) {
    const allowed: SessionStatus[] = [
      'pending',
      'matched',
      'active',
      'ended',
      'cancelled',
      'reported',
    ];
    const status =
      statusRaw != null &&
      statusRaw !== '' &&
      (allowed as string[]).includes(statusRaw)
        ? (statusRaw as SessionStatus)
        : undefined;

    return this.prisma.session.findMany({
      where: status != null ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 150,
      select: {
        id: true,
        status: true,
        createdAt: true,
        startedAt: true,
        requester: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true } },
          },
        },
        listener: {
          select: {
            id: true,
            email: true,
            profile: { select: { displayName: true } },
          },
        },
        participants: {
          select: { userId: true, role: true },
        },
        _count: { select: { messages: true } },
      },
    });
  }

  @Post(':id/join-chat')
  joinChat(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.sessions.joinAsModerator(req.user.userId, id);
  }
}
