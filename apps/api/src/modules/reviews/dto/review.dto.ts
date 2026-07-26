import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateReviewDto {
  // Range (1–5) is checked in the service so it maps to REVIEW_RATING_INVALID
  // (contract §123) instead of the generic VALIDATION_FAILED.
  @ApiProperty({ minimum: 1, maximum: 5, example: 5 })
  @IsInt()
  rating!: number;

  @ApiPropertyOptional({ maxLength: 1000 })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  comment?: string;
}

export const REVIEW_SORTS = ['newest', 'oldest', 'rating_desc', 'rating_asc'] as const;
export type ReviewSort = (typeof REVIEW_SORTS)[number];

export class ListReviewsQueryDto {
  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  rating?: number;

  @ApiPropertyOptional({ enum: REVIEW_SORTS, default: 'newest' })
  @IsOptional()
  @IsIn(REVIEW_SORTS)
  sort?: ReviewSort;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  limit?: number;
}
