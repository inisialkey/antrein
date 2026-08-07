import { Prisma } from '../../generated/prisma/client';
import {
  CancellationPolicySnapshot,
  cancellationDeadlineAt,
  refundAmountFor,
} from './domain/cancellation-policy';
import { summarizePayments } from './domain/payment-summary';

/** Relations every booking read needs to render the §59 resource. */
export const bookingInclude = {
  snapshot: true,
  payments: true,
  customer: { select: { id: true, name: true, phoneNumber: true } },
} as const;

export type BookingWithRelations = Prisma.BookingGetPayload<{ include: typeof bookingInclude }>;

const CUSTOMER_CANCELLABLE = ['pending_payment', 'confirmed'];

const money = (amount: number) => ({ amount, currency: 'IDR' });

export function cancellationPolicyOf(booking: BookingWithRelations): CancellationPolicySnapshot {
  return booking.snapshot?.cancellationPolicy as unknown as CancellationPolicySnapshot;
}

/** Net paid through online providers — the only refundable money (ADR 0018). */
export function netOnlinePaidOf(booking: BookingWithRelations): number {
  return summarizePayments(
    0,
    booking.payments.filter((p) => p.provider !== 'pay_at_location'),
  ).paidAmount;
}

export function paymentSummaryOf(booking: BookingWithRelations): Record<string, unknown> {
  const snapshot = booking.snapshot;
  const summary = summarizePayments(snapshot?.servicePriceAmount ?? 0, booking.payments);
  return {
    totalAmount: money(summary.totalAmount),
    requiredNow: money(snapshot?.requiredPaymentAmount ?? 0),
    paidAmount: money(summary.paidAmount),
    remainingAmount: money(summary.remainingAmount),
    status: summary.status,
  };
}

export function toBookingResource(
  booking: BookingWithRelations,
  opts: { businessView?: boolean; now?: Date } = {},
): Record<string, unknown> {
  const snapshot = booking.snapshot;
  const now = opts.now ?? new Date();
  const canCancel =
    CUSTOMER_CANCELLABLE.includes(booking.status) &&
    booking.scheduledAt !== null &&
    now < booking.scheduledAt;
  const policy = cancellationPolicyOf(booking);

  return {
    id: booking.id,
    bookingCode: booking.bookingCode,
    type: booking.bookingType,
    status: booking.status,
    customer: booking.customer
      ? {
          id: booking.customer.id,
          name: booking.customer.name,
          phoneNumber: booking.customer.phoneNumber,
        }
      : // A walk-in has no account, but §65 still owes the counter a name to
        // call — it lives on the booking row. Business view only.
        opts.businessView && booking.walkInCustomerName
        ? {
            id: null,
            name: booking.walkInCustomerName,
            phoneNumber: booking.walkInPhoneNumber,
          }
        : null,
    business: { id: booking.businessId, name: snapshot?.businessName ?? null },
    outlet: {
      id: booking.outletId,
      name: snapshot?.outletName ?? null,
      address: { formatted: snapshot?.outletAddressFormatted ?? null },
      timezone: snapshot?.outletTimezone ?? 'Asia/Jakarta',
    },
    service: {
      id: booking.serviceId,
      name: snapshot?.serviceName ?? null,
      durationMinutes: snapshot?.serviceDurationMinutes ?? null,
      price: money(snapshot?.servicePriceAmount ?? 0),
    },
    staff: booking.staffId
      ? {
          id: booking.staffId,
          name: snapshot?.staffName ?? null,
          // ponytail: the snapshot stores names, not file ids — an avatar here
          // needs a live staff_profiles join. Add it when a screen shows one.
          avatarUrl: null,
        }
      : null,
    scheduledAt: booking.scheduledAt?.toISOString() ?? null,
    expectedEndsAt: booking.expectedEndsAt?.toISOString() ?? null,
    paymentOption: booking.paymentOption,
    paymentSummary: paymentSummaryOf(booking),
    // ponytail: queue block lands with the queue milestone.
    queue: null,
    customerNotes: booking.customerNotes,
    ...(opts.businessView ? { internalNotes: booking.internalNotes } : {}),
    cancellation: {
      canCancel,
      refundEstimate:
        canCancel && policy && booking.scheduledAt
          ? money(refundAmountFor(policy, booking.scheduledAt, now, netOnlinePaidOf(booking)))
          : null,
      deadlineAt:
        policy && booking.scheduledAt
          ? cancellationDeadlineAt(policy, booking.scheduledAt).toISOString()
          : null,
    },
    createdAt: booking.createdAt.toISOString(),
    updatedAt: booking.updatedAt.toISOString(),
  };
}

export function toPaymentResource(payment: {
  id: string;
  bookingId: string;
  provider: string;
  providerReference: string | null;
  paymentOption: string;
  method: string | null;
  status: string;
  amount: number;
  checkout?: unknown;
  paidAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): Record<string, unknown> {
  return {
    id: payment.id,
    bookingId: payment.bookingId,
    provider: payment.provider,
    providerReference: payment.providerReference,
    paymentOption: payment.paymentOption,
    method: payment.method,
    status: payment.status,
    amount: money(payment.amount),
    // §60: normalized checkout instruction; null for pay-at-location.
    checkout: payment.checkout ?? null,
    paidAt: payment.paidAt?.toISOString() ?? null,
    expiresAt: payment.expiresAt?.toISOString() ?? null,
    createdAt: payment.createdAt.toISOString(),
    updatedAt: payment.updatedAt.toISOString(),
  };
}
