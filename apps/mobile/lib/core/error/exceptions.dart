/// Data-layer exceptions. The remote data source throws these after unwrapping
/// the response envelope; the repository catches them and maps each to a
/// Failure. They stay inside the data layer — never surfaced to the UI.
library;

class ServerException implements Exception {
  const ServerException(this.message);

  final String message;
}

class CacheException implements Exception {
  const CacheException(this.message);

  final String message;
}

/// Authentication problems: invalid credentials, or an unauthenticated/expired
/// session that could not be refreshed, suspended/inactive account, bad reset
/// token.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

/// A 422/400 `VALIDATION_FAILED` response.
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;
}

/// A 409 conflict — e.g. `AUTH_EMAIL_ALREADY_REGISTERED`.
class ConflictException implements Exception {
  const ConflictException(this.message);

  final String message;
}

/// A 429 `RATE_LIMIT_EXCEEDED` response.
class RateLimitException implements Exception {
  const RateLimitException(this.message);

  final String message;
}

/// Connectivity/timeout problems.
class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;
}
