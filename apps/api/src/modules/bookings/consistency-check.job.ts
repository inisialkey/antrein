import { Injectable, Logger, OnModuleDestroy, OnModuleInit, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { MetricsService } from '../../infrastructure/metrics/metrics.service';
import { Prisma } from '../../generated/prisma/client';
import { ACTIVE_QUEUE_STATUSES } from './queue/queue-support';

const TERMINAL_BOOKING_STATUSES = ['completed', 'cancelled', 'expired', 'no_show'];
/** Statuses whose scheduled slot must still be reservation-blocked (§82). */
const BLOCKING_BOOKING_STATUSES = ['pending_payment', 'confirmed', 'checked_in', 'in_service'];

const STALE_REFUND_MS = 60 * 60_000;
const OUTBOX_BACKLOG_MS = 10 * 60_000;

export interface ConsistencyReport {
  orphanReservations: number;
  missingReservations: number;
  queueBookingMismatches: number;
  staleRefunds: number;
  outboxBacklog: number;
}

/**
 * Daily detector (booking-payment §82, realtime-queue §63): finds invariant
 * violations and reports them (log + metric). It never repairs — §82 requires
 * repairs to go through audited application logic, so a human decides.
 * Auto-poll is skipped under NODE_ENV=test; specs drive runOnce().
 */
@Injectable()
export class ConsistencyCheckJob implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ConsistencyCheckJob.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    @Optional()
    private readonly metrics?: MetricsService,
  ) {}

  onModuleInit(): void {
    if (process.env.NODE_ENV === 'test') return;
    const intervalMs = this.config.get<number>('CONSISTENCY_CHECK_INTERVAL_MS') ?? 86_400_000;
    if (intervalMs <= 0) return;
    this.timer = setInterval(() => {
      this.runOnce().catch((error: Error) =>
        this.logger.error(`Consistency sweep failed: ${error.message}`),
      );
    }, intervalMs);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async runOnce(now = new Date()): Promise<ConsistencyReport> {
    const report: ConsistencyReport = {
      // Reservation held by a booking that no longer blocks the slot.
      orphanReservations: await this.prisma.bookingReservation.count({
        where: { booking: { status: { in: TERMINAL_BOOKING_STATUSES } } },
      }),
      // Scheduled booking that should block its slot but has no reservation
      // row. Walk-ins never have one by design (§67).
      missingReservations: await this.prisma.booking.count({
        where: {
          bookingType: { not: 'walk_in' },
          status: { in: BLOCKING_BOOKING_STATUSES },
          reservation: null,
        },
      }),
      queueBookingMismatches: await this.countQueueBookingMismatches(),
      staleRefunds: await this.prisma.refund.count({
        where: {
          status: 'refund_pending',
          requestedAt: { lte: new Date(now.getTime() - STALE_REFUND_MS) },
        },
      }),
      outboxBacklog: await this.prisma.outboxEvent.count({
        where: {
          OR: [
            { status: 'dead_letter' },
            {
              status: { in: ['pending', 'failed'] },
              createdAt: { lte: new Date(now.getTime() - OUTBOX_BACKLOG_MS) },
            },
          ],
        },
      }),
    };

    const total = Object.values(report).reduce((sum, n) => sum + n, 0);
    if (total > 0) {
      this.metrics?.inc('consistency_violations_total', total);
      this.logger.warn(`Consistency violations detected: ${JSON.stringify(report)}`);
    }
    return report;
  }

  /** Active queue entry whose booking already reached a terminal status (§63). */
  private async countQueueBookingMismatches(): Promise<number> {
    const rows = await this.prisma.$queryRaw<{ count: bigint }[]>`
      SELECT count(*) AS count
      FROM queue_entries qe
      JOIN bookings b ON b.id = qe.booking_id
      WHERE qe.status IN (${Prisma.join(ACTIVE_QUEUE_STATUSES)})
        AND b.status IN (${Prisma.join(TERMINAL_BOOKING_STATUSES)})
    `;
    return Number(rows[0]?.count ?? 0);
  }
}
