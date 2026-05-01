import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateMessageDto } from './dto/create-message.dto';
import { SendSessionGiftDto } from './dto/send-session-gift.dto';
import { FromRandomListenerDto } from './dto/from-random-listener.dto';
import { FromSelectionDto } from './dto/from-selection.dto';
import { SessionsService } from './sessions.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessions: SessionsService) {}

  @Post('from-selection')
  @UseGuards(JwtAuthGuard)
  fromSelection(@Req() req: AuthedRequest, @Body() dto: FromSelectionDto) {
    return this.sessions.fromSelection(req.user.userId, dto);
  }

  @Post('from-random')
  @UseGuards(JwtAuthGuard)
  fromRandom(@Req() req: AuthedRequest, @Body() dto: FromRandomListenerDto) {
    return this.sessions.fromRandomListener(req.user.userId, dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  listMineForChats(@Req() req: AuthedRequest) {
    return this.sessions.listMineForChats(req.user.userId);
  }

  @Get('me/unread-count')
  @UseGuards(JwtAuthGuard)
  unreadMessagesCount(@Req() req: AuthedRequest) {
    return this.sessions
      .countUnreadIncomingMessages(req.user.userId)
      .then((unreadCount) => ({ unreadCount }));
  }

  @Post(':id/end')
  @UseGuards(JwtAuthGuard)
  endSession(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.sessions.endSession(id, req.user.userId);
  }

  @Get(':id/messages')
  @UseGuards(JwtAuthGuard)
  listMessages(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.sessions.listMessages(id, req.user.userId);
  }

  @Post(':id/messages')
  @UseGuards(JwtAuthGuard)
  addMessage(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() dto: CreateMessageDto,
  ) {
    return this.sessions.addMessage(id, req.user.userId, dto);
  }

  @Post(':id/gifts')
  @UseGuards(JwtAuthGuard)
  sendGift(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() dto: SendSessionGiftDto,
  ) {
    return this.sessions.recordGiftAndSystemMessage(
      id,
      req.user.userId,
      dto.giftCode,
    );
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  getById(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.sessions.getById(id, req.user.userId);
  }
}
