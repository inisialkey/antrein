/**
 * Booking payment aggregate (booking-payment §45). Gross paid counts every
 * status where money was actually received, including refund lifecycle states.
 */
const GROSS_PAID_STATUSES = new Set(['paid', 'refund_pending', 'partially_refunded', 'refunded']);

export type PaymentSummaryStatus = 'unpaid' | 'partially_paid' | 'paid' | 'overpaid';

export interface PaymentSummary {
  totalAmount: number;
  paidAmount: number;
  remainingAmount: number;
  status: PaymentSummaryStatus;
}

export function summarizePayments(
  totalAmount: number,
  payments: readonly { amount: number; status: string }[],
): PaymentSummary {
  // ponytail: net = gross until the refunds table lands (M7) — subtract
  // successful refunds here when it does.
  const paidAmount = payments
    .filter((p) => GROSS_PAID_STATUSES.has(p.status))
    .reduce((sum, p) => sum + p.amount, 0);
  const status: PaymentSummaryStatus =
    paidAmount > totalAmount
      ? 'overpaid'
      : paidAmount === totalAmount
        ? 'paid'
        : paidAmount === 0
          ? 'unpaid'
          : 'partially_paid';
  return { totalAmount, paidAmount, remainingAmount: totalAmount - paidAmount, status };
}
