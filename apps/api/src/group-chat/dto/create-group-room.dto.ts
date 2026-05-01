import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateGroupRoomDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;
}
