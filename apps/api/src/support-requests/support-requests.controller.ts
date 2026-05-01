import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateSupportRequestDto } from './dto/create-support-request.dto';
import { SupportRequestsService } from './support-requests.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('support-requests')
export class SupportRequestsController {
  constructor(private readonly supportRequests: SupportRequestsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@Req() req: AuthedRequest, @Body() dto: CreateSupportRequestDto) {
    return this.supportRequests.create(req.user.userId, dto);
  }
}
