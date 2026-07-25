import {
  availableRefundable,
  canTransitionPayment,
  paymentStatusAfterRefunds,
} from './payment-status.policy';

describe('payment status transitions (booking-payment §9)', () => {
  it.each([
    ['pending', 'paid'],
    ['pending', 'failed'],
    ['pending', 'expired'],
    ['pending', 'cancelled'],
    ['paid', 'refund_pending'],
    ['refund_pending', 'partially_refunded'],
    ['refund_pending', 'refunded'],
    ['partially_refunded', 'refund_pending'],
    ['partially_refunded', 'refunded'],
  ] as const)('allows %s → %s', (from, to) => {
    expect(canTransitionPayment(from, to)).toBe(true);
  });

  it.each([
    ['pending', 'refunded'],
    ['paid', 'pending'],
    ['paid', 'expired'],
    ['expired', 'paid'], // late payment goes to manual review, never a transition
    ['failed', 'paid'],
    ['cancelled', 'paid'],
    ['refunded', 'refund_pending'],
  ] as const)('rejects %s → %s', (from, to) => {
    expect(canTransitionPayment(from, to)).toBe(false);
  });
});

describe('availableRefundable (booking-payment §51)', () => {
  const refund = (status: string, amount: number) => ({ status, amount });

  it('is the full paid amount with no refunds', () => {
    expect(availableRefundable(50000, [])).toBe(50000);
  });

  it('subtracts completed and pending refunds', () => {
    expect(
      availableRefundable(50000, [refund('refunded', 10000), refund('refund_pending', 5000)]),
    ).toBe(35000);
  });

  it('ignores failed and cancelled refunds', () => {
    expect(availableRefundable(50000, [refund('failed', 10000), refund('cancelled', 5000)])).toBe(
      50000,
    );
  });

  it('never goes negative', () => {
    expect(availableRefundable(10000, [refund('refunded', 15000)])).toBe(0);
  });
});

describe('paymentStatusAfterRefunds', () => {
  const refund = (status: string, amount: number) => ({ status, amount });

  it('is refunded when completed refunds cover the payment', () => {
    expect(paymentStatusAfterRefunds(50000, [refund('refunded', 50000)])).toBe('refunded');
  });

  it('is partially_refunded for a partial completed refund', () => {
    expect(paymentStatusAfterRefunds(50000, [refund('refunded', 20000)])).toBe(
      'partially_refunded',
    );
  });

  it('is refund_pending while a refund is still pending', () => {
    expect(paymentStatusAfterRefunds(50000, [refund('refund_pending', 20000)])).toBe(
      'refund_pending',
    );
  });

  it('pending refund wins over earlier partial refunds', () => {
    expect(
      paymentStatusAfterRefunds(50000, [refund('refunded', 10000), refund('refund_pending', 5000)]),
    ).toBe('refund_pending');
  });

  it('falls back to paid when nothing was refunded', () => {
    expect(paymentStatusAfterRefunds(50000, [refund('failed', 10000)])).toBe('paid');
  });
});
