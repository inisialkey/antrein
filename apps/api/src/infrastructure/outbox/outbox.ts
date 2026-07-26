import { newId } from '../../common/id/id';
import { Prisma, PrismaClient } from '../../generated/prisma/client';

export type OutboxDb = Prisma.TransactionClient | PrismaClient;

/** After this many delivery attempts a row is parked in dead_letter (needs ops). */
export const OUTBOX_MAX_ATTEMPTS = 10;

export interface EnqueueOutboxInput {
  eventType: string;
  aggregateType: string;
  aggregateId: string;
  payload: Record<string, unknown>;
}

/** One row claimed for delivery (payload is decoded jsonb). */
export interface ClaimedOutboxRow {
  id: string;
  eventType: string;
  aggregateType: string;
  aggregateId: string;
  attemptCount: number;
  payload: Record<string, unknown>;
}

/**
 * Insert an outbox row inside the caller's transaction (arch §33: business state
 * + outbox commit together). No publish happens here — the dispatcher drains it.
 */
export async function enqueueOutbox(
  tx: Prisma.TransactionClient,
  input: EnqueueOutboxInput,
): Promise<void> {
  await tx.outboxEvent.create({
    data: {
      id: newId('obx'),
      eventType: input.eventType,
      aggregateType: input.aggregateType,
      aggregateId: input.aggregateId,
      payload: input.payload as Prisma.InputJsonValue,
    },
  });
}

/**
 * Atomically claim a batch of due rows (database-design §50): one CTE + UPDATE
 * with FOR UPDATE SKIP LOCKED so concurrent dispatchers never grab the same row.
 */
export async function claimOutboxBatch(
  db: OutboxDb,
  limit: number,
  workerId: string,
): Promise<ClaimedOutboxRow[]> {
  return db.$queryRaw<ClaimedOutboxRow[]>`
    WITH claimed AS (
      SELECT id FROM outbox_events
      WHERE status IN ('pending', 'failed') AND next_attempt_at <= now()
      ORDER BY created_at
      FOR UPDATE SKIP LOCKED
      LIMIT ${limit}
    )
    UPDATE outbox_events o
    SET status = 'processing',
        claimed_at = now(),
        claimed_by = ${workerId},
        attempt_count = attempt_count + 1
    FROM claimed
    WHERE o.id = claimed.id
    RETURNING o.id,
              o.event_type AS "eventType",
              o.aggregate_type AS "aggregateType",
              o.aggregate_id AS "aggregateId",
              o.attempt_count AS "attemptCount",
              o.payload`;
}

export async function markOutboxProcessed(db: OutboxDb, ids: string[]): Promise<void> {
  if (ids.length === 0) return;
  await db.outboxEvent.updateMany({
    where: { id: { in: ids } },
    data: { status: 'processed', processedAt: new Date() },
  });
}

/**
 * Delivery failed: back the row off for a retry, or dead-letter it once it has
 * burned through {@link OUTBOX_MAX_ATTEMPTS}. `attemptCount` is the post-claim value.
 */
export async function markOutboxFailed(
  db: OutboxDb,
  input: { id: string; attemptCount: number; error: string; now?: Date },
): Promise<void> {
  const now = input.now ?? new Date();
  const dead = input.attemptCount >= OUTBOX_MAX_ATTEMPTS;
  // Linear-ish backoff capped at ~5 min; good enough for a barbershop MVP.
  const backoffMs = Math.min(input.attemptCount * 30_000, 300_000);
  await db.outboxEvent.update({
    where: { id: input.id },
    data: {
      status: dead ? 'dead_letter' : 'failed',
      lastError: input.error.slice(0, 500),
      nextAttemptAt: new Date(now.getTime() + backoffMs),
    },
  });
}
