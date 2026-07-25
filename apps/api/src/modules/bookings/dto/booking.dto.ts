import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { BOOKING_STATUSES } from '../domain/booking-status.policy';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const ISO_INSTANT_RE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(\.\d+)?([+-]\d{2}:\d{2}|Z)$/;

export const PAYMENT_OPTIONS = ['pay_at_location', 'full_payment', 'deposit'] as const;
export const PAY_AT_LOCATION_METHODS = [
  'cash',
  'qris_manual',
  'bank_transfer_manual',
  'card_terminal',
  'other',
] as const;
const PAYMENT_STATUSES = [
  'pending',
  'paid',
  'failed',
  'expired',
  'cancelled',
  'refund_pending',
  'partially_refunded',
  'refunded',
] as const;

export class MoneyDto {
  @ApiProperty({ example: 50000 })
  @IsInt()
  @Min(0)
  amount!: number;

  @ApiProperty({ example: 'IDR' })
  @IsString()
  currency!: string;
}

export class StaffSelectionDto {
  @ApiProperty({ enum: ['specific_staff', 'any_available'] })
  @IsIn(['specific_staff', 'any_available'])
  mode!: 'specific_staff' | 'any_available';

  @ApiPropertyOptional({ example: 'stf_01J...' })
  @IsOptional()
  @IsString()
  staffId?: string;
}

export class CreateBookingDto {
  @ApiProperty({ example: 'biz_01J...' })
  @IsString()
  businessId!: string;

  @ApiProperty({ example: 'out_01J...' })
  @IsString()
  outletId!: string;

  @ApiProperty({ example: 'svc_01J...' })
  @IsString()
  serviceId!: string;

  @ApiProperty({ type: StaffSelectionDto })
  @ValidateNested()
  @Type(() => StaffSelectionDto)
  staffSelection!: StaffSelectionDto;

  @ApiProperty({ example: '2026-07-26T10:00:00+07:00' })
  @Matches(ISO_INSTANT_RE, { message: 'scheduledAt must be an ISO 8601 timestamp with offset' })
  scheduledAt!: string;

  @ApiProperty({ enum: PAYMENT_OPTIONS })
  @IsIn(PAYMENT_OPTIONS as readonly string[])
  paymentOption!: (typeof PAYMENT_OPTIONS)[number];

  @ApiPropertyOptional({ example: 'Please use scissors only.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  customerNotes?: string;
}

export class CancelBookingDto {
  @ApiPropertyOptional({ example: 'customer_changed_plan' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  reasonCode?: string;

  @ApiPropertyOptional({ example: 'I am no longer available.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

/** ADR 0040: business cancellation requires a reason. */
export class BusinessCancelBookingDto {
  @ApiProperty({ example: 'business_unavailable' })
  @IsString()
  @MaxLength(100)
  reasonCode!: string;

  @ApiProperty({ example: 'Staff member is ill.' })
  @IsString()
  @MaxLength(500)
  reason!: string;
}

export class ConfirmPayAtLocationDto {
  @ApiProperty({ type: MoneyDto })
  @ValidateNested()
  @Type(() => MoneyDto)
  amount!: MoneyDto;

  @ApiProperty({ enum: PAY_AT_LOCATION_METHODS })
  @IsIn(PAY_AT_LOCATION_METHODS as readonly string[])
  method!: (typeof PAY_AT_LOCATION_METHODS)[number];

  @ApiPropertyOptional({ example: 'Paid at front desk.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class RequestRefundDto {
  @ApiProperty({ type: MoneyDto })
  @ValidateNested()
  @Type(() => MoneyDto)
  amount!: MoneyDto;

  @ApiProperty({ example: 'booking_cancelled' })
  @IsString()
  @MaxLength(100)
  reasonCode!: string;

  @ApiPropertyOptional({ example: 'Customer cancelled within full-refund window.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class ListCustomerBookingsQueryDto {
  @ApiPropertyOptional({ enum: BOOKING_STATUSES })
  @IsOptional()
  @IsIn(BOOKING_STATUSES as readonly string[])
  status?: string;

  @ApiPropertyOptional({ example: '2026-07-01' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'dateFrom must use the YYYY-MM-DD format' })
  dateFrom?: string;

  @ApiPropertyOptional({ example: '2026-07-31' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'dateTo must use the YYYY-MM-DD format' })
  dateTo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ example: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class ListBusinessBookingsQueryDto extends ListCustomerBookingsQueryDto {
  @ApiPropertyOptional({ example: 'out_01J...' })
  @IsOptional()
  @IsString()
  outletId?: string;

  @ApiPropertyOptional({ example: 'stf_01J...' })
  @IsOptional()
  @IsString()
  staffId?: string;

  @ApiPropertyOptional({ example: '2026-07-26', description: 'Exact business date.' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'date must use the YYYY-MM-DD format' })
  date?: string;

  @ApiPropertyOptional({ enum: ['scheduled', 'walk_in'] })
  @IsOptional()
  @IsIn(['scheduled', 'walk_in'])
  type?: string;

  @ApiPropertyOptional({ enum: PAYMENT_STATUSES })
  @IsOptional()
  @IsIn(PAYMENT_STATUSES as readonly string[])
  paymentStatus?: string;
}
