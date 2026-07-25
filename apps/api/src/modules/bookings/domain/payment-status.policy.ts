/** Payment status machine + refund accounting (booking-payment §9, §51). */

export const PAYMENT_STATUSES = [
  'pending',
  'paid',
  'failed',
  'expired',
  'cancelled',
  'refund_pending',
  'partially_refunded',
  'refunded',
] as const;

export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

const ALLOWED_PAYMENT_TRANSITIONS: Record<PaymentStatus, PaymentStatus[]> = {
  pending: ['paid', 'failed', 'expired', 'cancelled'],
  paid: ['refund_pending'],
  failed: [],
  expired: [],
  cancelled: [],
  refund_pending: ['partially_refunded', 'refunded'],
  partially_refunded: ['refund_pending', 'refunded'],
  refunded: [],
};

export function canTransitionPayment(from: PaymentStatus, to: PaymentStatus): boolean {
  return ALLOWED_PAYMENT_TRANSITIONS[from]?.includes(to) ?? false;
}

interface RefundLike {
  status: string;
  amount: number;
}

/** Refunds that hold or have taken money — they reduce what is still refundable. */
const COUNTING_REFUND_STATUSES = new Set(['refunded', 'partially_refunded', 'refund_pending']);
const COMPLETED_REFUND_STATUSES = new Set(['refunded', 'partially_refunded']);

/** available = paid − already refunded − pending refunds (§51), floored at 0. */
export function availableRefundable(paidAmount: number, refunds: RefundLike[]): number {
  const held = refunds
    .filter((r) => COUNTING_REFUND_STATUSES.has(r.status))
    .reduce((sum, r) => sum + r.amount, 0);
  return Math.max(0, paidAmount - held);
}

/** Aggregate payment status implied by its refund rows (§10). */
export function paymentStatusAfterRefunds(
  paidAmount: number,
  refunds: RefundLike[],
): 'paid' | 'refund_pending' | 'partially_refunded' | 'refunded' {
  if (refunds.some((r) => r.status === 'refund_pending')) return 'refund_pending';
  const completed = refunds
    .filter((r) => COMPLETED_REFUND_STATUSES.has(r.status))
    .reduce((sum, r) => sum + r.amount, 0);
  if (completed <= 0) return 'paid';
  return completed >= paidAmount ? 'refunded' : 'partially_refunded';
}
