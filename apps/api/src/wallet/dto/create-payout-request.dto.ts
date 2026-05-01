import { IsInt, IsString, MaxLength, Min, MinLength } from 'class-validator';

export class CreatePayoutRequestDto {
  @IsInt()
  @Min(1)
  amountMinor!: number;

  @IsString()
  @MinLength(15)
  @MaxLength(42)
  iban!: string;
}
