import {
  Body,
  Controller,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { WalletService } from '../wallet/wallet.service';
import { AdminCreditWalletDto } from './dto/admin-credit-wallet.dto';

@Controller('admin/wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminWalletController {
  constructor(private readonly wallet: WalletService) {}

  @Post('users/:userId/credit')
  credit(
    @Param('userId', new ParseUUIDPipe({ version: '4' })) userId: string,
    @Body() dto: AdminCreditWalletDto,
  ) {
    return this.wallet.adminCreditWallet(userId, dto.amountMinor, dto.note);
  }
}
