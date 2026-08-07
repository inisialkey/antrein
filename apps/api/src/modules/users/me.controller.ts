import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { UpdateMeDto, UpdateNotificationPreferencesDto } from './dto/user.dto';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@Controller('me')
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @ApiOperation({ summary: 'Get the current user profile' })
  me(@CurrentUser() principal: AccessTokenPrincipal): ReturnType<UsersService['getMe']> {
    return this.users.getMe(principal.userId);
  }

  @Patch()
  @ApiOperation({ summary: 'Update the current user profile (contract §32)' })
  update(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Body() dto: UpdateMeDto,
  ): ReturnType<UsersService['updateMe']> {
    return this.users.updateMe(principal.userId, dto);
  }

  @Patch('notification-preferences')
  @ApiOperation({ summary: 'Update notification preferences (contract §33)' })
  updatePreferences(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Body() dto: UpdateNotificationPreferencesDto,
  ): ReturnType<UsersService['updateNotificationPreferences']> {
    return this.users.updateNotificationPreferences(principal.userId, dto);
  }
}
