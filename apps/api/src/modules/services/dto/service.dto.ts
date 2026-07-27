import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { ListQueryDto } from '../../businesses/dto/business.dto';

export class MoneyDto {
  @ApiProperty({ example: 50000 })
  @IsInt()
  amount!: number;

  @ApiProperty({ example: 'IDR' })
  @IsString()
  @MaxLength(3)
  currency!: string;
}

export class DepositDto {
  // Domain-validated in the service (SERVICE_INVALID_DEPOSIT, ADR 0022 fixed-only).
  @ApiProperty({ enum: ['none', 'fixed', 'percentage'] })
  @IsString()
  @MaxLength(20)
  type!: string;

  @ApiProperty({ example: 10000 })
  @IsInt()
  value!: number;
}

export class CreateServiceDto {
  @ApiProperty({ example: 'Haircut' })
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
  imageFileId?: string;

  @ApiProperty({ example: 45 })
  @IsInt()
  durationMinutes!: number;

  @ApiProperty({ type: MoneyDto })
  @ValidateNested()
  @Type(() => MoneyDto)
  price!: MoneyDto;

  @ApiPropertyOptional({ type: DepositDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => DepositDto)
  deposit?: DepositDto;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  eligibleStaffIds?: string[];

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateServiceDto {
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
  imageFileId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  durationMinutes?: number;

  @ApiPropertyOptional({ type: MoneyDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => MoneyDto)
  price?: MoneyDto;

  @ApiPropertyOptional({ type: DepositDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => DepositDto)
  deposit?: DepositDto;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  eligibleStaffIds?: string[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class ListServicesQueryDto extends ListQueryDto {
  // Reserved in v1: services are business-scoped, not outlet-scoped (MVP).
  @ApiPropertyOptional({ description: 'Reserved in v1' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  outletId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(50)
  staffId?: string;

  @ApiPropertyOptional({ default: 'true' })
  @IsOptional()
  @IsString()
  activeOnly?: string;
}
