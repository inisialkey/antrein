import { bookingInvalidStatusTransition } from '../booking.errors';

/** Booking lifecycle (product brief §16, booking-payment §8). */
export const BOOKING_STATUSES = [
  'draft',
  'pending_payment',
  'confirmed',
  'checked_in',
  'waiting',
  'called',
  'in_service',
  'completed',
  'cancelled',
  'expired',
  'no_show',
] as const;

export type BookingStatus = (typeof BOOKING_STATUSES)[number];

/** Statuses whose booking holds a staff reservation (ADR 0027). */
export const BLOCKING_BOOKING_STATUSES: readonly BookingStatus[] = [
  'pending_payment',
  'confirmed',
  'checked_in',
  'waiting',
  'called',
  'in_service',
];

export const TERMINAL_BOOKING_STATUSES: readonly BookingStatus[] = [
  'completed',
  'cancelled',
  'expired',
  'no_show',
];

// ponytail: 'skipped' is a queue-only state (bookings CHECK constraint has no
// 'skipped'); called → waiting stands in for skip-return until the queue
// milestone ratifies the exact booking↔queue mapping.
const ALLOWED_TRANSITIONS: Record<BookingStatus, readonly BookingStatus[]> = {
  draft: ['pending_payment', 'confirmed'],
  pending_payment: ['confirmed', 'expired', 'cancelled'],
  confirmed: ['checked_in', 'cancelled', 'no_show'],
  checked_in: ['waiting'],
  waiting: ['called'],
  called: ['in_service', 'no_show', 'waiting'],
  in_service: ['completed'],
  completed: [],
  cancelled: [],
  expired: [],
  no_show: [],
};

export function canTransition(from: BookingStatus, to: BookingStatus): boolean {
  return ALLOWED_TRANSITIONS[from].includes(to);
}

export function assertBookingTransition(from: BookingStatus, to: BookingStatus): void {
  if (!canTransition(from, to)) throw bookingInvalidStatusTransition(from, to);
}
