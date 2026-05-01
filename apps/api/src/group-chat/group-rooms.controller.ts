import {
  Body,
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
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateGroupJoinRequestDto } from './dto/create-group-join-request.dto';
import { GroupChatService } from './group-chat.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('group-rooms')
@UseGuards(JwtAuthGuard)
export class GroupRoomsController {
  constructor(private readonly groups: GroupChatService) {}

  @Get('me')
  listMine(@Req() req: AuthedRequest) {
    return this.groups.listMyRooms(req.user.userId);
  }

  @Get('discover')
  listDiscover(
    @Req() req: AuthedRequest,
    @Query('page') pageRaw: string | undefined,
  ) {
    const page = Math.max(1, parseInt(pageRaw ?? '1', 10) || 1);
    return this.groups.listDiscoverRooms(req.user.userId, page);
  }

  @Post(':roomId/join-request')
  requestJoin(
    @Req() req: AuthedRequest,
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
    @Body() dto: CreateGroupJoinRequestDto,
  ) {
    return this.groups.createJoinRequest(roomId, req.user.userId, dto.message);
  }

  @Get(':roomId/messages')
  listMessages(
    @Req() req: AuthedRequest,
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
  ) {
    return this.groups.listMessagesForUser(roomId, req.user.userId);
  }

  @Get(':roomId')
  getRoom(
    @Req() req: AuthedRequest,
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
  ) {
    return this.groups.getRoomForUser(roomId, req.user.userId);
  }
}
