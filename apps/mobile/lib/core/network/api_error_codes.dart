/// Stable backend error codes (api-contract Part XVIII), surfaced in the error
/// envelope as `error.code`. Single registry — branch on these, never string
/// literals. Mirrors `apps/api/src/modules/auth/auth.errors.ts`.
abstract final class ApiErrorCodes {
  static const String authInvalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const String authAccessTokenInvalid = 'AUTH_ACCESS_TOKEN_INVALID';
  static const String authAccessTokenExpired = 'AUTH_ACCESS_TOKEN_EXPIRED';
  static const String authRefreshTokenInvalid = 'AUTH_REFRESH_TOKEN_INVALID';
  static const String authRefreshTokenExpired = 'AUTH_REFRESH_TOKEN_EXPIRED';
  static const String authRefreshTokenReused = 'AUTH_REFRESH_TOKEN_REUSED';
  static const String authSessionRevoked = 'AUTH_SESSION_REVOKED';
  static const String authEmailAlreadyRegistered =
      'AUTH_EMAIL_ALREADY_REGISTERED';
  static const String authAccountSuspended = 'AUTH_ACCOUNT_SUSPENDED';
  static const String authAccountInactive = 'AUTH_ACCOUNT_INACTIVE';
  static const String authResetTokenInvalid = 'AUTH_RESET_TOKEN_INVALID';
  static const String authResetTokenExpired = 'AUTH_RESET_TOKEN_EXPIRED';
  static const String authPasswordReuseNotAllowed =
      'AUTH_PASSWORD_REUSE_NOT_ALLOWED';
  static const String rateLimitExceeded = 'RATE_LIMIT_EXCEEDED';
  static const String validationFailed = 'VALIDATION_FAILED';

  // Booking + payment (api-contract §60, §63, §72 — mirrors booking.errors.ts)
  static const String bookingSlotUnavailable = 'BOOKING_SLOT_UNAVAILABLE';
  static const String bookingActiveLimitReached =
      'BOOKING_ACTIVE_LIMIT_REACHED';
  static const String bookingLeadTimeNotMet = 'BOOKING_LEAD_TIME_NOT_MET';
  static const String bookingDateInPast = 'BOOKING_DATE_IN_PAST';
  static const String bookingCannotBeCancelled = 'BOOKING_CANNOT_BE_CANCELLED';
  static const String bookingAlreadyCancelled = 'BOOKING_ALREADY_CANCELLED';
  static const String paymentOptionNotAvailable =
      'PAYMENT_OPTION_NOT_AVAILABLE';
  static const String paymentProviderUnavailable =
      'PAYMENT_PROVIDER_UNAVAILABLE';
  static const String paymentRefreshRateLimited =
      'PAYMENT_STATUS_REFRESH_RATE_LIMITED';

  // Queue + check-in (api-contract §58/§122 — mirrors queue/domain/queue.errors.ts)
  static const String bookingCheckInTooEarly = 'BOOKING_CHECK_IN_TOO_EARLY';
  static const String bookingCheckInTooLate = 'BOOKING_CHECK_IN_TOO_LATE';
  static const String bookingNotConfirmed = 'BOOKING_NOT_CONFIRMED';
  static const String queueEntryAlreadyExists = 'QUEUE_ENTRY_ALREADY_EXISTS';
  static const String outletQueueClosed = 'OUTLET_QUEUE_CLOSED';
  static const String queueEntryNotFound = 'QUEUE_ENTRY_NOT_FOUND';
  static const String forbiddenQueueResource = 'FORBIDDEN_QUEUE_RESOURCE';

  // Staff queue commands (api-contract §122 — mirrors queue/domain/queue.errors.ts)
  static const String queueVersionConflict = 'QUEUE_VERSION_CONFLICT';
  static const String queueHasCalledEntry = 'QUEUE_HAS_CALLED_ENTRY';
  static const String staffNotAvailable = 'STAFF_NOT_AVAILABLE';
  static const String queueEntryNotWaiting = 'QUEUE_ENTRY_NOT_WAITING';
  static const String queueEntryNotCalled = 'QUEUE_ENTRY_NOT_CALLED';
  static const String queueEntryNotInService = 'QUEUE_ENTRY_NOT_IN_SERVICE';
  static const String queueEntryNotSkipped = 'QUEUE_ENTRY_NOT_SKIPPED';

  /// Access-token 401s that should trigger a transparent refresh + retry.
  /// (The API returns `_INVALID` for both malformed and expired access tokens.)
  static const Set<String> refreshable = {
    authAccessTokenExpired,
    authAccessTokenInvalid,
  };
}

/// Extracts the stable `error.code` from a decoded response envelope
/// (`{ success: false, error: { code, message } }`), or null if absent.
String? errorCodeOf(dynamic body) {
  if (body is Map) {
    final error = body['error'];
    if (error is Map) {
      return error['code'] as String?;
    }
  }
  return null;
}

/// Extracts the human `error.message` from an error envelope, with a fallback.
String errorMessageOf(dynamic body, {String fallback = 'Request failed.'}) {
  if (body is Map) {
    final error = body['error'];
    if (error is Map) {
      return error['message'] as String? ?? fallback;
    }
  }
  return fallback;
}
