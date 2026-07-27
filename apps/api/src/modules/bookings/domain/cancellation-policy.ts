/**
 * Cancellation refund policy (booking-payment §48, ADR 0018). All calculations
 * use the immutable policy snapshot stored on the booking, never live policy.
 */
export interface CancellationPolicySnapshot {
  fullRefundBeforeMinutes: number;
  partialRefundBeforeMinutes: number;
  partialRefundPercentage: number;
  noShowRefundPercentage: number;
}

export function refundPercentageFor(
  policy: CancellationPolicySnapshot,
  scheduledAt: Date,
  at: Date,
): number {
  const minutesBefore = (scheduledAt.getTime() - at.getTime()) / 60_000;
  if (minutesBefore >= policy.fullRefundBeforeMinutes) return 100;
  if (minutesBefore >= policy.partialRefundBeforeMinutes) return policy.partialRefundPercentage;
  return 0;
}

/** Integer IDR, floored (ADR 0018). `netPaidAmount` = online net paid. */
export function refundAmountFor(
  policy: CancellationPolicySnapshot,
  scheduledAt: Date,
  at: Date,
  netPaidAmount: number,
): number {
  return Math.floor((netPaidAmount * refundPercentageFor(policy, scheduledAt, at)) / 100);
}

/** Last instant that still yields a full refund (contract §59 `deadlineAt`). */
export function cancellationDeadlineAt(
  policy: CancellationPolicySnapshot,
  scheduledAt: Date,
): Date {
  return new Date(scheduledAt.getTime() - policy.fullRefundBeforeMinutes * 60_000);
}
