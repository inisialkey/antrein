import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayNotEmpty,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
export const CHECK_IN_METHODS = ['customer_app', 'staff_assisted', 'qr'] as const;

export class CheckInDto {
  @ApiPropertyOptional({ enum: CHECK_IN_METHODS, default: 'customer_app' })
  @IsOptional()
  @IsIn(CHECK_IN_METHODS as readonly string[])
  method?: (typeof CHECK_IN_METHODS)[number];
}

export class WalkInCustomerDto {
  @ApiProperty({ example: 'Walk-In Customer' })
  @IsString()
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional({ example: '+6281234567890' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  phoneNumber?: string;
}

export class WalkInStaffSelectionDto {
  @ApiProperty({ enum: ['specific_staff', 'any_available'] })
  @IsIn(['specific_staff', 'any_available'])
  mode!: 'specific_staff' | 'any_available';

  @ApiPropertyOptional({ example: 'stf_01J...' })
  @IsOptional()
  @IsString()
  staffId?: string;
}

export class CreateWalkInDto {
  @ApiProperty({ example: 'out_01J...' })
  @IsString()
  outletId!: string;

  @ApiProperty({ type: WalkInCustomerDto })
  @ValidateNested()
  @Type(() => WalkInCustomerDto)
  customer!: WalkInCustomerDto;

  @ApiProperty({ example: 'svc_01J...' })
  @IsString()
  serviceId!: string;

  @ApiProperty({ type: WalkInStaffSelectionDto })
  @ValidateNested()
  @Type(() => WalkInStaffSelectionDto)
  staffSelection!: WalkInStaffSelectionDto;

  // Walk-ins settle at the location; online provider flows are out of MVP scope (§31).
  @ApiProperty({ enum: ['pay_at_location'] })
  @IsIn(['pay_at_location'])
  paymentOption!: 'pay_at_location';

  @ApiPropertyOptional({ example: null })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

/** call / recall / return-to-waiting share the bare version envelope. */
export class QueueCommandDto {
  @ApiProperty({ example: 4 })
  @IsInt()
  @Min(1)
  expectedVersion!: number;
}

export class SkipQueueEntryDto extends QueueCommandDto {
  @ApiPropertyOptional({ example: 'Customer is temporarily unavailable.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class StartServiceDto extends QueueCommandDto {
  @ApiPropertyOptional({ example: 'stf_01J...' })
  @IsOptional()
  @IsString()
  staffId?: string;
}

export class CompleteServiceDto extends QueueCommandDto {
  @ApiPropertyOptional({ example: 'Service completed successfully.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  internalNote?: string;
}

export class NoShowQueueEntryDto extends QueueCommandDto {
  @ApiPropertyOptional({ example: 'Customer did not respond after recall.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

/** §68 booking-level no-show: booking never entered the queue, so no version. */
export class NoShowBookingDto {
  @ApiPropertyOptional({ example: 'Customer did not arrive within the allowed window.' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class ReorderQueueDto {
  @ApiProperty({ example: '2026-07-22' })
  @Matches(DATE_RE, { message: 'businessDate must use the YYYY-MM-DD format' })
  businessDate!: string;

  @ApiProperty({ example: 18 })
  @IsInt()
  @Min(1)
  expectedQueueVersion!: number;

  @ApiProperty({ example: ['que_01J_A', 'que_01J_B'] })
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  orderedQueueEntryIds!: string[];

  @ApiProperty({ example: 'Customer with appointment priority arrived.' })
  @IsString()
  @MaxLength(500)
  reason!: string;
}

export class OutletQueueQueryDto {
  @ApiPropertyOptional({ example: '2026-07-22', description: 'Business date; defaults to today.' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'date must use the YYYY-MM-DD format' })
  date?: string;

  @ApiPropertyOptional({ example: 'waiting' })
  @IsOptional()
  @IsString()
  status?: string;
}
