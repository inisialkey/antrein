import { Inject, Injectable, Optional } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { MetricsService } from '../../infrastructure/metrics/metrics.service';
import {
  ParsedProviderEvent,
  PaymentProviderPort,
} from '../../infrastructure/payments/payment-provider.port';
import { Prisma } from '../../generated/prisma/client';
import { canTransitionPayment, PaymentStatus } from './domain/payment-status.policy';

export interface AppliedProviderEvent {
  outcome: 'processed' | 'duplicate' | 'ignored' | 'manual_review';
  errorCode?: string;
  paymentId?: string;
  paymentStatus?: string;
  bookingId?: string;
  bookingStatus?: string;
  /** Set when a verified success arrived too late to honor (ADR 0040 §30). */
  lateRefund?: { paymentId: string; bookingId: string; businessId: string; amount: number };
}

/**
 * The single idempotent transition path shared by webhook delivery and
 * synchronous refresh (ADR 0029): dedupe on (provider, provider_event_id),
 * lock the payment, validate, apply payment + booking transitions atomically.
 */
@Injectable()
export class PaymentTransitionService {
  constructor(
    private readonly prisma: PrismaService,
    @Optional()
    @Inject(PaymentProviderPort)
    private readonly provider: PaymentProviderPort | null,
    @Optional()
    private readonly metrics?: MetricsService,
  ) {}

