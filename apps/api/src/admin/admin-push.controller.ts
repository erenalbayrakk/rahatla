import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AdminPushService } from './admin-push.service';
import { AdminFilterPushDto } from './dto/admin-filter-push.dto';
import { AdminTestPushDto } from './dto/admin-test-push.dto';

@Controller('admin/push')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminPushController {
  constructor(private readonly adminPush: AdminPushService) {}

  @Post('test')
  test(@Body() dto: AdminTestPushDto) {
    return this.adminPush.sendTestPush(dto);
  }

  @Post('by-filter')
  byFilter(@Body() dto: AdminFilterPushDto) {
    return this.adminPush.sendByFilter(dto);
  }
}
