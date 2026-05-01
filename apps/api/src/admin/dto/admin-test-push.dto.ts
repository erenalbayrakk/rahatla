import { IsNotEmpty, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminTestPushDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  token!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  title!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  body!: string;

  @IsOptional()
  @IsObject()
  data?: Record<string, string | number | boolean | null>;
}
