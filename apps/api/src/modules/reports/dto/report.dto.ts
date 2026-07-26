import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, Matches } from 'class-validator';

export class DailySummaryQueryDto {
  @ApiProperty({ example: 'out_01J...' })
  @IsString()
  outletId!: string;

  @ApiPropertyOptional({ example: '2026-07-22', description: 'Defaults to today (Asia/Jakarta)' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date?: string;
}
