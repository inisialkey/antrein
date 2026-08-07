import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const fileNotFound = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'FILE_NOT_FOUND', 'File not found.');

export const fileNotOwned = (): ApiError =>
  new ApiError(HttpStatus.FORBIDDEN, 'FILE_NOT_OWNED', 'This file belongs to another account.');

export const fileAlreadyAttached = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'FILE_ALREADY_ATTACHED',
    'This file is already attached to a resource.',
  );

export const fileTooLarge = (maxBytes: number): ApiError =>
  new ApiError(HttpStatus.PAYLOAD_TOO_LARGE, 'FILE_TOO_LARGE', 'File exceeds the size limit.', {
    maxBytes,
  });

export const fileTypeNotAllowed = (allowed: string[]): ApiError =>
  new ApiError(
    HttpStatus.UNSUPPORTED_MEDIA_TYPE,
    'FILE_TYPE_NOT_ALLOWED',
    'Only JPEG, PNG and WebP images are accepted.',
    { allowed },
  );

export const fileInvalidContent = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'FILE_INVALID_CONTENT',
    'File content does not match its declared image type.',
  );

export const fileUploadFailed = (): ApiError =>
  new ApiError(
    HttpStatus.INTERNAL_SERVER_ERROR,
    'FILE_UPLOAD_FAILED',
    'The file could not be stored. Try again.',
  );
