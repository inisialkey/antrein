import { ApiError } from '../auth/auth.errors';

/** Booking + M6 payment error factories (api-contract §120–§121, §75 HTTP mapping). */

export function bookingNotFound(): ApiError {
  return new ApiError(404, 'BOOKING_NOT_FOUND', 'Booking was not found.');
}

export function forbiddenBookingResource(): ApiError {
  return new ApiError(403, 'FORBIDDEN_BOOKING_RESOURCE', 'You cannot access this booking.');
}

export function bookingSlotUnavailable(): ApiError {
  return new ApiError(
    409,
    'BOOKING_SLOT_UNAVAILABLE',
    'The requested slot is no longer available.',
  );
}

export function bookingDateInPast(): ApiError {
  return new ApiError(400, 'BOOKING_DATE_IN_PAST', 'The requested time is in the past.');
}

export function bookingLeadTimeNotMet(minimumLeadMinutes: number): ApiError {
  return new ApiError(
    400,
    'BOOKING_LEAD_TIME_NOT_MET',
    'The requested time is inside the minimum booking lead time.',
    { minimumLeadMinutes },
  );
}

export function bookingHorizonExceeded(maximumAdvanceDays: number): ApiError {
  return new ApiError(
    400,
    'BOOKING_HORIZON_EXCEEDED',
    'The requested date is beyond the maximum booking horizon.',
    { maximumAdvanceDays },
  );
}

export function bookingActiveLimitReached(maxActiveBookings: number): ApiError {
  return new ApiError(
    409,
    'BOOKING_ACTIVE_LIMIT_REACHED',
    'You have reached the maximum number of active bookings for this business.',
    { maxActiveBookings },
  );
}

export function bookingCannotBeCancelled(): ApiError {
  return new ApiError(
    422,
    'BOOKING_CANNOT_BE_CANCELLED',
    'This booking can no longer be cancelled.',
  );
}

export function bookingAlreadyCancelled(): ApiError {
  return new ApiError(409, 'BOOKING_ALREADY_CANCELLED', 'This booking is already cancelled.');
}

export function bookingAlreadyCompleted(): ApiError {
  return new ApiError(409, 'BOOKING_ALREADY_COMPLETED', 'This booking is already completed.');
}

export function bookingInvalidStatusTransition(from: string, to: string): ApiError {
  return new ApiError(
    409,
    'BOOKING_INVALID_STATUS_TRANSITION',
    'The requested booking status transition is not allowed.',
    { from, to },
  );
}

export function businessNotActive(): ApiError {
  return new ApiError(409, 'BUSINESS_NOT_ACTIVE', 'This business is not accepting bookings.');
}

export function outletNotActive(): ApiError {
  return new ApiError(409, 'OUTLET_NOT_ACTIVE', 'This outlet is not accepting bookings.');
}

export function serviceNotActive(): ApiError {
  return new ApiError(409, 'SERVICE_NOT_ACTIVE', 'This service is not available for booking.');
}

export function staffNotActive(): ApiError {
  return new ApiError(409, 'STAFF_NOT_ACTIVE', 'This staff member is not available for booking.');
}

export function paymentOptionNotAvailable(): ApiError {
  return new ApiError(
    422,
    'PAYMENT_OPTION_NOT_AVAILABLE',
    'This payment option is not available for this business.',
  );
}

export function paymentProviderUnavailable(): ApiError {
  return new ApiError(
    503,
    'PAYMENT_PROVIDER_UNAVAILABLE',
    'Online payment is temporarily unavailable. Please try again later.',
  );
}

export function paymentNotFound(): ApiError {
  return new ApiError(404, 'PAYMENT_NOT_FOUND', 'Payment was not found.');
}

export function paymentAlreadyPaid(): ApiError {
  return new ApiError(409, 'PAYMENT_ALREADY_PAID', 'This payment is already paid.');
}

export function paymentAmountMismatch(expectedAmount: number): ApiError {
  return new ApiError(
    409,
    'PAYMENT_AMOUNT_MISMATCH',
    'The submitted amount does not match the outstanding amount.',
    { expectedAmount },
  );
}

export function paymentCurrencyMismatch(): ApiError {
  return new ApiError(409, 'PAYMENT_CURRENCY_MISMATCH', 'The submitted currency is not supported.');
}
