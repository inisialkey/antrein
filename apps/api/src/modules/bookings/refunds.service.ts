import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { PaymentProviderPort } from '../../infrastructure/payments/payment-provider.port';
import { Payment, Refund } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { ApiError, validationFailed } from '../auth/auth.errors';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { MembershipsService } from '../memberships/memberships.service';
import {
  paymentCurrencyMismatch,
  paymentNotFound,
  paymentNotRefundable,
  refundAlreadyPending,
  refundAmountExceedsPaidAmount,
  refundNotFound,
} from './booking.errors';
import {
  availableRefundable,
  canTransitionPayment,
  PaymentStatus,
  paymentStatusAfterRefunds,
} from './domain/payment-status.policy';
import { RequestRefundDto } from './dto/booking.dto';

const PAYMENT_IDEMPOTENCY_RETENTION_HOURS = 24 * 7; // ADR 0034

const REFUNDABLE_PAYMENT_STATUSES: PaymentStatus[] = ['paid', 'partially_refunded'];

export function toRefundResource(refund: Refund): Record<string, unknown> {
  return {
    id: refund.id,
    paymentId: refund.paymentId,
    bookingId: refund.bookingId,
    status: refund.status,
    amount: { amount: refund.amount, currency: refund.currency },
    reasonCode: refund.reasonCode,
    reason: refund.reason,
    processedAt: refund.processedAt?.toISOString() ?? null,
    createdAt: refund.createdAt.toISOString(),
  };
}

/** Refund lifecycle (booking-payment §51–§55): request, provider call, aggregate state. */
@Injectable()
export class RefundsService {
  private readonly logger = new Logger(RefundsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly memberships: MembershipsService,
    private readonly audit: AuditService,
    @Optional()
    @Inject(PaymentProviderPort)
    private readonly provider: PaymentProviderPort | null,
  ) {}

