import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminReviewVerifySelfieDto {
  @IsIn(['approved', 'rejected'])
  status!: 'approved' | 'rejected';

  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}
