import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { IdempotencyService } from '../idempotency/idempotency.service';
import {
  bookingNotFound,
  paymentAlreadyPaid,
  paymentAmountMismatch,
  paymentCurrencyMismatch,
  paymentNotFound,
} from './booking.errors';
import { paymentSummaryOf, toPaymentResource } from './booking.mapper';
import { summarizePayments } from './domain/payment-summary';
import { BookingsService } from './bookings.service';
import { ConfirmPayAtLocationDto } from './dto/booking.dto';

const PAYMENT_IDEMPOTENCY_RETENTION_HOURS = 24 * 7; // ADR 0034

/**
 * M6 payment slice: pay-at-location receipt + reads. The provider port,
 * webhooks and refunds extract this into modules/payments in M7.
 */
@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly audit: AuditService,
    private readonly bookings: BookingsService,
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
        if (!pending) {
          const alreadyPaid = booking.payments.some(
            (p) => p.provider === 'pay_at_location' && p.status === 'paid',
          );
          throw alreadyPaid ? paymentAlreadyPaid() : paymentNotFound();
        }
        const outstanding = summarizePayments(
          booking.snapshot?.servicePriceAmount ?? 0,
          booking.payments,
        ).remainingAmount;
        if (dto.amount.amount !== outstanding) throw paymentAmountMismatch(outstanding);

        const paidAt = new Date();
        await this.prisma.$transaction(async (tx) => {
          const updated = await tx.payment.updateMany({
            // Status guard makes two concurrent confirmations produce one effect.
            where: { id: pending.id, status: 'pending' },
            data: { status: 'paid', method: dto.method, paidAt, version: { increment: 1 } },
          });
          if (updated.count === 0) throw paymentAlreadyPaid();
          await this.audit.record(
            {
              actorUserId,
              businessId,
              outletId: booking.outletId,
              action: 'payment.pay_at_location_confirm',
              resourceType: 'payment',
              resourceId: pending.id,
              beforeData: { status: 'pending' },
              afterData: { status: 'paid', method: dto.method, amount: pending.amount },
              reason: dto.note,
            },
            tx,
          );
        });

        const refreshed = await this.bookings.requireBooking(bookingId);
        const paid = refreshed.payments.find((p) => p.id === pending.id);
        return {
          payment: paid ? toPaymentResource(paid) : null,
          bookingPaymentSummary: paymentSummaryOf(refreshed),
        };
      },
    });
  }
}
