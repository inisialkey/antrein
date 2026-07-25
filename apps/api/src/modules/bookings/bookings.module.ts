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
import { BusinessQueueController } from './queue/business-queue.controller';
import { QueueController } from './queue/queue.controller';
import { QueueCommandsService } from './queue/queue-commands.service';
import { QueueService } from './queue/queue.service';

/**
 * Bookings + payments + refunds + queue transactional slice. One module on
 * purpose (ponytail): webhook/cancel/expiration/check-in each mutate bookings
 * AND payments/queue in one transaction, and the module-boundary rule forbids
 * touching another module's tables — a separate module would need forwardRef
 * cycles (walk-in creates a booking; queue commands drive booking status) for
 * zero isolation gain. The realtime-queue §72 `modules/queues` layout is the
 * target for when WebSocket/outbox extraction justifies it.
 */
@Module({
  imports: [MembershipsModule, IdempotencyModule, AuditModule],
  controllers: [
    BookingsController,
    BusinessBookingsController,
    PaymentsController,
    RefundsController,
    WebhooksController,
    QueueController,
    BusinessQueueController,
  ],
  providers: [
    BookingsService,
    PaymentsService,
    PaymentTransitionService,
    RefundsService,
    PaymentExpirationJob,
    QueueService,
    QueueCommandsService,
  ],
  exports: [BookingsService],
})
export class BookingsModule {}
