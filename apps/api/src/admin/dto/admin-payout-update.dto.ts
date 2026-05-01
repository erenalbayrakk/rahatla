import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminPayoutUpdateDto {
  @IsIn(['paid', 'rejected'])
  status!: 'paid' | 'rejected';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  adminNote?: string;
}
