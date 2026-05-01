import { UserRole, UserStatus } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

/**
 * FCM ile çoklu gönderim. En az bir filtre alanı dolu olmalı (onlyOnlineListeners: true veya
 * userIds / emailContains / role / status).
 */
export class AdminFilterPushDto {
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

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  @ArrayMaxSize(500)
  userIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(200)
  emailContains?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsEnum(UserStatus)
  status?: UserStatus;

  @IsOptional()
  @IsBoolean()
  onlyOnlineListeners?: boolean;
}
