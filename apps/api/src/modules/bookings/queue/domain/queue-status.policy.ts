import { BookingStatus } from '../../domain/booking-status.policy';

/** Queue lifecycle (realtime-queue §8, database-design §38). */
export const QUEUE_STATUSES = [
  'waiting',
  'called',
  'skipped',
  'in_service',
  'completed',
  'cancelled',
  'no_show',
] as const;

export type QueueStatus = (typeof QUEUE_STATUSES)[number];

export const TERMINAL_QUEUE_STATUSES: readonly QueueStatus[] = [
  'completed',
  'cancelled',
  'no_show',
];

/** Entries the customer still counts as "ahead" (realtime-queue §35). */
export const ACTIVE_AHEAD_STATUSES: readonly QueueStatus[] = ['waiting', 'called', 'in_service'];

/** Entries a reorder may touch (realtime-queue §33). */
export const REORDERABLE_STATUSES: readonly QueueStatus[] = ['waiting', 'skipped'];

// realtime-queue §8.2 (+ §29 skipped→no_show). Cancellation edges match the spec
// even though M8 exposes no queue-cancel endpoint (§30 deferred with the realtime
// milestone).
const ALLOWED_QUEUE_TRANSITIONS: Record<QueueStatus, readonly QueueStatus[]> = {
  waiting: ['called', 'cancelled'],
  called: ['in_service', 'skipped', 'no_show', 'cancelled'],
  skipped: ['waiting', 'no_show'],
  in_service: ['completed'],
  completed: [],
  cancelled: [],
  no_show: [],
};

export function canTransitionQueue(from: QueueStatus, to: QueueStatus): boolean {
  return ALLOWED_QUEUE_TRANSITIONS[from].includes(to);
}

/**
 * Booking status a queue status maps to (realtime-queue §9). `skipped` keeps the
 * booking `waiting` — skip is a queue-only state that never adds a booking state.
 */
const QUEUE_TO_BOOKING: Record<QueueStatus, BookingStatus> = {
  waiting: 'waiting',
  called: 'called',
  skipped: 'waiting',
  in_service: 'in_service',
  completed: 'completed',
  cancelled: 'cancelled',
  no_show: 'no_show',
};

export function bookingStatusForQueue(status: QueueStatus): BookingStatus {
  return QUEUE_TO_BOOKING[status];
}
