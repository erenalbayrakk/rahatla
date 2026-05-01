import {
  BadRequestException,
  Controller,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { S3Service } from './s3.service';

type AuthedRequest = Request & {
  user: { userId: string; email: string; role: string; isVerified: boolean };
};

@Controller('media')
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(
    private readonly s3: S3Service,
    private readonly prisma: PrismaService,
  ) {}

  @Post('chat-image')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  async uploadChatImage(
    @Req() req: AuthedRequest,
    @UploadedFile()
    file:
      | {
          mimetype?: string;
          buffer: Buffer;
          size?: number;
          originalname?: string;
        }
      | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('file alanı gerekli');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('Sadece görsel yüklenebilir');
    }
    const allowed = new Set([
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    ]);
    if (!allowed.has(file.mimetype)) {
      throw new BadRequestException('Desteklenen türler: JPG, PNG, WEBP');
    }
    const out = await this.s3.uploadChatImage({
      buffer: file.buffer,
      mimeType: file.mimetype,
      uploaderId: req.user.userId,
    });
    return { key: out.key, url: out.url };
  }

  @Post('profile-image')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  async uploadProfileImage(
    @Req() req: AuthedRequest,
    @UploadedFile()
    file:
      | {
          mimetype?: string;
          buffer: Buffer;
          size?: number;
          originalname?: string;
        }
      | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('file alanı gerekli');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('Sadece görsel yüklenebilir');
    }
    const allowed = new Set([
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    ]);
    if (!allowed.has(file.mimetype)) {
      throw new BadRequestException('Desteklenen türler: JPG, PNG, WEBP');
    }
    const out = await this.s3.uploadProfileImage({
      buffer: file.buffer,
      mimeType: file.mimetype,
      userId: req.user.userId,
    });
    return { key: out.key, url: out.url };
  }

  @Post('verify-selfie')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  async uploadVerifySelfie(
    @Req() req: AuthedRequest,
    @UploadedFile()
    file:
      | {
          mimetype?: string;
          buffer: Buffer;
          size?: number;
          originalname?: string;
        }
      | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('file alanı gerekli');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('Sadece görsel yüklenebilir');
    }
    const allowed = new Set([
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    ]);
    if (!allowed.has(file.mimetype)) {
      throw new BadRequestException('Desteklenen türler: JPG, PNG, WEBP');
    }
    const out = await this.s3.uploadVerifySelfie({
      buffer: file.buffer,
      mimeType: file.mimetype,
      userId: req.user.userId,
    });
    await this.prisma.profile.update({
      where: { userId: req.user.userId },
      data: {
        verifySelfieUrl: out.url,
        verifySelfieStatus: 'pending',
        verifySelfieSubmittedAt: new Date(),
        verifySelfieReviewedAt: null,
        verifySelfieReviewedBy: null,
        verifySelfieRejectReason: null,
      },
    });
    return { key: out.key, url: out.url };
  }
}
