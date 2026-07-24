import 'package:equatable/equatable.dart';

/// The domain-facing error type. Repositories return `Left(Failure)`; Cubits
/// map it to UX. Every failure carries a human-readable message; the concrete
/// subtype (auth, conflict, validation, rate-limit, …) is what call sites
/// branch on. The stable backend `error.code` is mapped to that subtype in the
/// data layer (see `ApiErrorCodes`).
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// A uniqueness/state conflict (HTTP 409) — e.g. `AUTH_EMAIL_ALREADY_REGISTERED`.
class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

/// Too many attempts (HTTP 429) — `RATE_LIMIT_EXCEEDED`.
class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message);
}
