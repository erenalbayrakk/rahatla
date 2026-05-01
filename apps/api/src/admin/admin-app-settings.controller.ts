import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AppSettingsService } from '../app-settings/app-settings.service';
import { ListenersService } from '../listeners/listeners.service';
import { AdminUpdateAppSettingsDto } from './dto/admin-update-app-settings.dto';

@Controller('admin/app-settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminAppSettingsController {
  constructor(
    private readonly appSettings: AppSettingsService,
    private readonly listeners: ListenersService,
  ) {}

  @Get()
  get() {
    return this.appSettings.getAdminPayload();
  }

  @Patch()
  async patch(@Body() dto: AdminUpdateAppSettingsDto) {
    const out = await this.appSettings.patch(dto);
    this.listeners.clearReplyPaceCache();
    return out;
  }
}
