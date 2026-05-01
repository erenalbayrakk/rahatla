import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AddGroupParticipantDto } from './dto/add-group-participant.dto';
import { CreateGroupRoomDto } from './dto/create-group-room.dto';
import { ModerateGroupMessageDto } from './dto/moderate-group-message.dto';
import { GroupChatService } from './group-chat.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('admin/group-rooms')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminGroupRoomsController {
  constructor(private readonly groups: GroupChatService) {}

  @Post()
  create(@Req() req: AuthedRequest, @Body() dto: CreateGroupRoomDto) {
    return this.groups.createRoom(req.user.userId, dto.title, dto.description);
  }

  @Get()
  list() {
    return this.groups.listRoomsAdmin();
  }

  @Get('join-requests')
  listJoinRequests(@Query('roomId') roomId?: string) {
    return this.groups.listPendingJoinRequestsAdmin(roomId);
  }

  @Post('join-requests/:requestId/approve')
  approveJoinRequest(
    @Req() req: AuthedRequest,
    @Param('requestId', new ParseUUIDPipe({ version: '4' })) requestId: string,
  ) {
    return this.groups.approveJoinRequest(requestId, req.user.userId);
  }

  @Post('join-requests/:requestId/reject')
  rejectJoinRequest(
    @Req() req: AuthedRequest,
    @Param('requestId', new ParseUUIDPipe({ version: '4' })) requestId: string,
  ) {
    return this.groups.rejectJoinRequest(requestId, req.user.userId);
  }

  @Post(':roomId/participants')
  addParticipant(
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
    @Body() dto: AddGroupParticipantDto,
  ) {
    return this.groups.addParticipant(roomId, dto.userId, dto.role);
  }

  @Delete(':roomId/participants/:userId')
  removeParticipant(
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
    @Param('userId', new ParseUUIDPipe({ version: '4' })) userId: string,
  ) {
    return this.groups.removeParticipant(roomId, userId);
  }

  @Patch(':roomId/close')
  closeRoom(
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
  ) {
    return this.groups.closeRoom(roomId);
  }

  @Get(':roomId/messages')
  listMessagesAdmin(
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
  ) {
    return this.groups.listMessagesAdmin(roomId);
  }

  @Patch(':roomId/messages/:messageId/moderate')
  moderateMessage(
    @Param('roomId', new ParseUUIDPipe({ version: '4' })) roomId: string,
    @Param('messageId', new ParseUUIDPipe({ version: '4' })) messageId: string,
    @Body() dto: ModerateGroupMessageDto,
  ) {
    return this.groups.setMessageModeration(roomId, messageId, dto.hidden);
  }
}
