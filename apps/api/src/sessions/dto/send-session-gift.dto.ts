import { IsNotEmpty, IsString } from 'class-validator';

export class SendSessionGiftDto {
  @IsString()
  @IsNotEmpty()
  giftCode!: string;
}
