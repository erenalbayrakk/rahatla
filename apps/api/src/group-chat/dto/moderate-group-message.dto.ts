import { IsBoolean } from 'class-validator';

export class ModerateGroupMessageDto {
  @IsBoolean()
  hidden!: boolean;
}
