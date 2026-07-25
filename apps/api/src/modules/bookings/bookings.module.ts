import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { MembershipsModule } from '../memberships/memberships.module';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { BusinessBookingsController } from './business-bookings.controller';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

/**
 * Bookings + M6 payment slice. The provider port, webhooks and refunds split
 * payments into its own module in M7.
 */
@Module({
  imports: [MembershipsModule, IdempotencyModule, AuditModule],
  controllers: [BookingsController, BusinessBookingsController, PaymentsController],
  providers: [BookingsService, PaymentsService],
  exports: [BookingsService],
})
export class BookingsModule {}
