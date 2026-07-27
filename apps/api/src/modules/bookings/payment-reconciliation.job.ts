import {
  Inject,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { MetricsService } from '../../infrastructure/metrics/metrics.service';
import { PaymentProviderPort } from '../../infrastructure/payments/payment-provider.port';
import { PaymentTransitionService } from './payment-transition.service';
import { RefundsService } from './refunds.service';

/** Reconciliation ignores payments younger than this — the webhook is probably still coming. */
const RECONCILE_MIN_AGE_MS = 60_000;

/**
 * Booking-payment §42/§81: every-few-minutes sweep that queries the provider
 * for stale pending online payments and pushes the answer through the same
 * idempotent transition path as webhooks (ADR 0029 — deterministic provider
 * event ids make repeated sweeps dedupe), then re-settles stuck refunds.
 * Auto-poll is skipped under NODE_ENV=test (like the outbox dispatcher);
 * specs drive runOnce() by hand.
 */
@Injectable()
export class PaymentReconciliationJob implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PaymentReconciliationJob.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly transitions: PaymentTransitionService,
    private readonly refunds: RefundsService,
    @Optional()
    @Inject(PaymentProviderPort)
    private readonly provider: PaymentProviderPort | null,
    @Optional()
    private readonly metrics?: MetricsService,
  ) {}

  onModuleInit(): void {
    if (process.env.NODE_ENV === 'test') return;
    const intervalMs = this.config.get<number>('PAYMENT_RECONCILIATION_INTERVAL_MS') ?? 300_000;
    if (intervalMs <= 0) return;
    this.timer = setInterval(() => {
      this.runOnce().catch((error: Error) =>
        this.logger.error(`Payment reconciliation sweep failed: ${error.message}`),
      );
    }, intervalMs);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async runOnce(now = new Date()): Promise<{ payments: number; refunds: number }> {
    const payments = this.provider ? await this.reconcilePayments(now) : 0;
    const refunds = await this.refunds.reconcilePendingRefunds(now);
    if (payments + refunds > 0)
      this.metrics?.inc('payment_reconciliation_total', payments + refunds);
    return { payments, refunds };
  }

  private async reconcilePayments(now: Date): Promise<number> {
    const provider = this.provider!;
    const cutoff = new Date(now.getTime() - RECONCILE_MIN_AGE_MS);
    const stale = await this.prisma.payment.findMany({
      where: {
        status: 'pending',
        provider: { not: 'pay_at_location' },
        providerReference: { not: null },
        createdAt: { lte: cutoff },
      },
      select: { id: true, providerReference: true },
      take: 50,
      orderBy: { createdAt: 'asc' },
    });
    let processed = 0;
    for (const payment of stale) {
      try {
        const status = await provider.getPaymentStatus(payment.providerReference!);
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
        if (applied.outcome === 'processed') processed += 1;
      } catch (error) {
        this.logger.warn(`Failed to reconcile payment ${payment.id}: ${(error as Error).message}`);
      }
    }
    return processed;
  }
}
