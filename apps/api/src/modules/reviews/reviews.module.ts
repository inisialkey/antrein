import { Module } from '@nestjs/common';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { ReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';

/**
 * Reviews (§96–§97). Reads bookings for eligibility and updates the
 * denormalized rating aggregates on businesses/staff_profiles inside the
 * review transaction — that aggregate write is this module's output by
 * design (ADR 0038), not a bookings/businesses concern.
 */
@Module({
  imports: [IdempotencyModule],
  controllers: [ReviewsController],
  providers: [ReviewsService],
})
export class ReviewsModule {}
