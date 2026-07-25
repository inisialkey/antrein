import { newId } from '../../../common/id/id';
import { Prisma, PrismaClient, QueueEntry } from '../../../generated/prisma/client';
import { jakartaDateString } from '../../schedules/slots';
import { BookingStatus, assertBookingTransition } from '../domain/booking-status.policy';
import { estimatedWaitMinutes, peopleAheadOf } from './domain/queue-math';
import { CustomerQueueView } from './queue.mapper';
import { QueueStatus } from './domain/queue-status.policy';
import { queueVersionConflict } from './domain/queue.errors';

export type QueueDb = Prisma.TransactionClient | PrismaClient;

/** Statuses that occupy the active queue for ordering + snapshot. */
export const ACTIVE_QUEUE_STATUSES: QueueStatus[] = ['waiting', 'called', 'in_service', 'skipped'];

/** Jakarta business date as both the API string and a UTC-midnight Date column value. */
export function jakartaBusinessDate(now: Date): { str: string; date: Date } {
  const str = jakartaDateString(now);
  return { str, date: new Date(`${str}T00:00:00Z`) };
}

/** Atomic queue-number generation (database-design §37). Returns the new number + aggregate version. */
export async function nextQueueNumber(
  tx: Prisma.TransactionClient,
  outletId: string,
  businessDateStr: string,
): Promise<{ number: number; version: number }> {
  const rows = await tx.$queryRaw<Array<{ last_number: number; version: number }>>`
    INSERT INTO queue_counters (outlet_id, business_date, last_number)
    VALUES (${outletId}, ${businessDateStr}::date, 1)
    ON CONFLICT (outlet_id, business_date)
    DO UPDATE SET last_number = queue_counters.last_number + 1,
                  version = queue_counters.version + 1,
                  updated_at = now()
    RETURNING last_number, version`;
  return { number: rows[0].last_number, version: rows[0].version };
}

/** Version-guarded aggregate bump for reorder (realtime-queue §20/§33). */
export async function bumpQueueVersion(
  tx: Prisma.TransactionClient,
  outletId: string,
  businessDateStr: string,
  expectedVersion: number,
): Promise<number> {
  const rows = await tx.$queryRaw<Array<{ version: number }>>`
    UPDATE queue_counters SET version = version + 1, updated_at = now()
    WHERE outlet_id = ${outletId} AND business_date = ${businessDateStr}::date
      AND version = ${expectedVersion}
    RETURNING version`;
  if (rows.length !== 1) throw queueVersionConflict();
  return rows[0].version;
}

export async function insertQueueHistory(
  tx: Prisma.TransactionClient,
  input: {
    queueEntryId: string;
    fromStatus: QueueStatus | null;
    toStatus: QueueStatus;
    actorUserId: string | null;
    actorType: string;
    reason?: string | null;
    metadata?: Record<string, unknown>;
    requestId?: string | null;
  },
): Promise<void> {
  await tx.queueStatusHistory.create({
    data: {
      id: newId('qsh'),
      queueEntryId: input.queueEntryId,
      fromStatus: input.fromStatus,
      toStatus: input.toStatus,
      actorUserId: input.actorUserId,
      actorType: input.actorType,
      reason: input.reason ?? null,
      metadata: (input.metadata ?? {}) as Prisma.InputJsonValue,
      requestId: input.requestId ?? null,
    },
  });
}

export async function insertBookingHistory(
  tx: Prisma.TransactionClient,
  input: {
    bookingId: string;
    fromStatus: BookingStatus | null;
    toStatus: BookingStatus;
    actorUserId: string | null;
    actorType: string;
    reason?: string | null;
    reasonCode?: string | null;
    metadata?: Record<string, unknown>;
    requestId?: string | null;
  },
): Promise<void> {
  await tx.bookingStatusHistory.create({
    data: {
      id: newId('bsh'),
      bookingId: input.bookingId,
      fromStatus: input.fromStatus,
      toStatus: input.toStatus,
      actorUserId: input.actorUserId,
      actorType: input.actorType,
      reason: input.reason ?? null,
      reasonCode: input.reasonCode ?? null,
      metadata: (input.metadata ?? {}) as Prisma.InputJsonValue,
    },
  });
}

