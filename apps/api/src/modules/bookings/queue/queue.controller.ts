import { Body, Controller, Get, Headers, HttpCode, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../../auth/token.service';
import { CheckInDto } from './dto/queue.dto';
import { QueueService } from './queue.service';

@ApiTags('queue')
@ApiBearerAuth()
@Controller('bookings')
export class QueueController {
  constructor(private readonly queue: QueueService) {}

  @Post(':bookingId/check-in')
  @HttpCode(200)
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Check in a booking (contract §64)' })
  checkIn(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('bookingId') bookingId: string,
    @Body() dto: CheckInDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<QueueService['checkIn']> {
    return this.queue.checkIn(principal.userId, bookingId, dto, idempotencyKey);
  }

  @Get(':bookingId/queue')
  @ApiOperation({ summary: 'Get own queue state (contract §81)' })
  getQueue(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('bookingId') bookingId: string,
  ): ReturnType<QueueService['getCustomerQueue']> {
    return this.queue.getCustomerQueue(principal.userId, bookingId);
  }
}
