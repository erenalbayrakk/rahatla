import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';

export class AdminUpdateMailSettingsDto {
  @IsOptional()
  @IsString()
  smtpHost?: string;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(65535)
  smtpPort?: number | null;

  @IsOptional()
  @IsIn(['inherit', 'on', 'off'])
  smtpSecure?: 'inherit' | 'on' | 'off';

  @IsOptional()
  @IsString()
  smtpUser?: string;

  @IsOptional()
  @IsString()
  mailFrom?: string;

  @IsOptional()
  @IsString()
  appPublicApiUrl?: string;

  @IsOptional()
  @IsString()
  providerDocsUrl?: string;
}
