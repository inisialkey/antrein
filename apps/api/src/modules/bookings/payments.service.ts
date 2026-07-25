import { Inject, Injectable, Optional } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { PaymentProviderPort } from '../../infrastructure/payments/payment-provider.port';
import { AuditService } from '../audit/audit.service';
import { IdempotencyService } from '../idempotency/idempotency.service';
import {
  bookingNotFound,
  paymentAlreadyPaid,
  paymentAmountMismatch,
  paymentCurrencyMismatch,
  paymentNotFound,
  paymentStatusRefreshRateLimited,
} from './booking.errors';
import { paymentSummaryOf, toPaymentResource } from './booking.mapper';
import { summarizePayments } from './domain/payment-summary';
import { BookingsService } from './bookings.service';
import { PaymentTransitionService } from './payment-transition.service';
import { RefundsService } from './refunds.service';
import { ConfirmPayAtLocationDto } from './dto/booking.dto';

const PAYMENT_IDEMPOTENCY_RETENTION_HOURS = 24 * 7; // ADR 0034
// ponytail: per-instance in-memory refresh throttle; Redis when multi-instance.
const REFRESH_MIN_INTERVAL_MS = 10_000;

/** Payment reads, pay-at-location receipts, synchronous status refresh (ADR 0029). */
@Injectable()
export class PaymentsService {
  private readonly lastRefreshAt = new Map<string, number>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly audit: AuditService,
    private readonly bookings: BookingsService,
    private readonly transitions: PaymentTransitionService,
    private readonly refunds: RefundsService,
    @Optional()
    @Inject(PaymentProviderPort)
    private readonly provider: PaymentProviderPort | null,
  ) {}

  async getPayment(userId: string, paymentId: string): Promise<Record<string, unknown>> {
    const payment = await this.prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment) throw paymentNotFound();
    try {
      await this.bookings.assertCanReadBookingPayments(userId, {
        customerUserId: payment.customerUserId,
        businessId: payment.businessId,
      });
    } catch {
      // Do not reveal foreign payment existence.
      throw paymentNotFound();
    }
    return toPaymentResource(payment);
  }

  async listBookingPayments(
    userId: string,
    bookingId: string,
  ): Promise<{ items: Record<string, unknown>[] }> {
    const booking = await this.bookings.requireBooking(bookingId);
    await this.bookings.assertCanReadBookingPayments(userId, booking);
    return {
      items: [...booking.payments]
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
        .map(toPaymentResource),
    };
  }

  /**
   * §72 + ADR 0029: query the provider synchronously and push the result
   * through the same transition path as webhooks. Provider trouble returns the
   * stored state with refreshedFromProvider: false — never a 5xx.
   */
  async refreshPayment(userId: string, paymentId: string): Promise<Record<string, unknown>> {
    const payment = await this.prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment) throw paymentNotFound();
    try {
      await this.bookings.assertCanReadBookingPayments(userId, {
        customerUserId: payment.customerUserId,
        businessId: payment.businessId,
      });
    } catch {
      throw paymentNotFound();
    }

    const respond = async (refreshedFromProvider: boolean): Promise<Record<string, unknown>> => {
      const fresh = await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
      const booking = await this.prisma.booking.findUniqueOrThrow({
        where: { id: fresh.bookingId },
        select: { status: true },
      });
      return {
        payment: toPaymentResource(fresh),
        bookingStatus: booking.status,
        refreshedFromProvider,
      };
    };

    if (!this.provider || payment.provider === 'pay_at_location' || !payment.providerReference) {
      return respond(false);
    }

    const last = this.lastRefreshAt.get(paymentId) ?? 0;
    const now = Date.now();
    if (now - last < REFRESH_MIN_INTERVAL_MS) throw paymentStatusRefreshRateLimited();
    this.lastRefreshAt.set(paymentId, now);

    let status;
    try {
      status = await this.provider.getPaymentStatus(payment.providerReference);
    } catch {
      return respond(false);
    }
    const applied = await this.transitions.applyProviderEvent(
      {
        eventId: status.eventId,
        type: `payment.${status.status}`,
        providerReference: status.providerReference,
        status: status.status,
        amount: status.amount,
        currency: status.currency,
        occurredAt: status.occurredAt,
      },
      { signatureValid: true },
    );
    if (applied.lateRefund) await this.refunds.refundLatePayment(applied.lateRefund);
    return respond(true);
  }

  async confirmPayAtLocation(
    actorUserId: string,
    businessId: string,
    bookingId: string,
    dto: ConfirmPayAtLocationDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `payment.pal_confirm:${bookingId}`,
      key: idempotencyKey,
      payload: dto,
      retentionHours: PAYMENT_IDEMPOTENCY_RETENTION_HOURS,
      run: async () => {
        const booking = await this.bookings.requireBooking(bookingId);
        if (booking.businessId !== businessId) throw bookingNotFound();
        if (dto.amount.currency !== 'IDR') throw paymentCurrencyMismatch();

        const pending = booking.payments.find(
          (p) => p.provider === 'pay_at_location' && p.status === 'pending',
        );
        const outstanding = summarizePayments(
          booking.snapshot?.servicePriceAmount ?? 0,
          booking.payments,
        ).remainingAmount;
        if (!pending && outstanding <= 0) throw paymentAlreadyPaid();
        if (dto.amount.amount !== outstanding) throw paymentAmountMismatch(outstanding);

        const paidAt = new Date();
        const paymentId = pending?.id ?? newId('pay');
        await this.prisma.$transaction(async (tx) => {
          if (pending) {
            const updated = await tx.payment.updateMany({
              // Status guard makes two concurrent confirmations produce one effect.
              where: { id: pending.id, status: 'pending' },
              data: { status: 'paid', method: dto.method, paidAt, version: { increment: 1 } },
            });
            if (updated.count === 0) throw paymentAlreadyPaid();
          } else {
            // §45: settle the remainder of an online deposit at the outlet —
            // recorded as its own pay-at-location receipt row.
            await tx.payment.create({
              data: {
                id: paymentId,
                bookingId,
                businessId,
                customerUserId: booking.customerUserId,
                provider: 'pay_at_location',
                paymentOption: 'pay_at_location',
                status: 'paid',
                amount: outstanding,
                method: dto.method,
                paidAt,
              },
            });
          }
          await this.audit.record(
            {
              actorUserId,
              businessId,
              outletId: booking.outletId,
              action: 'payment.pay_at_location_confirm',
              resourceType: 'payment',
              resourceId: paymentId,
              beforeData: { status: pending ? 'pending' : null },
              afterData: { status: 'paid', method: dto.method, amount: outstanding },
              reason: dto.note,
            },
            tx,
          );
        });

        const refreshed = await this.bookings.requireBooking(bookingId);
        const paid = refreshed.payments.find((p) => p.id === paymentId);
        return {
          payment: paid ? toPaymentResource(paid) : null,
          bookingPaymentSummary: paymentSummaryOf(refreshed),
        };
      },
    });
  }
}
