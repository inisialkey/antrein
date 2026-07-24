import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export const PAYMENT_OPTION_LABELS = ['pay_at_location', 'full_payment', 'deposit'] as const;
export type PaymentOptionLabel = (typeof PAYMENT_OPTION_LABELS)[number];

export class AddressDto {
  @ApiProperty({ example: 'Jl. Example No. 10, Jakarta' })
  @IsString()
  @Length(5, 500)
  formatted!: string;

  @ApiPropertyOptional({ example: -6.2 })
  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude?: number;

  @ApiPropertyOptional({ example: 106.8 })
  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude?: number;
}

export class CreateOutletDto {
  @ApiProperty({ example: 'Main Outlet' })
  @IsString()
  @Length(2, 100)
  name!: string;

  @ApiPropertyOptional({ example: '+622112345678' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneNumber?: string;

  @ApiProperty({ type: AddressDto })
  @ValidateNested()
  @Type(() => AddressDto)
  address!: AddressDto;
}

export class CreateBusinessDto {
  @ApiProperty({ example: 'AntreIn Barbershop' })
  @IsString()
  @Length(2, 100)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional({ example: 'fil_01J...' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  logoFileId?: string;

  @ApiPropertyOptional({ example: 'Asia/Jakarta' })
  @IsOptional()
  @IsIn(['Asia/Jakarta'])
  timezone?: string;

  @ApiProperty({ type: CreateOutletDto })
  @ValidateNested()
  @Type(() => CreateOutletDto)
  primaryOutlet!: CreateOutletDto;
}

export class BookingPolicyDto {
  @ApiPropertyOptional({ example: 60 })
  @IsOptional()
  @IsInt()
  @Min(0)
  minimumLeadMinutes?: number;

  @ApiPropertyOptional({ example: 30 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(365)
  maximumAdvanceDays?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  automaticConfirmation?: boolean;
}

export class DepositPolicyDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  enabled!: boolean;

  // Fixed-only deposits in MVP (ADR 0022); 'percentage' returns post-MVP.
  @ApiPropertyOptional({ enum: ['none', 'fixed'] })
  @IsOptional()
  @IsIn(['none', 'fixed'])
  defaultType?: 'none' | 'fixed';

  @ApiPropertyOptional({ example: 10000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  defaultValue?: number;
}

export class CancellationPolicyDto {
  @ApiPropertyOptional({ example: 360 })
  @IsOptional()
  @IsInt()
  @Min(0)
  fullRefundBeforeMinutes?: number;

  @ApiPropertyOptional({ example: 120 })
  @IsOptional()
  @IsInt()
  @Min(0)
  partialRefundBeforeMinutes?: number;

  @ApiPropertyOptional({ example: 50 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  partialRefundPercentage?: number;

  @ApiPropertyOptional({ example: 0 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  noShowRefundPercentage?: number;
}

export class UpdateBusinessDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 100)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(50)
  logoFileId?: string;

  // Validated in the service so unknown labels return PAYMENT_OPTION_NOT_SUPPORTED.
  @ApiPropertyOptional({ enum: PAYMENT_OPTION_LABELS, isArray: true })
  @IsOptional()
  @IsString({ each: true })
  supportedPaymentOptions?: string[];

  @ApiPropertyOptional({ type: BookingPolicyDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => BookingPolicyDto)
  bookingPolicy?: BookingPolicyDto;

  @ApiPropertyOptional({ type: DepositPolicyDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => DepositPolicyDto)
  depositPolicy?: DepositPolicyDto;

  @ApiPropertyOptional({ type: CancellationPolicyDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => CancellationPolicyDto)
  cancellationPolicy?: CancellationPolicyDto;
}

export class UpdateOutletDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Length(2, 100)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneNumber?: string;

  @ApiPropertyOptional({ example: 'Asia/Jakarta' })
  @IsOptional()
  @IsIn(['Asia/Jakarta'])
  timezone?: string;

  @ApiPropertyOptional({ type: AddressDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => AddressDto)
  address?: AddressDto;
}

export class ListQueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  cursor?: string;

  @ApiPropertyOptional({ default: 20, maximum: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class ListBusinessesQueryDto extends ListQueryDto {
  @ApiPropertyOptional({ description: 'Name search' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(50)
  serviceId?: string;

  // Reserved in v1 (ADR 0034): accepted, never evaluated.
  @ApiPropertyOptional({ description: 'Reserved in v1' })
  @IsOptional()
  latitude?: string;

  @ApiPropertyOptional({ description: 'Reserved in v1' })
  @IsOptional()
  longitude?: string;

  @ApiPropertyOptional({ description: 'Reserved in v1' })
  @IsOptional()
  radiusKm?: string;

  @ApiPropertyOptional({ enum: ['recommended', 'rating_desc', 'name_asc'] })
  @IsOptional()
  @IsIn(['recommended', 'rating_desc', 'name_asc'])
  sort?: 'recommended' | 'rating_desc' | 'name_asc';
}
