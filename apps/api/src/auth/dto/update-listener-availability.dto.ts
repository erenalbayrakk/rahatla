import { ListenerAvailabilityMode } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateListenerAvailabilityDto {
  @IsEnum(ListenerAvailabilityMode)
  availabilityMode!: ListenerAvailabilityMode;
}
