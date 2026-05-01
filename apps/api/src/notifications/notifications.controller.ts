import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RegisterFcmTokenDto } from './dto/register-fcm-token.dto';
import { NotificationsService } from './notifications.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@Req() req: AuthedRequest) {
    return this.notifications.listMine(req.user.userId);
  }

  @Get('unread-count')
  unreadCount(@Req() req: AuthedRequest) {
    return this.notifications.getUnreadCount(req.user.userId);
  }

  @Patch(':id/read')
  markRead(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.notifications.markRead(req.user.userId, id);
  }

  @Post('fcm-token')
  registerFcmToken(@Req() req: AuthedRequest, @Body() dto: RegisterFcmTokenDto) {
    return this.notifications.registerFcmToken(
      req.user.userId,
      dto.fcmToken.trim(),
      dto.platform,
    );
  }

  @Post('read-all')
  markAllRead(@Req() req: AuthedRequest) {
    return this.notifications.markAllRead(req.user.userId);
  }
}
