import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AdminUsersService } from './admin-users.service';

@Controller('admin/discover-users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminDiscoverController {
  constructor(private readonly users: AdminUsersService) {}

  @Get()
  list() {
    return this.users.listDiscoverUsers();
  }
}
