import { ApiError } from '../../../auth/auth.errors';

/**
 * Queue error catalog (api-contract §58, realtime-queue §58/§59). HTTP codes
 * follow the §59 mapping table; state-precondition failures are 409, window/
 * payload failures 422, authorization 403.
 */

export function queueEntryNotFound(): ApiError {
  return new ApiError(404, 'QUEUE_ENTRY_NOT_FOUND', 'No queue entry was found.');
}

export function queueEntryAlreadyExists(): ApiError {
  return new ApiError(409, 'QUEUE_ENTRY_ALREADY_EXISTS', 'This booking is already in the queue.');
}

export function queueEntryNotWaiting(): ApiError {
  return new ApiError(409, 'QUEUE_ENTRY_NOT_WAITING', 'The queue entry is not waiting.');
}

export function queueEntryNotCalled(): ApiError {
  return new ApiError(409, 'QUEUE_ENTRY_NOT_CALLED', 'The queue entry is not called.');
}

export function queueEntryNotSkipped(): ApiError {
  return new ApiError(409, 'QUEUE_ENTRY_NOT_SKIPPED', 'The queue entry is not skipped.');
}

export function queueEntryNotInService(): ApiError {
  return new ApiError(409, 'QUEUE_ENTRY_NOT_IN_SERVICE', 'The queue entry is not in service.');
}

export function queueEntryAlreadyCompleted(): ApiError {
  return new ApiError(
    409,
    'QUEUE_ENTRY_ALREADY_COMPLETED',
    'The queue entry is already completed.',
  );
}

export function queueHasCalledEntry(): ApiError {
  return new ApiError(
    409,
    'QUEUE_HAS_CALLED_ENTRY',
    'Another entry is already called. Resolve it before calling the next.',
  );
}

export function queueVersionConflict(): ApiError {
  return new ApiError(
    409,
    'QUEUE_VERSION_CONFLICT',
    'The queue entry changed since you last read it. Refetch and retry.',
  );
}

export function queueReorderInvalidEntries(): ApiError {
  return new ApiError(
    422,
    'QUEUE_REORDER_INVALID_ENTRIES',
    'The reorder list does not match the reorderable queue entries.',
  );
}

export function queueReorderReasonRequired(): ApiError {
  return new ApiError(422, 'QUEUE_REORDER_REASON_REQUIRED', 'A reorder reason is required.');
}

export function outletQueueClosed(): ApiError {
  return new ApiError(422, 'OUTLET_QUEUE_CLOSED', 'The outlet queue is closed.');
}

export function forbiddenQueueResource(): ApiError {
  return new ApiError(403, 'FORBIDDEN_QUEUE_RESOURCE', 'You cannot access this queue resource.');
}

export function forbiddenQueueReorder(): ApiError {
  return new ApiError(403, 'FORBIDDEN_QUEUE_REORDER', 'You cannot reorder this queue.');
}

export function bookingCheckInTooEarly(): ApiError {
  return new ApiError(422, 'BOOKING_CHECK_IN_TOO_EARLY', 'Check-in has not opened yet.');
}

export function bookingCheckInTooLate(): ApiError {
  return new ApiError(422, 'BOOKING_CHECK_IN_TOO_LATE', 'The check-in window has closed.');
}

export function bookingNotConfirmed(): ApiError {
  return new ApiError(422, 'BOOKING_NOT_CONFIRMED', 'The booking is not confirmed.');
}

export function staffNotAvailable(): ApiError {
  return new ApiError(422, 'STAFF_NOT_AVAILABLE', 'The staff member is not available.');
}
