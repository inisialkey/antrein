import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const idempotencyKeyRequired = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'IDEMPOTENCY_KEY_REQUIRED',
    'Idempotency-Key header is required for this operation.',
  );

export const idempotencyKeyReused = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'IDEMPOTENCY_KEY_REUSED',
    'Idempotency-Key was already used with a different request.',
  );

export const idempotencyRequestInProgress = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'IDEMPOTENCY_REQUEST_IN_PROGRESS',
    'A request with this Idempotency-Key is still being processed.',
  );
