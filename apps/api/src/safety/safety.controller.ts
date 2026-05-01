import {
  Body,
  Controller,
  Delete,
  Param,
  ParseUUIDPipe,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateBlockDto } from './dto/create-block.dto';
import { CreateReportDto } from './dto/create-report.dto';
import { SafetyService } from './safety.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('safety')
export class SafetyController {
  constructor(private readonly safety: SafetyService) {}

  @Post('reports')
  @UseGuards(JwtAuthGuard)
  createReport(@Req() req: AuthedRequest, @Body() dto: CreateReportDto) {
    return this.safety.createReport(req.user.userId, dto);
  }

  @Post('blocks')
  @UseGuards(JwtAuthGuard)
  createBlock(@Req() req: AuthedRequest, @Body() dto: CreateBlockDto) {
    return this.safety.createBlock(req.user.userId, dto);
  }

  @Delete('blocks/:blockedId')
  @UseGuards(JwtAuthGuard)
  removeBlock(
    @Req() req: AuthedRequest,
    @Param('blockedId', new ParseUUIDPipe({ version: '4' })) blockedId: string,
  ) {
    return this.safety.removeBlock(req.user.userId, blockedId);
  }
}
