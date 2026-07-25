import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';

/** Index = day_of_week smallint per database-design §22 (0 = Sunday). */
export const DAY_NAMES = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
] as const;

export type DayName = (typeof DAY_NAMES)[number];

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export class OperatingPeriodDto {
  @ApiProperty({ example: '09:00' })
  @IsString()
  opensAt!: string;

  @ApiProperty({ example: '21:00' })
  @IsString()
  closesAt!: string;
}

export class OperatingDayDto {
  @ApiProperty({ enum: DAY_NAMES })
  @IsIn(DAY_NAMES as readonly string[])
  dayOfWeek!: DayName;

  @ApiProperty({ example: false })
  @IsBoolean()
  isClosed!: boolean;

  @ApiProperty({ type: [OperatingPeriodDto] })
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => OperatingPeriodDto)
  periods!: OperatingPeriodDto[];
}

export class ReplaceOperatingHoursDto {
  @ApiProperty({ example: 'Asia/Jakarta' })
  @IsString()
  timezone!: string;

  @ApiProperty({ type: [OperatingDayDto] })
  @IsArray()
  @ArrayMaxSize(7)
  @ValidateNested({ each: true })
  @Type(() => OperatingDayDto)
  days!: OperatingDayDto[];
}

export class StaffPeriodDto {
  @ApiProperty({ example: '09:00' })
  @IsString()
  startsAt!: string;

  @ApiProperty({ example: '17:00' })
  @IsString()
  endsAt!: string;
}

export class StaffDayDto {
  @ApiProperty({ enum: DAY_NAMES })
  @IsIn(DAY_NAMES as readonly string[])
  dayOfWeek!: DayName;

  @ApiProperty({ example: true })
  @IsBoolean()
  isAvailable!: boolean;

  @ApiProperty({ type: [StaffPeriodDto] })
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => StaffPeriodDto)
  periods!: StaffPeriodDto[];

  @ApiPropertyOptional({ type: [StaffPeriodDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => StaffPeriodDto)
  breaks?: StaffPeriodDto[];
}

export class ReplaceStaffScheduleDto {
  @ApiProperty({ example: 'Asia/Jakarta' })
  @IsString()
  timezone!: string;

  @ApiProperty({ type: [StaffDayDto] })
  @IsArray()
  @ArrayMaxSize(7)
  @ValidateNested({ each: true })
  @Type(() => StaffDayDto)
  days!: StaffDayDto[];
}

export class CreateClosedDateDto {
  @ApiProperty({ example: '2026-08-17' })
  @Matches(DATE_RE, { message: 'date must use the YYYY-MM-DD format' })
  date!: string;

  @ApiPropertyOptional({ example: 'Public holiday' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  reason?: string;
}

export class ListClosedDatesQueryDto {
  @ApiPropertyOptional({ example: '2026-08-01' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'dateFrom must use the YYYY-MM-DD format' })
  dateFrom?: string;

  @ApiPropertyOptional({ example: '2026-08-31' })
  @IsOptional()
  @Matches(DATE_RE, { message: 'dateTo must use the YYYY-MM-DD format' })
  dateTo?: string;
}

export class AvailabilityQueryDto {
  @ApiProperty({ example: 'out_01J...' })
  @IsString()
  outletId!: string;

  @ApiProperty({ example: 'svc_01J...' })
  @IsString()
  serviceId!: string;

  @ApiPropertyOptional({ example: 'stf_01J...', description: 'Required in MVP (ADR 0019).' })
  @IsOptional()
  @IsString()
  staffId?: string;

  @ApiProperty({ example: '2026-07-25' })
  @Matches(DATE_RE, { message: 'date must use the YYYY-MM-DD format' })
  date!: string;
}
