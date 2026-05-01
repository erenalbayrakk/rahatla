import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';
import { WalletTopupDto } from './dto/wallet-topup.dto';
import { WalletService } from './wallet.service';

type AuthedRequest = Request & {
  user: { userId: string };
};

@Controller('wallet')
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get('gift-catalog')
  giftCatalog() {
    return this.wallet.getGiftCatalog();
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: AuthedRequest) {
    return this.wallet.walletSummary(req.user.userId);
  }

  @Get('leaderboard')
  @UseGuards(JwtAuthGuard)
  leaderboard(@Query('period') periodRaw?: string) {
    const period = periodRaw === 'month' ? 'month' : 'today';
    return this.wallet.leaderboard(period);
  }

  @Get('ledger')
  @UseGuards(JwtAuthGuard)
  ledger(
    @Req() req: AuthedRequest,
    @Query('take') takeRaw?: string,
    @Query('cursor') cursor?: string,
  ) {
    const take = takeRaw ? Number(takeRaw) : 20;
    return this.wallet.listLedger(req.user.userId, take, cursor);
  }

  @Get('received-session-gifts')
  @UseGuards(JwtAuthGuard)
  receivedSessionGifts(
    @Req() req: AuthedRequest,
    @Query('limit') limitRaw?: string,
  ) {
    return this.wallet.listReceivedSessionGifts(req.user.userId, limitRaw);
  }

  @Post('topup')
  @UseGuards(JwtAuthGuard)
  topup(@Req() req: AuthedRequest, @Body() dto: WalletTopupDto) {
    return this.wallet.selfServiceTopup(req.user.userId, dto.amountMinor);
  }

  @Post('payout-requests')
  @UseGuards(JwtAuthGuard)
  payoutRequest(
    @Req() req: AuthedRequest,
    @Body() dto: CreatePayoutRequestDto,
  ) {
    return this.wallet.createPayoutRequest(
      req.user.userId,
      dto.amountMinor,
      dto.iban,
    );
  }
}
