import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { SupportCategory } from '@prisma/client';
import type { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { DeleteAccountDto } from './dto/delete-account.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { ResendVerificationDto } from './dto/resend-verification.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { UpdateGenderDto } from './dto/update-gender.dto';
import { UpdateListenerAvailabilityDto } from './dto/update-listener-availability.dto';
import { UpdateDiscoverVisibilityDto } from './dto/update-discover-visibility.dto';
import { UpdatePreferAnonymousDto } from './dto/update-prefer-anonymous.dto';
import { UpdateProfileImagesDto } from './dto/update-profile-images.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

type AuthedRequest = Request & {
  user: {
    userId: string;
    email: string;
    role: string;
    isVerified: boolean;
  };
};

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.token, dto.password);
  }

  @Get('verify-email')
  async verifyEmailGet(
    @Query('token') token: string | undefined,
    @Res() res: Response,
  ) {
    const { statusCode, html } = await this.auth.verifyEmailFromBrowser(token);
    res.status(statusCode).type('html').send(html);
  }

  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  verifyEmailPost(@Body() dto: VerifyEmailDto) {
    return this.auth.verifyEmailPost(dto.token);
  }

  @Post('resend-verification')
  @HttpCode(HttpStatus.OK)
  resendVerification(@Body() dto: ResendVerificationDto) {
    return this.auth.resendVerificationByEmail(dto.email);
  }

  @Post('me/resend-verification')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  resendVerificationMe(@Req() req: AuthedRequest) {
    return this.auth.resendVerificationForUserId(req.user.userId);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: AuthedRequest) {
    return this.auth.me(req.user.userId);
  }

  @Patch('me/profile-images')
  @UseGuards(JwtAuthGuard)
  updateProfileImages(
    @Req() req: AuthedRequest,
    @Body() body: UpdateProfileImagesDto,
  ) {
    return this.auth.updateProfileImages(req.user.userId, body.imageUrls);
  }

  @Patch('me/prefer-anonymous')
  @UseGuards(JwtAuthGuard)
  updatePreferAnonymous(
    @Req() req: AuthedRequest,
    @Body() body: UpdatePreferAnonymousDto,
  ) {
    return this.auth.updatePreferAnonymous(
      req.user.userId,
      body.preferAnonymous,
    );
  }

  @Patch('me/discover-visibility')
  @UseGuards(JwtAuthGuard)
  updateDiscoverVisibility(
    @Req() req: AuthedRequest,
    @Body() body: UpdateDiscoverVisibilityDto,
  ) {
    return this.auth.updateDiscoverVisibility(
      req.user.userId,
      body.visibleInDiscover,
    );
  }

  @Patch('me/mood')
  @UseGuards(JwtAuthGuard)
  updateMood(
    @Req() req: AuthedRequest,
    @Body() body: { moodCategory?: SupportCategory | null },
  ) {
    return this.auth.updateMood(req.user.userId, body);
  }

  @Patch('me/gender')
  @UseGuards(JwtAuthGuard)
  updateGender(@Req() req: AuthedRequest, @Body() body: UpdateGenderDto) {
    return this.auth.updateGender(req.user.userId, body);
  }

  @Patch('me/listener-availability')
  @UseGuards(JwtAuthGuard)
  updateListenerAvailability(
    @Req() req: AuthedRequest,
    @Body() body: UpdateListenerAvailabilityDto,
  ) {
    return this.auth.updateListenerAvailability(req.user.userId, body);
  }

  @Post('me/delete-account')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  deleteAccount(@Req() req: AuthedRequest, @Body() dto: DeleteAccountDto) {
    return this.auth.deleteAccount(req.user.userId, dto.password);
  }
}
