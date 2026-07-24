import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../auth/auth.errors';

export const staffNotFound = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'STAFF_NOT_FOUND', 'Staff member was not found.');

export const staffAlreadyMember = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'STAFF_ALREADY_MEMBER',
    'This person is already a member of the business.',
  );

export const staffInvitationAlreadyPending = (): ApiError =>
  new ApiError(
    HttpStatus.CONFLICT,
    'STAFF_INVITATION_ALREADY_PENDING',
    'A pending invitation already exists for this email.',
  );

export const staffInvitationNotFound = (): ApiError =>
  new ApiError(HttpStatus.NOT_FOUND, 'STAFF_INVITATION_NOT_FOUND', 'Invitation was not found.');

export const staffInvitationExpired = (): ApiError =>
  new ApiError(HttpStatus.GONE, 'STAFF_INVITATION_EXPIRED', 'Invitation has expired.');

export const outletNotInBusiness = (outletIds: string[]): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'OUTLET_NOT_IN_BUSINESS',
    'Outlet does not belong to this business.',
    { outletIds },
  );

export const serviceNotInBusiness = (serviceIds: string[]): ApiError =>
  new ApiError(
    HttpStatus.BAD_REQUEST,
    'SERVICE_NOT_IN_BUSINESS',
    'Service does not belong to this business.',
    { serviceIds },
  );