  async applyProviderEvent(
    event: ParsedProviderEvent,
    opts: { signatureValid: boolean },
  ): Promise<AppliedProviderEvent> {
    const eventRowId = newId('evt');
    const payload = {
      eventId: event.eventId,
      type: event.type,
      providerReference: event.providerReference,
      status: event.status,
      amount: event.amount,
      currency: event.currency,
      occurredAt: event.occurredAt.toISOString(),
    };

    const providerName = this.provider?.provider ?? 'unknown';
    const existing = await this.prisma.paymentEvent.findUnique({
      where: {
        provider_providerEventId: { provider: providerName, providerEventId: event.eventId },
      },
    });
    // §36: duplicate events acknowledge without repeating effects.
    if (existing) return { outcome: 'duplicate' };

    return this.prisma.$transaction(async (tx) => {
      try {
        await tx.paymentEvent.create({
          data: {
            id: eventRowId,
            provider: providerName,
            providerEventId: event.eventId,
            eventType: event.type,
            signatureValid: opts.signatureValid,
            amount: event.amount,
            currency: event.currency,
            payload: payload as Prisma.InputJsonValue,
          },
        });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          // Raced duplicate — return before any further statement touches the
          // aborted transaction.
          return { outcome: 'duplicate' as const };
        }
        throw error;
      }

      const payment = await tx.payment.findFirst({
        where: { provider: providerName, providerReference: event.providerReference },
      });
      if (!payment) {
        await this.closeEvent(tx, eventRowId, 'manual_review', 'PAYMENT_WEBHOOK_PAYMENT_NOT_FOUND');
        return {
          outcome: 'manual_review' as const,
          errorCode: 'PAYMENT_WEBHOOK_PAYMENT_NOT_FOUND',
        };
      }

      // Serialize against the expiration worker and concurrent deliveries.
      await tx.$queryRaw`SELECT id FROM payments WHERE id = ${payment.id} FOR UPDATE`;
      const locked = await tx.payment.findUniqueOrThrow({ where: { id: payment.id } });

      if (event.amount !== locked.amount || event.currency !== locked.currency) {
        const code =
          event.currency !== locked.currency
            ? 'PAYMENT_WEBHOOK_CURRENCY_MISMATCH'
            : 'PAYMENT_WEBHOOK_AMOUNT_MISMATCH';
        await this.closeEvent(tx, eventRowId, 'manual_review', code, payment.id);
        return { outcome: 'manual_review' as const, errorCode: code, paymentId: payment.id };
      }

      return this.applyTransition(tx, eventRowId, locked, event);
    });
  }

  private async applyTransition(
    tx: Prisma.TransactionClient,
    eventRowId: string,
    payment: { id: string; bookingId: string; businessId: string; status: string; amount: number },
    event: ParsedProviderEvent,
  ): Promise<AppliedProviderEvent> {
    const current = payment.status as PaymentStatus;
    const target = event.status;
    const base = { paymentId: payment.id, bookingId: payment.bookingId };

    if (target === 'pending' || current === target) {
      await this.closeEvent(tx, eventRowId, 'ignored', undefined, payment.id);
      return { outcome: 'ignored', ...base, paymentStatus: current };
    }

    if (target === 'paid' && !canTransitionPayment(current, 'paid')) {
      // Late success: honor only while the slot reservation still exists (§30).
      const reservation = await tx.bookingReservation.findUnique({
        where: { bookingId: payment.bookingId },
      });
      const booking = await tx.booking.findUniqueOrThrow({ where: { id: payment.bookingId } });
      if (reservation && booking.status === 'pending_payment') {
        return this.applyPaid(tx, eventRowId, payment, event);
      }
      await this.closeEvent(
        tx,
        eventRowId,
        'manual_review',
        'PAYMENT_WEBHOOK_TRANSITION_INVALID',
        payment.id,
      );
      return {
        outcome: 'manual_review',
        errorCode: 'PAYMENT_WEBHOOK_TRANSITION_INVALID',
        ...base,
        paymentStatus: current,
        bookingStatus: booking.status,
        lateRefund: {
          paymentId: payment.id,
          bookingId: payment.bookingId,
          businessId: payment.businessId,
          amount: event.amount,
        },
      };
    }

    if (!canTransitionPayment(current, target)) {
      await this.closeEvent(
        tx,
        eventRowId,
        'ignored',
        'PAYMENT_WEBHOOK_TRANSITION_INVALID',
        payment.id,
      );
      return {
        outcome: 'ignored',
        errorCode: 'PAYMENT_WEBHOOK_TRANSITION_INVALID',
        ...base,
        paymentStatus: current,
      };
    }

    if (target === 'paid') {
      return this.applyPaid(tx, eventRowId, payment, event);
    }

    // failed / expired / cancelled — release the slot (§39).
    await tx.payment.update({
      where: { id: payment.id },
      data: {
        status: target,
        version: { increment: 1 },
        ...(target === 'failed' ? { failedAt: event.occurredAt } : {}),
        ...(target === 'cancelled' ? { cancelledAt: event.occurredAt } : {}),
      },
    });
    const booking = await tx.booking.findUniqueOrThrow({ where: { id: payment.bookingId } });
    let bookingStatus = booking.status;
    if (booking.status === 'pending_payment') {
      await tx.booking.update({
        where: { id: booking.id },
        data: { status: 'expired', version: { increment: 1 } },
      });
      await tx.bookingReservation.deleteMany({ where: { bookingId: booking.id } });
      await tx.bookingStatusHistory.create({
        data: {
          id: newId('bsh'),
          bookingId: booking.id,
          fromStatus: 'pending_payment',
          toStatus: 'expired',
          actorType: 'system',
          reasonCode: `payment_${target}`,
          metadata: { providerEventId: event.eventId } as Prisma.InputJsonValue,
        },
      });
      bookingStatus = 'expired';
    }
    await this.closeEvent(tx, eventRowId, 'processed', undefined, payment.id);
    return { outcome: 'processed', ...base, paymentStatus: target, bookingStatus };
  }

  private async applyPaid(
    tx: Prisma.TransactionClient,
    eventRowId: string,
    payment: { id: string; bookingId: string },
    event: ParsedProviderEvent,
  ): Promise<AppliedProviderEvent> {
    await tx.payment.update({
      where: { id: payment.id },
      data: { status: 'paid', paidAt: event.occurredAt, version: { increment: 1 } },
    });
    const booking = await tx.booking.findUniqueOrThrow({ where: { id: payment.bookingId } });
    let bookingStatus = booking.status;
    if (booking.status === 'pending_payment') {
      await tx.booking.update({
        where: { id: booking.id },
        data: { status: 'confirmed', version: { increment: 1 } },
      });
      await tx.bookingStatusHistory.create({
        data: {
          id: newId('bsh'),
          bookingId: booking.id,
          fromStatus: 'pending_payment',
          toStatus: 'confirmed',
          actorType: 'system',
          reasonCode: 'payment_paid',
          metadata: { providerEventId: event.eventId } as Prisma.InputJsonValue,
        },
      });
      bookingStatus = 'confirmed';
    }
    // §38: the reservation is preserved — the confirmed booking still blocks the slot.
    await this.closeEvent(tx, eventRowId, 'processed', undefined, payment.id);
    this.metrics?.inc('payment_paid_total');
    return {
      outcome: 'processed',
      paymentId: payment.id,
      bookingId: booking.id,
      paymentStatus: 'paid',
      bookingStatus,
    };
  }

  private async closeEvent(
    tx: Prisma.TransactionClient,
    eventRowId: string,
    status: 'processed' | 'ignored' | 'failed' | 'manual_review',
    errorCode?: string,
    paymentId?: string,
  ): Promise<void> {
    await tx.paymentEvent.update({
      where: { id: eventRowId },
      data: {
        processingStatus: status,
        processingErrorCode: errorCode ?? null,
        processedAt: new Date(),
        ...(paymentId ? { paymentId } : {}),
      },
    });
  }
}
