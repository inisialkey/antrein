import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const reviewBookingNotCompleted = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'REVIEW_BOOKING_NOT_COMPLETED',
    'Only completed bookings can be reviewed.',
  );

export const reviewAlreadyExists = (): ApiError =>
  new ApiError(HttpStatus.CONFLICT, 'REVIEW_ALREADY_EXISTS', 'This booking already has a review.');

export const reviewNotAllowed = (): ApiError =>
  new ApiError(
    HttpStatus.FORBIDDEN,
    'REVIEW_NOT_ALLOWED',
    'You are not allowed to review this booking.',
  );

export const reviewRatingInvalid = (): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'REVIEW_RATING_INVALID',
    'Rating must be an integer between 1 and 5.',
  );
