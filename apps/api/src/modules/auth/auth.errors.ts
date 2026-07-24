import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Contract error with a stable UPPER_SNAKE code (api-contract Part XVIII).
 * The global HttpExceptionFilter serializes { code, message, details } as-is.
 */
export class ApiError extends HttpException {
  constructor(
    status: HttpStatus,
    code: string,
    message: string,
    details?: Record<string, unknown>,
  ) {
    super({ code, message, ...(details ? { details } : {}) }, status);
  }
}

export const invalidCredentials = (): ApiError =>
  new ApiError(
    HttpStatus.UNAUTHORIZED,
    'AUTH_INVALID_CREDENTIALS',
    'Email or password is incorrect.',
  );

export const accessTokenInvalid = (): ApiError =>
  new ApiError(
    HttpStatus.UNAUTHORIZED,
    'AUTH_ACCESS_TOKEN_INVALID',
    'Access token is missing or invalid.',
  );

export const accessTokenExpired = (): ApiError =>
  new ApiError(HttpStatus.UNAUTHORIZED, 'AUTH_ACCESS_TOKEN_EXPIRED', 'Access token has expired.');

export const refreshTokenInvalid = (): ApiError =>
  new ApiError(HttpStatus.UNAUTHORIZED, 'AUTH_REFRESH_TOKEN_INVALID', 'Refresh token is invalid.');

export const refreshTokenExpired = (): ApiError =>
  new ApiError(HttpStatus.UNAUTHORIZED, 'AUTH_REFRESH_TOKEN_EXPIRED', 'Refresh token has expired.');

export const refreshTokenReused = (): ApiError =>
  new ApiError(
    HttpStatus.UNAUTHORIZED,
    'AUTH_REFRESH_TOKEN_REUSED',
    'Refresh token was already used. Please log in again.',
  );

export const sessionRevoked = (): ApiError =>
  new ApiError(HttpStatus.UNAUTHORIZED, 'AUTH_SESSION_REVOKED', 'Session has been revoked.');

export const emailAlreadyRegistered = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'AUTH_EMAIL_ALREADY_REGISTERED',
    'Email is already registered.',
  );

export const accountSuspended = (): ApiError =>
  new ApiError(HttpStatus.FORBIDDEN, 'AUTH_ACCOUNT_SUSPENDED', 'Account is suspended.');

export const accountInactive = (): ApiError =>
  new ApiError(HttpStatus.FORBIDDEN, 'AUTH_ACCOUNT_INACTIVE', 'Account is inactive.');

export const resetTokenInvalid = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'AUTH_RESET_TOKEN_INVALID',
    'Reset token is invalid or already used.',
  );

export const resetTokenExpired = (): ApiError =>
  new ApiError(HttpStatus.GONE, 'AUTH_RESET_TOKEN_EXPIRED', 'Reset token has expired.');

export const passwordReuseNotAllowed = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'AUTH_PASSWORD_REUSE_NOT_ALLOWED',
    'New password must be different from the current password.',
  );

export const rateLimitExceeded = (): ApiError =>
  new ApiError(
    HttpStatus.TOO_MANY_REQUESTS,
    'RATE_LIMIT_EXCEEDED',
    'Too many attempts. Try again later.',
  );

export const validationFailed = (message: string): ApiError =>
  new ApiError(HttpStatus.BAD_REQUEST, 'VALIDATION_FAILED', message);
