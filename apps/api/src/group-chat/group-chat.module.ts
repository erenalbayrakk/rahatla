import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminGroupRoomsController } from './admin-group-rooms.controller';
import { GroupRoomsController } from './group-rooms.controller';
import { GroupChatService } from './group-chat.service';

@Module({
  imports: [AuthModule],
  providers: [GroupChatService],
  controllers: [GroupRoomsController, AdminGroupRoomsController],
  exports: [GroupChatService],
})
export class GroupChatModule {}
