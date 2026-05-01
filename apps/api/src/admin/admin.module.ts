import { Module } from '@nestjs/common';
import { AppSettingsModule } from '../app-settings/app-settings.module';
import { AuthModule } from '../auth/auth.module';
import { ListenersModule } from '../listeners/listeners.module';
import { MailModule } from '../mail/mail.module';
import { SessionsModule } from '../sessions/sessions.module';
import { WalletModule } from '../wallet/wallet.module';
import { AdminPushController } from './admin-push.controller';
import { AdminPushService } from './admin-push.service';
import { AdminMailSettingsController } from './admin-mail-settings.controller';
import { AdminPayoutRequestsController } from './admin-payout-requests.controller';
import { AdminWalletController } from './admin-wallet.controller';
import { AdminListenerPresenceController } from './admin-listener-presence.controller';
import { AdminListenerRecognitionController } from './admin-listener-recognition.controller';
import { AdminSessionsController } from './admin-sessions.controller';
import { AdminDiscoverController } from './admin-discover.controller';
import { AdminUsersController } from './admin-users.controller';
import { AdminUsersService } from './admin-users.service';
import { AdminSessionGiftsController } from './admin-session-gifts.controller';
import { AdminAppSettingsController } from './admin-app-settings.controller';

@Module({
  imports: [
    AuthModule,
    SessionsModule,
    MailModule,
    WalletModule,
    AppSettingsModule,
    ListenersModule,
  ],
  providers: [AdminUsersService, AdminPushService],
  controllers: [
    AdminDiscoverController,
    AdminUsersController,
    AdminListenerRecognitionController,
    AdminListenerPresenceController,
    AdminSessionsController,
    AdminMailSettingsController,
    AdminWalletController,
    AdminPayoutRequestsController,
    AdminPushController,
    AdminSessionGiftsController,
    AdminAppSettingsController,
  ],
})
export class AdminModule {}
