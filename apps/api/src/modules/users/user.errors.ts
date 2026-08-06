import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const userPhoneAlreadyUsed = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'USER_PHONE_ALREADY_USED',
    'That phone number belongs to another account.',
  );
