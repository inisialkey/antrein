import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { ListNotificationsQueryDto, RegisterDeviceDto } from './dto/notifications.dto';
import { NotificationsService } from './notifications.service';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'List my notifications' })
  list(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Query() query: ListNotificationsQueryDto,
  ): Promise<Record<string, unknown>> {
    return this.notifications.list(principal.userId, query);
  }

  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark all my notifications as read' })
  readAll(@CurrentUser() principal: AccessTokenPrincipal): Promise<Record<string, unknown>> {
    return this.notifications.markAllRead(principal.userId);
  }

  @Get(':notificationId')
  @ApiOperation({ summary: 'Get one notification' })
  get(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('notificationId') notificationId: string,
  ): Promise<Record<string, unknown>> {
    return this.notifications.get(principal.userId, notificationId);
  }

  @Post(':notificationId/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Mark a notification as read' })
  read(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('notificationId') notificationId: string,
  ): Promise<Record<string, unknown>> {
    return this.notifications.markRead(principal.userId, notificationId);
  }
}

@ApiTags('users')
@ApiBearerAuth()
@Controller('me/devices')
export class MeDevicesController {
  constructor(private readonly notifications: NotificationsService) {}

  @Put(':deviceId')
  @ApiOperation({ summary: 'Register or update a device (idempotent by deviceId)' })
  register(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('deviceId') deviceId: string,
    @Body() dto: RegisterDeviceDto,
  ): Promise<Record<string, unknown>> {
    return this.notifications.registerDevice(principal.userId, deviceId, dto);
  }

  @Delete(':deviceId')
  @ApiOperation({ summary: 'Remove a device' })
  remove(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('deviceId') deviceId: string,
  ): Promise<Record<string, unknown>> {
    return this.notifications.removeDevice(principal.userId, deviceId);
  }
}
