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
import { CurrentUser } from '../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { BusinessMemberGuard } from '../memberships/business-member.guard';
import { RequireBusinessPermission } from '../memberships/require-permission.decorator';
import { BookingsService } from './bookings.service';
import {
  BusinessCancelBookingDto,
  ConfirmPayAtLocationDto,
  ListBusinessBookingsQueryDto,
  RequestRefundDto,
} from './dto/booking.dto';
import { PaymentsService } from './payments.service';
import { RefundsService } from './refunds.service';

@ApiTags('business-bookings')
@ApiBearerAuth()
@Controller('businesses')
@UseGuards(BusinessMemberGuard)
export class BusinessBookingsController {
  constructor(
    private readonly bookings: BookingsService,
    private readonly payments: PaymentsService,
    private readonly refunds: RefundsService,
  ) {}

  @Get(':businessId/bookings')
  @RequireBusinessPermission('booking.read')
  @ApiOperation({ summary: 'List business bookings (contract §65)' })
  list(
    @Param('businessId') businessId: string,
    @Query() query: ListBusinessBookingsQueryDto,
  ): ReturnType<BookingsService['listBusinessBookings']> {
    return this.bookings.listBusinessBookings(businessId, query);
  }

  @Get(':businessId/bookings/:bookingId')
  @RequireBusinessPermission('booking.read')
  @ApiOperation({ summary: 'Get business booking (contract §66)' })
  get(
    @Param('businessId') businessId: string,
    @Param('bookingId') bookingId: string,
  ): ReturnType<BookingsService['getBusinessBooking']> {
    return this.bookings.getBusinessBooking(businessId, bookingId);
  }

  @Post(':businessId/bookings/:bookingId/cancel')
  @HttpCode(200)
  @RequireBusinessPermission('booking.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Cancel booking as business (ADR 0040, contract §68.1)' })
  cancel(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('bookingId') bookingId: string,
    @Body() dto: BusinessCancelBookingDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<BookingsService['cancelBusinessBooking']> {
    return this.bookings.cancelBusinessBooking(
      principal.userId,
      businessId,
      bookingId,
      dto,
      idempotencyKey,
    );
  }

  @Post(':businessId/bookings/:bookingId/payments/pay-at-location/confirm')
  @HttpCode(200)
  @RequireBusinessPermission('payment.confirm')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Confirm pay-at-location payment (contract §73)' })
  confirmPayAtLocation(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('bookingId') bookingId: string,
    @Body() dto: ConfirmPayAtLocationDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<PaymentsService['confirmPayAtLocation']> {
    return this.payments.confirmPayAtLocation(
      principal.userId,
      businessId,
      bookingId,
      dto,
      idempotencyKey,
    );
  }

  @Post(':businessId/payments/:paymentId/refunds')
  @HttpCode(202)
  @RequireBusinessPermission('payment.refund')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Request refund (contract §74)' })
  requestRefund(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('paymentId') paymentId: string,
    @Body() dto: RequestRefundDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<RefundsService['requestRefund']> {
    return this.refunds.requestRefund(principal.userId, businessId, paymentId, dto, idempotencyKey);
  }
}
