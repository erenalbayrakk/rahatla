import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class AdminCreditWalletDto {
  @IsInt()
  @Min(-50_000_000)
  @Max(50_000_000)
  amountMinor!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
