import 'package:antrein/core/error/exceptions.dart';
import 'package:antrein/core/error/failures.dart';
import 'package:antrein/core/logging/app_logger.dart';

/// Shared exception → Failure mapping for feature repositories (auth keeps its
/// own auth-specific version). Preserves the backend `error.code`.
Failure mapExceptionToFailure(Exception e, String label) => switch (e) {
  AuthException(:final message, :final code) => AuthFailure(
    message,
    code: code,
  ),
  ConflictException(:final message, :final code) => ConflictFailure(
    message,
    code: code,
  ),
  ValidationException(:final message, :final code) => ValidationFailure(
    message,
    code: code,
  ),
  RateLimitException(:final message, :final code) => RateLimitFailure(
    message,
    code: code,
  ),
  NetworkException(:final message, :final code) => NetworkFailure(
    message,
    code: code,
  ),
  ServerException(:final message, :final code) => ServerFailure(
    message,
    code: code,
  ),
  _ => _unexpected(e, label),
};

Failure _unexpected(Exception e, String label) {
  AppLogger.e('Unexpected error in $label', error: e);
  return const ServerFailure('Something went wrong. Please try again.');
}
