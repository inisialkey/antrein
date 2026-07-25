import { ACTIVE_AHEAD_STATUSES, QueueStatus } from './queue-status.policy';

/**
 * Human-readable queue label (realtime-queue §15, ADR 0041): outlet prefix +
 * zero-padded number, minimum three digits. Gaps are acceptable.
 */
export function formatDisplayNumber(prefix: string, queueNumber: number): string {
  return `${prefix}${String(queueNumber).padStart(3, '0')}`;
}

export type CheckInWindowState = 'too_early' | 'too_late' | 'open';

/**
 * Check-in window (realtime-queue §10, ADR 0034): opens `earlyMinutes` before
 * and closes `lateMinutes` after the scheduled time (bounds inclusive).
 */
export function checkInWindowState(
  scheduledAt: Date,
  now: Date,
  earlyMinutes: number,
  lateMinutes: number,
): CheckInWindowState {
  const t = now.getTime();
  const opensAt = scheduledAt.getTime() - earlyMinutes * 60_000;
  const closesAt = scheduledAt.getTime() + lateMinutes * 60_000;
  if (t < opensAt) return 'too_early';
  if (t > closesAt) return 'too_late';
  return 'open';
}

/**
 * People ahead of `targetId` in the ordered active queue (realtime-queue §35):
 * entries positioned before it that are still waiting, called, or in service.
 * Skipped entries do not count until returned to waiting. `entries` must already
 * be in queue order.
 */
export function peopleAheadOf(
  entries: ReadonlyArray<{ id: string; status: QueueStatus }>,
  targetId: string,
): number {
  const index = entries.findIndex((e) => e.id === targetId);
  if (index < 0) return 0;
  return entries.slice(0, index).filter((e) => ACTIVE_AHEAD_STATUSES.includes(e.status)).length;
}

/**
 * Estimated wait (realtime-queue §36 fallback, ADR 0041): people ahead × average
 * service minutes. Informational only.
 */
export function estimatedWaitMinutes(peopleAhead: number, averageServiceMinutes: number): number {
  return Math.max(0, peopleAhead) * Math.max(0, averageServiceMinutes);
}
