import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { MembershipsModule } from '../memberships/memberships.module';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';
import { BusinessBookingsController } from './business-bookings.controller';
import { PaymentExpirationJob } from './payment-expiration.job';
import { PaymentTransitionService } from './payment-transition.service';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { RefundsController } from './refunds.controller';
import { RefundsService } from './refunds.service';
import { WebhooksController } from './webhooks.controller';

/**
 * Bookings + payments + refunds transactional slice. One module on purpose
 * (ponytail): webhook/cancel/expiration each mutate bookings AND payments in
 * one transaction, and the module-boundary rule forbids touching another
 * module's tables — a payments module would need forwardRef cycles for zero
 * isolation gain. Revisit when queue/realtime pressure justifies extraction.
 */
@Module({
  imports: [MembershipsModule, IdempotencyModule, AuditModule],
  controllers: [
    BookingsController,
    BusinessBookingsController,
    PaymentsController,
    RefundsController,
    WebhooksController,
  ],
  providers: [
    BookingsService,
    PaymentsService,
    PaymentTransitionService,
    RefundsService,
    PaymentExpirationJob,
  ],
  exports: [BookingsService],
})
export class BookingsModule {}
