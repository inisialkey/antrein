import { ApiError } from '../../auth/auth.errors';
import { formatBookingCode } from './booking-code';
import {
  BLOCKING_BOOKING_STATUSES,
  assertBookingTransition,
  canTransition,
} from './booking-status.policy';
import {
  CancellationPolicySnapshot,
  cancellationDeadlineAt,
  refundAmountFor,
  refundPercentageFor,
} from './cancellation-policy';
import { summarizePayments } from './payment-summary';

function codeOf(fn: () => void): string {
  try {
    fn();
  } catch (error) {
    if (error instanceof ApiError) return (error.getResponse() as { code: string }).code;
    throw error;
  }
  throw new Error('expected ApiError');
}

describe('booking-status.policy', () => {
  it('allows the documented lifecycle transitions', () => {
    expect(canTransition('draft', 'confirmed')).toBe(true);
    expect(canTransition('draft', 'pending_payment')).toBe(true);
    expect(canTransition('pending_payment', 'confirmed')).toBe(true);
    expect(canTransition('pending_payment', 'expired')).toBe(true);
    expect(canTransition('pending_payment', 'cancelled')).toBe(true);
    expect(canTransition('confirmed', 'checked_in')).toBe(true);
    expect(canTransition('confirmed', 'cancelled')).toBe(true);
    expect(canTransition('confirmed', 'no_show')).toBe(true);
    expect(canTransition('in_service', 'completed')).toBe(true);
  });

  it('rejects transitions out of terminal states', () => {
    expect(canTransition('completed', 'cancelled')).toBe(false);
    expect(canTransition('cancelled', 'confirmed')).toBe(false);
    expect(canTransition('expired', 'confirmed')).toBe(false);
    expect(canTransition('no_show', 'waiting')).toBe(false);
  });

  it('assertBookingTransition throws the stable conflict code', () => {
    expect(codeOf(() => assertBookingTransition('completed', 'cancelled'))).toBe(
      'BOOKING_INVALID_STATUS_TRANSITION',
    );
    expect(() => assertBookingTransition('confirmed', 'cancelled')).not.toThrow();
  });

  it('blocking statuses match ADR 0027', () => {
    expect(BLOCKING_BOOKING_STATUSES).toEqual([
      'pending_payment',
      'confirmed',
      'checked_in',
      'waiting',
      'called',
      'in_service',
    ]);
  });
});

describe('cancellation-policy', () => {
  const policy: CancellationPolicySnapshot = {
    fullRefundBeforeMinutes: 360,
    partialRefundBeforeMinutes: 120,
    partialRefundPercentage: 50,
    noShowRefundPercentage: 0,
  };
  const scheduledAt = new Date('2026-07-22T18:00:00+07:00');

  it('gives full refund at or beyond the full threshold', () => {
    expect(refundPercentageFor(policy, scheduledAt, new Date('2026-07-22T10:00:00+07:00'))).toBe(
      100,
    );
    expect(refundPercentageFor(policy, scheduledAt, new Date('2026-07-22T12:00:00+07:00'))).toBe(
      100,
    );
  });

  it('gives partial refund between thresholds, zero inside the last window', () => {
    expect(refundPercentageFor(policy, scheduledAt, new Date('2026-07-22T12:00:01+07:00'))).toBe(
      50,
    );
    expect(refundPercentageFor(policy, scheduledAt, new Date('2026-07-22T16:00:00+07:00'))).toBe(
      50,
    );
    expect(refundPercentageFor(policy, scheduledAt, new Date('2026-07-22T16:00:01+07:00'))).toBe(0);
    expect(refundPercentageFor(policy, scheduledAt, new Date('2026-07-22T19:00:00+07:00'))).toBe(0);
  });

  it('floors partial refund amounts to integer IDR (ADR 0018)', () => {
    const at = new Date('2026-07-22T14:00:00+07:00');
    expect(refundAmountFor(policy, scheduledAt, at, 33333)).toBe(16666);
    expect(refundAmountFor(policy, scheduledAt, at, 0)).toBe(0);
  });

  it('deadline is the full-refund cutoff', () => {
    expect(cancellationDeadlineAt(policy, scheduledAt).toISOString()).toBe(
      new Date('2026-07-22T12:00:00+07:00').toISOString(),
    );
  });
});

describe('payment-summary', () => {
  const paid = (amount: number, status = 'paid') => ({ amount, status });

  it('unpaid when nothing collected; pending rows do not count', () => {
    expect(summarizePayments(50000, [paid(50000, 'pending')])).toEqual({
      totalAmount: 50000,
      paidAmount: 0,
      remainingAmount: 50000,
      status: 'unpaid',
    });
  });

  it('partially paid, fully paid, overpaid', () => {
    expect(summarizePayments(50000, [paid(10000)]).status).toBe('partially_paid');
    expect(summarizePayments(50000, [paid(10000), paid(40000)])).toEqual({
      totalAmount: 50000,
      paidAmount: 50000,
      remainingAmount: 0,
      status: 'paid',
    });
    expect(summarizePayments(50000, [paid(60000)]).status).toBe('overpaid');
  });

  it('counts refund-lifecycle statuses as collected gross', () => {
    expect(summarizePayments(50000, [paid(50000, 'refund_pending')]).status).toBe('paid');
    expect(summarizePayments(50000, [paid(20000, 'failed'), paid(20000, 'cancelled')]).status).toBe(
      'unpaid',
    );
  });
});

describe('booking-code', () => {
  it('formats ANT-YYYYMMDD-NNNN with zero padding', () => {
    expect(formatBookingCode('2026-07-22', 12)).toBe('ANT-20260722-0012');
    expect(formatBookingCode('2026-01-05', 1)).toBe('ANT-20260105-0001');
  });

  it('does not truncate beyond four digits', () => {
    expect(formatBookingCode('2026-07-22', 10000)).toBe('ANT-20260722-10000');
  });
});
