import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AdminUsersService } from './admin-users.service';
import { AdminCreateUserDto } from './dto/admin-create-user.dto';
import { AdminReviewVerifySelfieDto } from './dto/admin-review-verify-selfie.dto';
import { AdminUpdateUserDto } from './dto/admin-update-user.dto';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('admin/users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  @Get()
  list() {
    return this.users.list();
  }

  @Get('online')
  listOnline() {
    return this.users.listOnlineListeners();
  }

  @Get('verify-selfies')
  listVerifySelfies(@Query('status') statusRaw?: string) {
    const status =
      statusRaw === 'approved' || statusRaw === 'rejected'
        ? statusRaw
        : 'pending';
    return this.users.listVerifySelfies(status);
  }

  @Post()
  create(@Body() dto: AdminCreateUserDto) {
    return this.users.create(dto);
  }

  @Patch(':id')
  update(
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() dto: AdminUpdateUserDto,
  ) {
    return this.users.update(id, dto);
  }

  @Patch(':id/verify-selfie')
  reviewVerifySelfie(
    @Req() req: AuthedRequest,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() dto: AdminReviewVerifySelfieDto,
  ) {
    return this.users.reviewVerifySelfie(id, req.user.userId, dto);
  }
}
