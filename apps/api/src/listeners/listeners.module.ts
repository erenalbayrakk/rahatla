import { Module } from '@nestjs/common';
import { AppSettingsModule } from '../app-settings/app-settings.module';
import { AuthModule } from '../auth/auth.module';
import { ListenersController } from './listeners.controller';
import { ListenersService } from './listeners.service';

@Module({
  imports: [AuthModule, AppSettingsModule],
  controllers: [ListenersController],
  providers: [ListenersService],
  exports: [ListenersService],
})
export class ListenersModule {}
