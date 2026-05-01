import { IsIn, IsInt } from 'class-validator';

/** MVP: sabit paketler. Üretimde ödeme sağlayıcı onayı sonrası kullanılmalı. */
export class WalletTopupDto {
  @IsInt()
  @IsIn([100, 500, 1000, 5000], {
    message: 'amountMinor 100, 500, 1000 veya 5000 olmalı',
  })
  amountMinor!: number;
}
