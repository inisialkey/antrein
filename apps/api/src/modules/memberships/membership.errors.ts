import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const forbiddenBusinessResource = (): ApiError =>
  new ApiError(
    HttpStatus.FORBIDDEN,
    'FORBIDDEN_BUSINESS_RESOURCE',
    'You do not have access to this business resource.',
  );

export const permissionRequired = (permission: string): ApiError =>
  new ApiError(HttpStatus.FORBIDDEN, 'PERMISSION_REQUIRED', 'A required permission is missing.', {
    permission,
  });

export const membershipInactive = (): ApiError =>
  new ApiError(HttpStatus.FORBIDDEN, 'MEMBERSHIP_INACTIVE', 'Your membership is not active.');

export const businessNotFound = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'BUSINESS_NOT_FOUND', 'Business was not found.');
