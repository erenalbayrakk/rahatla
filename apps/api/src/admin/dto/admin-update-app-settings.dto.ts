import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class AdminUpdateAppSettingsDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(60)
  @Max(14 * 24 * 60 * 60)
  replySparkMaxSeconds?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(60)
  @Max(14 * 24 * 60 * 60)
  replySwiftMaxSeconds?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(60)
  @Max(14 * 24 * 60 * 60)
  replyWarmMaxSeconds?: number;
}
