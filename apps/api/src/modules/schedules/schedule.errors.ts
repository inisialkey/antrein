import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const scheduleInvalidPeriod = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SCHEDULE_INVALID_PERIOD',
    'Schedule periods must use HH:MM times with start before end, and breaks must fall inside a period.',
  );

export const scheduleOverlappingPeriods = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SCHEDULE_OVERLAPPING_PERIODS',
    'Schedule periods must not overlap.',
  );

export const scheduleInvalidTimezone = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SCHEDULE_INVALID_TIMEZONE',
    'Only the Asia/Jakarta timezone is supported.',
  );

export const scheduleDateInPast = (): ApiError =>
  new ApiError(HttpStatus.BAD_REQUEST, 'SCHEDULE_DATE_IN_PAST', 'Date must not be in the past.');

export const scheduleDateOutOfRange = (maximumAdvanceDays: number): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SCHEDULE_DATE_OUT_OF_RANGE',
    'Date must be within the booking window.',
    { maximumAdvanceDays },
  );

export const scheduleClosedDateAlreadyExists = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'SCHEDULE_CLOSED_DATE_ALREADY_EXISTS',
    'This date is already marked as closed.',
  );

export const staffNotEligibleForService = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'STAFF_NOT_ELIGIBLE_FOR_SERVICE',
    'Staff member is not eligible for this service.',
  );
