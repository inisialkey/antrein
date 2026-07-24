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
