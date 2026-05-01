import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterFcmTokenDto {
  @IsString()
  @MinLength(10, { message: 'FCM token cok kisa' })
  @MaxLength(512)
  fcmToken!: string;

  @IsString()
  @IsIn(['ios', 'android'])
  platform!: 'ios' | 'android';
}
