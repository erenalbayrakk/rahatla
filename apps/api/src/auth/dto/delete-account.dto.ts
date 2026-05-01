import { IsString, MinLength } from 'class-validator';

export class DeleteAccountDto {
  @IsString()
  @MinLength(8, { message: 'Şifre en az 8 karakter olmalı.' })
  password!: string;
}
