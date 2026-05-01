import { GroupChatParticipantRole } from '@prisma/client';
import { IsEnum, IsUUID } from 'class-validator';

export class AddGroupParticipantDto {
  @IsUUID('4')
  userId!: string;

  @IsEnum(GroupChatParticipantRole)
  role!: GroupChatParticipantRole;
}
