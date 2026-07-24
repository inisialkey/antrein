import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const businessLimitReached = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'BUSINESS_LIMIT_REACHED',
    'You already own a business. MVP allows one owned business per account.',
  );

export const businessNotActive = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'BUSINESS_NOT_ACTIVE', 'Business is not active.');

export const outletNotFound = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'OUTLET_NOT_FOUND', 'Outlet was not found.');

export const paymentOptionNotSupported = (option: string): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'PAYMENT_OPTION_NOT_SUPPORTED',
    'Payment option is not supported.',
    { option },
  );
