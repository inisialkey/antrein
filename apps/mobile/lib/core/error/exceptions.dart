/// Data-layer exceptions. The remote data source throws these after unwrapping
/// the response envelope; the repository catches them and maps each to a
/// Failure. They stay inside the data layer — never surfaced to the UI.
/// The `code` field carries the stable backend `error.code` when present.
library;

class ServerException implements Exception {
  const ServerException(this.message, {this.code});

  final String message;
  final String? code;
}

class CacheException implements Exception {
  const CacheException(this.message, {this.code});

  final String message;
  final String? code;
}

/// Authentication problems: invalid credentials, or an unauthenticated/expired
/// session that could not be refreshed, suspended/inactive account, bad reset
/// token.
class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;
}

/// A 422/400 `VALIDATION_FAILED` response.
class ValidationException implements Exception {
  const ValidationException(this.message, {this.code});

  final String message;
  final String? code;
}

/// A 409 conflict — e.g. `AUTH_EMAIL_ALREADY_REGISTERED`.
class ConflictException implements Exception {
  const ConflictException(this.message, {this.code});

  final String message;
  final String? code;
}

/// A 429 `RATE_LIMIT_EXCEEDED` response.
class RateLimitException implements Exception {
  const RateLimitException(this.message, {this.code});

  final String message;
  final String? code;
}

/// Connectivity/timeout problems.
class NetworkException implements Exception {
  const NetworkException(this.message, {this.code});

  final String message;
  final String? code;
}
