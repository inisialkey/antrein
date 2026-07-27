import { Body, Controller, Get, Headers, HttpCode, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { BookingsService } from './bookings.service';
import {
  CancelBookingDto,
  CreateBookingDto,
  ListCustomerBookingsQueryDto,
} from './dto/booking.dto';
import { PaymentsService } from './payments.service';

@ApiTags('bookings')
@ApiBearerAuth()
@Controller('bookings')
export class BookingsController {
  constructor(
    private readonly bookings: BookingsService,
    private readonly payments: PaymentsService,
  ) {}

  @Post()
  @HttpCode(201)
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Create a booking (contract §60)' })
  create(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Body() dto: CreateBookingDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<BookingsService['createBooking']> {
    return this.bookings.createBooking(principal.userId, dto, idempotencyKey);
  }

  @Get()
  @ApiOperation({ summary: 'List own bookings' })
  list(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Query() query: ListCustomerBookingsQueryDto,
  ): ReturnType<BookingsService['listCustomerBookings']> {
    return this.bookings.listCustomerBookings(principal.userId, query);
  }

  @Get(':bookingId')
  @ApiOperation({ summary: 'Get own booking' })
  get(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('bookingId') bookingId: string,
  ): ReturnType<BookingsService['getCustomerBooking']> {
    return this.bookings.getCustomerBooking(principal.userId, bookingId);
  }

  @Post(':bookingId/cancel')
  @HttpCode(200)
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Cancel own booking (contract §63)' })
  cancel(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('bookingId') bookingId: string,
    @Body() dto: CancelBookingDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<BookingsService['cancelCustomerBooking']> {
    return this.bookings.cancelCustomerBooking(principal.userId, bookingId, dto, idempotencyKey);
  }

  @Get(':bookingId/payments')
  @ApiOperation({ summary: 'List payments of a booking (contract §70)' })
  listPayments(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('bookingId') bookingId: string,
  ): ReturnType<PaymentsService['listBookingPayments']> {
    return this.payments.listBookingPayments(principal.userId, bookingId);
  }
}
