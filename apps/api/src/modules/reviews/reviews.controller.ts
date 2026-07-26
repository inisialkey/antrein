import { Body, Controller, Get, Headers, HttpCode, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { Public } from '../auth/public.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { CreateReviewDto, ListReviewsQueryDto } from './dto/review.dto';
import { ReviewsService } from './reviews.service';

@ApiTags('reviews')
@Controller()
export class ReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Post('bookings/:bookingId/review')
  @HttpCode(201)
  @ApiBearerAuth()
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Create a review for a completed booking (contract §96)' })
  create(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('bookingId') bookingId: string,
    @Body() dto: CreateReviewDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<ReviewsService['createReview']> {
    return this.reviews.createReview(principal.userId, bookingId, dto, idempotencyKey);
  }

  @Public()
  @Get('businesses/:businessId/reviews')
  @ApiOperation({ summary: 'List business reviews with summary (contract §97)' })
  list(
    @Param('businessId') businessId: string,
    @Query() query: ListReviewsQueryDto,
  ): ReturnType<ReviewsService['listBusinessReviews']> {
    return this.reviews.listBusinessReviews(businessId, query);
  }
}
