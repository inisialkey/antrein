import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const serviceNotFound = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'SERVICE_NOT_FOUND', 'Service was not found.');

export const serviceNameAlreadyExists = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'SERVICE_NAME_ALREADY_EXISTS',
    'A service with this name already exists.',
  );

export const serviceInvalidDuration = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SERVICE_INVALID_DURATION',
    'Service duration must be between 1 and 600 minutes.',
  );

export const serviceInvalidPrice = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SERVICE_INVALID_PRICE',
    'Service price must be a non-negative IDR amount.',
  );

export const serviceInvalidDeposit = (message: string): ApiError =>
  new ApiError(HttpStatus.BAD_REQUEST, 'SERVICE_INVALID_DEPOSIT', message);

export const staffNotFound = (staffIds?: string[]): ApiError =>
  new ApiError(
    HttpStatus.NOT_FOUND,
    'STAFF_NOT_FOUND',
    'Staff member was not found.',
    staffIds ? { staffIds } : undefined,
  );

export const staffNotInBusiness = (staffIds: string[]): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'STAFF_NOT_IN_BUSINESS',
    'Staff member does not belong to this business.',
    { staffIds },
  );
