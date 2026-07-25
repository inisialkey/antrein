import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../../auth/token.service';
import { BusinessMemberGuard } from '../../memberships/business-member.guard';
import { RequireBusinessPermission } from '../../memberships/require-permission.decorator';
import {
  CompleteServiceDto,
  CreateWalkInDto,
  NoShowBookingDto,
  NoShowQueueEntryDto,
  OutletQueueQueryDto,
  QueueCommandDto,
  ReorderQueueDto,
  SkipQueueEntryDto,
  StartServiceDto,
} from './dto/queue.dto';
import { QueueCommandsService } from './queue-commands.service';

@ApiTags('business-queue')
@ApiBearerAuth()
@Controller('businesses')
@UseGuards(BusinessMemberGuard)
export class BusinessQueueController {
  constructor(private readonly queue: QueueCommandsService) {}

  @Get(':businessId/outlets/:outletId/queue')
  @RequireBusinessPermission('queue.read')
  @ApiOperation({ summary: 'Get outlet queue snapshot (contract §82)' })
  snapshot(
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
    @Query() query: OutletQueueQueryDto,
  ): ReturnType<QueueCommandsService['getOutletSnapshot']> {
    return this.queue.getOutletSnapshot(businessId, outletId, query);
  }

  @Post(':businessId/walk-ins')
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Create a walk-in booking + queue entry (contract §67)' })
  walkIn(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Body() dto: CreateWalkInDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['createWalkIn']> {
    return this.queue.createWalkIn(principal.userId, businessId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/call')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Call a queue entry (contract §83)' })
  call(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: QueueCommandDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['call']> {
    return this.queue.call(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/recall')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Recall a called entry (contract §84)' })
  recall(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: QueueCommandDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['recall']> {
    return this.queue.recall(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/skip')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Skip a called entry (contract §85)' })
  skip(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: SkipQueueEntryDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['skip']> {
    return this.queue.skip(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/return-to-waiting')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Return a skipped entry to waiting (contract §86)' })
  returnToWaiting(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: QueueCommandDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['returnToWaiting']> {
    return this.queue.returnToWaiting(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/start-service')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Start service (contract §87)' })
  startService(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: StartServiceDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['startService']> {
    return this.queue.startService(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/complete')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Complete service (contract §88)' })
  complete(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: CompleteServiceDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['complete']> {
    return this.queue.complete(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/queue/:queueEntryId/no-show')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Mark a queue entry no-show (contract §89)' })
  noShowEntry(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('queueEntryId') queueEntryId: string,
    @Body() dto: NoShowQueueEntryDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['markNoShowEntry']> {
    return this.queue.markNoShowEntry(principal.userId, businessId, queueEntryId, dto, key);
  }

  @Post(':businessId/bookings/:bookingId/no-show')
  @HttpCode(200)
  @RequireBusinessPermission('queue.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Mark a booking no-show before check-in (contract §68)' })
  noShowBooking(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('bookingId') bookingId: string,
    @Body() dto: NoShowBookingDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['markNoShowBooking']> {
    return this.queue.markNoShowBooking(principal.userId, businessId, bookingId, dto, key);
  }

  @Post(':businessId/outlets/:outletId/queue/reorder')
  @HttpCode(200)
  @RequireBusinessPermission('queue.reorder')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Reorder the outlet queue (contract §90)' })
  reorder(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
    @Body() dto: ReorderQueueDto,
    @Headers('idempotency-key') key: string | undefined,
  ): ReturnType<QueueCommandsService['reorder']> {
    return this.queue.reorder(principal.userId, businessId, outletId, dto, key);
  }
}
