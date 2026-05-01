import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { MailConfigService } from '../mail/mail-config.service';
import { AdminUpdateMailSettingsDto } from './dto/admin-update-mail-settings.dto';

@Controller('admin/mail-settings')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminMailSettingsController {
  constructor(private readonly mailConfig: MailConfigService) {}

  @Get()
  get() {
    return this.mailConfig.getAdminPayload();
  }

  @Patch()
  patch(@Body() dto: AdminUpdateMailSettingsDto) {
    return this.mailConfig.patch(dto);
  }
}
