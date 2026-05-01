import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateGroupJoinRequestDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
