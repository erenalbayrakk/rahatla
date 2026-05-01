import {
  BadRequestException,
  Controller,
  Get,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Gender } from '@prisma/client';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ListenersService } from './listeners.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('listeners')
export class ListenersController {
  constructor(private readonly listeners: ListenersService) {}

  @Get('browse')
  @UseGuards(JwtAuthGuard)
  browse(
    @Req() req: AuthedRequest,
    @Query('filter') filterRaw: string | undefined,
    @Query('mood') moodQuery: string | undefined,
    @Query('page') pageRaw: string | undefined,
    @Query('q') q: string | undefined,
    @Query('minAge') minAgeRaw: string | undefined,
    @Query('maxAge') maxAgeRaw: string | undefined,
    @Query('gender') genderRaw: string | undefined,
  ) {
    const filter = filterRaw === 'ready' ? 'ready' : 'all';
    const page = Math.max(1, parseInt(pageRaw ?? '1', 10) || 1);

    let minAge: number | undefined;
    if (minAgeRaw != null && minAgeRaw !== '') {
      const n = parseInt(minAgeRaw, 10);
      if (!Number.isFinite(n) || n < 0 || n > 120) {
        throw new BadRequestException('minAge 0–120 arasında olmalı');
      }
      minAge = n;
    }
    let maxAge: number | undefined;
    if (maxAgeRaw != null && maxAgeRaw !== '') {
      const n = parseInt(maxAgeRaw, 10);
      if (!Number.isFinite(n) || n < 0 || n > 120) {
        throw new BadRequestException('maxAge 0–120 arasında olmalı');
      }
      maxAge = n;
    }
    if (
      minAge != null &&
      maxAge != null &&
      minAge > maxAge
    ) {
      throw new BadRequestException('minAge maxAge’den büyük olamaz');
    }

    let gender: Gender | undefined;
    if (genderRaw != null && genderRaw !== '') {
      const allowed = Object.values(Gender) as string[];
      if (!allowed.includes(genderRaw)) {
        throw new BadRequestException('Geçersiz gender');
      }
      gender = genderRaw as Gender;
    }

    return this.listeners.browse({
      filter,
      seekerUserId: req.user.userId,
      moodQuery,
      page,
      q,
      minAge,
      maxAge,
      gender,
    });
  }
}
