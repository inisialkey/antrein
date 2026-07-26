import { hostname } from 'node:os';
import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import {
  ClaimedOutboxRow,
  claimOutboxBatch,
  markOutboxFailed,
  markOutboxProcessed,
} from '../../infrastructure/outbox/outbox';
import { buildEvent } from '../../infrastructure/realtime/realtime-event';
import { RealtimePublisherPort } from '../../infrastructure/realtime/realtime-publisher.port';
import { NotificationsService } from '../notifications/notifications.service';
import { toCustomerQueueResource } from './queue/queue.mapper';
import { customerViewOf, outletSnapshotSummary } from './queue/queue-support';

/**
 * Drains the transactional outbox (realtime-queue §49): claims committed rows and
 * publishes the customer + staff queue events. Mirrors {@link PaymentExpirationJob}
 * — runs inline (ADR 0035); interval 0 disables the timer so tests drive
 * runOnce() directly. A publish failure backs the row off for retry and never
 * touches the already-committed business state (arch §33).
 */
@Injectable()
export class OutboxDispatcherJob implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OutboxDispatcherJob.name);
  private readonly workerId = `${hostname()}:${process.pid}`;
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly publisher: RealtimePublisherPort,
    private readonly notifications: NotificationsService,
  ) {}

  onModuleInit(): void {
    // ponytail: never auto-poll under tests — integration specs boot many app
    // instances and drive runOnce() by hand; a live 2s timer across them starves
    // the connection pool and flakes unrelated suites. Real envs run it normally.
    if (process.env.NODE_ENV === 'test') return;
    const intervalMs = this.config.get<number>('OUTBOX_DISPATCHER_INTERVAL_MS') ?? 2_000;
    if (intervalMs <= 0) return;
    this.timer = setInterval(() => {
      this.runOnce().catch((error: Error) =>
        this.logger.error(`Outbox dispatch sweep failed: ${error.message}`),
      );
    }, intervalMs);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** Claim + deliver one batch; returns how many rows were delivered. */
  async runOnce(limit = 100): Promise<number> {
    const rows = await claimOutboxBatch(this.prisma, limit, this.workerId);
    const delivered: string[] = [];
    for (const row of rows) {
      try {
        await this.dispatch(row);
        delivered.push(row.id);
      } catch (error) {
        await markOutboxFailed(this.prisma, {
          id: row.id,
          attemptCount: row.attemptCount,
          error: (error as Error).message,
        });
      }
    }
    await markOutboxProcessed(this.prisma, delivered);
    return delivered.length;
  }

  private async dispatch(row: ClaimedOutboxRow): Promise<void> {
    const { outletId, businessDate, bookingId, push } = row.payload as {
      outletId: string;
      businessDate: string;
      bookingId: string | null;
      push?: 'checked_in' | 'called' | null;
    };
    const businessDateAt = new Date(`${businessDate}T00:00:00Z`);

    // Staff snapshot (§108) — always, from latest state (events are hints, §47).
    const summary = await outletSnapshotSummary(this.prisma, outletId, businessDateAt);
    await this.publisher.publishToOutletQueue(
      outletId,
      businessDate,
      buildEvent(
        'queue.snapshot.updated.v1',
        { type: 'outlet_queue', id: `${outletId}:${businessDate}` },
        summary.version,
        {
          outletId,
          businessDate,
          currentServing: summary.currentServing,
          waitingCount: summary.waitingCount,
          skippedCount: summary.skippedCount,
        },
      ),
    );

    // Customer queue view (§107) — only when the entry maps to a real customer
    // (walk-ins are anonymous). Privacy: never exposes any other customer.
    if (!bookingId) return;
    const entry = await this.prisma.queueEntry.findUnique({ where: { bookingId } });
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { customerUserId: true },
    });
    if (!entry || !booking?.customerUserId) return;
    const view = await customerViewOf(this.prisma, entry);
    await this.publisher.publishToUser(
      booking.customerUserId,
      buildEvent(
        'queue.entry.updated.v1',
        { type: 'queue_entry', id: entry.id },
        entry.version,
        toCustomerQueueResource(entry, view),
      ),
    );

    // Push-worthy transitions (realtime-queue §53/§54, ADR 0044): the kind was
    // decided inside the mutating tx; provider failures never fail the dispatch.
    if (push) {
      await this.notifications.notifyQueuePush({
        userId: booking.customerUserId,
        kind: push,
        bookingId,
        displayNumber: entry.displayNumber,
      });
    }
  }
}
