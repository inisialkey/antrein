import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, Length, MaxLength } from 'class-validator';

export class UpdateMeDto {
  @ApiPropertyOptional({ example: 'Oki Key' })
  @IsOptional()
  @IsString()
  @Length(2, 100)
  name?: string;

  /** Explicit null clears the number; omitted leaves it untouched. */
  @ApiPropertyOptional({ example: '+6281234567890', nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  phoneNumber?: string | null;

  @ApiPropertyOptional({ example: 'fil_01J...', nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  avatarFileId?: string | null;
}

export class UpdateNotificationPreferencesDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  bookingUpdates?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  paymentUpdates?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  queueUpdates?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  marketing?: boolean;
}