  async requestRefund(
    actorUserId: string,
    businessId: string,
    paymentId: string,
    dto: RequestRefundDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `payment.refund:${paymentId}`,
      key: idempotencyKey,
      payload: dto,
      retentionHours: PAYMENT_IDEMPOTENCY_RETENTION_HOURS,
      resourceOf: (result) => ({
        type: 'refund',
        id: (result.refund as { id: string }).id,
      }),
      run: async () => {
        const payment = await this.prisma.payment.findUnique({
          where: { id: paymentId },
          include: { refunds: true },
        });
        if (!payment || payment.businessId !== businessId) throw paymentNotFound();
        if (dto.amount.currency !== 'IDR') throw paymentCurrencyMismatch();
        if (dto.amount.amount <= 0) {
          throw validationFailed('Refund amount must be greater than zero.');
        }
        if (payment.provider === 'pay_at_location') throw paymentNotRefundable();
        if (payment.status === 'refund_pending') throw refundAlreadyPending();
        if (!REFUNDABLE_PAYMENT_STATUSES.includes(payment.status as PaymentStatus)) {
          throw paymentNotRefundable();
        }

        const refund = await this.executeRefund(payment, dto.amount.amount, {
          reasonCode: dto.reasonCode,
          reason: dto.reason ?? null,
          requestedByUserId: actorUserId,
          audit: { actorUserId, businessId },
        });
        return { refund: toRefundResource(refund) };
      },
    });
  }

  /**
   * ADR 0040 §30: a verified provider success that arrived after the slot was
   * released is refunded in full — idempotent per payment.
   */
  async refundLatePayment(input: {
    paymentId: string;
    bookingId: string;
    businessId: string;
    amount: number;
  }): Promise<void> {
    const existing = await this.prisma.refund.findFirst({
      where: { paymentId: input.paymentId, reasonCode: 'late_payment' },
    });
    if (existing) return;
    const payment = await this.prisma.payment.findUnique({
      where: { id: input.paymentId },
      include: { refunds: true },
    });
    if (!payment) return;
    try {
      await this.executeRefund(payment, input.amount, {
        reasonCode: 'late_payment',
        reason: 'Automatic refund: payment confirmed after the reserved slot was released.',
        requestedByUserId: null,
        skipPaymentTransition: true,
      });
    } catch (error) {
      // Raced duplicate (webhook + refresh both flag the same late payment):
      // the second attempt loses under the payment row lock — benign.
      const code = ((error as ApiError).getResponse?.() as { code?: string } | undefined)?.code;
      if (code === 'REFUND_AMOUNT_EXCEEDS_PAID_AMOUNT' || code === 'REFUND_ALREADY_PENDING') {
        return;
      }
      // Never fail webhook acknowledgement over the follow-up refund; the
      // manual_review event keeps the case visible.
      this.logger.error(`Late-payment refund failed for ${input.paymentId}`, error as Error);
    }
  }

  /**
   * Cancellation refund (ADR 0018 customer thresholds / ADR 0040 business
   * full-refund). Returns null when there is no paid online payment or no
   * amount to return.
   */
  async createCancellationRefund(input: {
    bookingId: string;
    amount: number;
    actorUserId: string;
    reasonCode: string;
    reason: string | null;
    auditBusinessId?: string;
  }): Promise<Record<string, unknown> | null> {
    if (input.amount <= 0) return null;
    const payment = await this.prisma.payment.findFirst({
      where: {
        bookingId: input.bookingId,
        provider: { not: 'pay_at_location' },
        status: { in: [...REFUNDABLE_PAYMENT_STATUSES] },
      },
      orderBy: { createdAt: 'desc' },
      include: { refunds: true },
    });
    if (!payment) return null;
    const refund = await this.executeRefund(payment, input.amount, {
      reasonCode: input.reasonCode,
      reason: input.reason,
      requestedByUserId: input.actorUserId,
      audit: input.auditBusinessId
        ? { actorUserId: input.actorUserId, businessId: input.auditBusinessId }
        : undefined,
    });
    return toRefundResource(refund);
  }

  async getRefund(userId: string, refundId: string): Promise<Record<string, unknown>> {
    const refund = await this.prisma.refund.findUnique({
      where: { id: refundId },
      include: { payment: true },
    });
    if (!refund) throw refundNotFound();
    if (refund.payment.customerUserId !== userId) {
      try {
        await this.memberships.requirePermission(userId, refund.businessId, null);
      } catch {
        // Do not reveal foreign refund existence.
        throw refundNotFound();
      }
    }
    return toRefundResource(refund);
  }

  /**
   * Creates the refund_pending row atomically (re-validating under the payment
   * row lock), then settles it through the provider. Provider failure leaves
   * the row refund_pending for reconciliation (§54 temporary failure).
   */
  private async executeRefund(
    payment: Payment & { refunds: Refund[] },
    amount: number,
    opts: {
      reasonCode: string;
      reason: string | null;
      requestedByUserId: string | null;
      audit?: { actorUserId: string; businessId: string };
      /** Late payments refund a payment stuck in a terminal status (§30). */
      skipPaymentTransition?: boolean;
    },
  ): Promise<Refund> {
    const refundId = newId('ref');
    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM payments WHERE id = ${payment.id} FOR UPDATE`;
      const refunds = await tx.refund.findMany({ where: { paymentId: payment.id } });
      if (refunds.some((r) => r.status === 'refund_pending')) throw refundAlreadyPending();
      const available = availableRefundable(payment.amount, refunds);
      if (amount > available) throw refundAmountExceedsPaidAmount(available);

      await tx.refund.create({
        data: {
          id: refundId,
          paymentId: payment.id,
          bookingId: payment.bookingId,
          businessId: payment.businessId,
          requestedByUserId: opts.requestedByUserId,
          status: 'refund_pending',
          amount,
          reasonCode: opts.reasonCode,
          reason: opts.reason,
          requestedAt: now,
        },
      });
      if (
        !opts.skipPaymentTransition &&
        canTransitionPayment(payment.status as PaymentStatus, 'refund_pending')
      ) {
        await tx.payment.update({
          where: { id: payment.id },
          data: { status: 'refund_pending', version: { increment: 1 } },
        });
      }
      if (opts.audit) {
        await this.audit.record(
          {
            actorUserId: opts.audit.actorUserId,
            businessId: opts.audit.businessId,
            action: 'payment.refund_request',
            resourceType: 'refund',
            resourceId: refundId,
            afterData: { paymentId: payment.id, amount, reasonCode: opts.reasonCode },
            reason: opts.reason ?? undefined,
          },
          tx,
        );
      }
    });

    await this.settleWithProvider(payment, refundId, amount, opts.skipPaymentTransition ?? false);

    const refund = await this.prisma.refund.findUniqueOrThrow({ where: { id: refundId } });
    return refund;
  }

  private async settleWithProvider(
    payment: Payment,
    refundId: string,
    amount: number,
    skipPaymentTransition: boolean,
  ): Promise<void> {
    if (!this.provider || !payment.providerReference) {
      // Nothing to settle against — leave refund_pending for manual handling.
      return;
    }
    let providerReference: string;
    try {
      const result = await this.provider.requestRefund({
        refundId,
        providerReference: payment.providerReference,
        amount,
        currency: payment.currency,
      });
      if (result.status !== 'refunded') return; // async settlement — reconciliation's job
      providerReference = result.providerReference;
    } catch (error) {
      this.logger.warn(`Provider refund failed for ${refundId}: ${(error as Error).message}`);
      return;
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM payments WHERE id = ${payment.id} FOR UPDATE`;
      const updated = await tx.refund.updateMany({
        where: { id: refundId, status: 'refund_pending' },
        data: {
          status: 'refunded',
          providerReference,
          processedAt: new Date(),
          version: { increment: 1 },
        },
      });
      if (updated.count === 0) return;
      if (skipPaymentTransition) return;
      const refunds = await tx.refund.findMany({ where: { paymentId: payment.id } });
      const aggregate = paymentStatusAfterRefunds(payment.amount, refunds);
      await tx.payment.update({
        where: { id: payment.id },
        data: { status: aggregate, version: { increment: 1 } },
      });
    });
  }
}