const BOOKING_TERMINAL_TIMESTAMP: Partial<
  Record<BookingStatus, 'completedAt' | 'noShowAt' | 'cancelledAt'>
> = {
  completed: 'completedAt',
  no_show: 'noShowAt',
  cancelled: 'cancelledAt',
};

/**
 * Move the booking in sync with its queue entry (realtime-queue §9). No-op when
 * the mapped status is unchanged (e.g. skip → return keeps the booking waiting).
 */
export async function transitionBookingWithQueue(
  tx: Prisma.TransactionClient,
  input: {
    bookingId: string;
    fromStatus: BookingStatus;
    toStatus: BookingStatus;
    actorUserId: string | null;
    actorType: string;
    reason?: string | null;
    reasonCode?: string | null;
    at: Date;
  },
): Promise<void> {
  if (input.fromStatus === input.toStatus) return;
  assertBookingTransition(input.fromStatus, input.toStatus);
  const timestampField = BOOKING_TERMINAL_TIMESTAMP[input.toStatus];
  await tx.booking.update({
    where: { id: input.bookingId },
    data: {
      status: input.toStatus,
      version: { increment: 1 },
      updatedAt: input.at,
      ...(timestampField ? { [timestampField]: input.at } : {}),
    },
  });
  await insertBookingHistory(tx, {
    bookingId: input.bookingId,
    fromStatus: input.fromStatus,
    toStatus: input.toStatus,
    actorUserId: input.actorUserId,
    actorType: input.actorType,
    reason: input.reason,
    reasonCode: input.reasonCode,
  });
}

/** Release the staff reservation if the booking still holds one (realtime-queue §28/§29). */
export async function releaseReservation(
  tx: Prisma.TransactionClient,
  bookingId: string,
): Promise<void> {
  await tx.bookingReservation.deleteMany({ where: { bookingId } });
}

/**
 * Optimistic-concurrency queue update (realtime-queue §20): applies only when the
 * stored version still matches. Zero rows updated → QUEUE_VERSION_CONFLICT.
 * Unique-constraint violations (one-called / one-in-service) propagate to the
 * caller to translate.
 */
export async function versionedQueueUpdate(
  tx: Prisma.TransactionClient,
  entryId: string,
  expectedVersion: number,
  data: Prisma.QueueEntryUpdateManyMutationInput,
  at: Date,
): Promise<void> {
  const result = await tx.queueEntry.updateMany({
    where: { id: entryId, version: expectedVersion },
    data: { ...data, version: { increment: 1 }, updatedAt: at },
  });
  if (result.count !== 1) throw queueVersionConflict();
}

/**
 * Customer-facing view of one entry (realtime-queue §35/§36): people ahead in the
 * ordered active queue, the current serving/called display number, and a wait
 * estimate. Privacy: never exposes any other customer.
 */
export async function customerViewOf(db: QueueDb, entry: QueueEntry): Promise<CustomerQueueView> {
  const active = await db.queueEntry.findMany({
    where: {
      outletId: entry.outletId,
      businessDate: entry.businessDate,
      status: { in: ACTIVE_QUEUE_STATUSES },
    },
    orderBy: [{ sortOrder: 'asc' }, { checkedInAt: 'asc' }, { queueNumber: 'asc' }],
    select: { id: true, status: true, displayNumber: true },
  });
  const peopleAhead = peopleAheadOf(
    active.map((e) => ({ id: e.id, status: e.status as QueueStatus })),
    entry.id,
  );
  const serving =
    active.find((e) => e.status === 'in_service') ?? active.find((e) => e.status === 'called');
  // ponytail: average = this booking's own snapshot duration (§36 fallback);
  // per-staff parallel estimation is deferred.
  const snapshot = await db.bookingSnapshot.findUnique({
    where: { bookingId: entry.bookingId },
    select: { serviceDurationMinutes: true },
  });
  const averageMinutes = snapshot?.serviceDurationMinutes ?? 30;
  return {
    peopleAhead,
    currentServingNumber: serving?.displayNumber ?? null,
    estimatedWaitMinutes: estimatedWaitMinutes(peopleAhead, averageMinutes),
  };
}
