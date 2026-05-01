import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { WalletService } from '../wallet/wallet.service';
import { AdminPayoutUpdateDto } from './dto/admin-payout-update.dto';

@Controller('admin/payout-requests')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminPayoutRequestsController {
  constructor(private readonly wallet: WalletService) {}

  @Get()
  list() {
    return this.wallet.listPayoutRequestsForAdmin();
  }

  @Patch(':id')
  update(
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() dto: AdminPayoutUpdateDto,
  ) {
    return this.wallet.adminSetPayoutStatus(id, dto.status, dto.adminNote);
  }
}
