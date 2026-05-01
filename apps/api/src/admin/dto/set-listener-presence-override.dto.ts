import { ListenerPresenceOverride } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class SetListenerPresenceOverrideDto {
  @IsEnum(ListenerPresenceOverride)
  override!: ListenerPresenceOverride;
}
