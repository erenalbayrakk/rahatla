import { SessionType } from '@prisma/client';
import { IsEnum, IsOptional, IsUUID } from 'class-validator';

export class FromRandomListenerDto {
  @IsOptional()
  @IsUUID('4')
  supportRequestId?: string;

  @IsOptional()
  @IsEnum(SessionType)
  type?: SessionType;
}
