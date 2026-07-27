import 'package:equatable/equatable.dart';

/// The domain-facing error type. Repositories return `Left(Failure)`; Cubits
/// map it to UX. Every failure carries a human-readable message; the concrete
/// subtype (auth, conflict, validation, rate-limit, …) is what call sites
/// branch on. The stable backend `error.code` is mapped to that subtype in the
/// data layer (see `ApiErrorCodes`) and preserved in [code] so screens can
/// localize well-known cases (e.g. BOOKING_SLOT_UNAVAILABLE).
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;

  /// Stable backend `error.code`, when the failure came from an API envelope.
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// A uniqueness/state conflict (HTTP 409) — e.g. `AUTH_EMAIL_ALREADY_REGISTERED`.
class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code});
}

/// Too many attempts (HTTP 429) — `RATE_LIMIT_EXCEEDED`.
class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {super.code});
}
