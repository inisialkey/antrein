import { ApiError } from '../auth/auth.errors';

/** Notification/device error catalog (api-contract §122.1). */

export function notificationNotFound(): ApiError {
  return new ApiError(404, 'NOTIFICATION_NOT_FOUND', 'No notification was found.');
}

export function deviceNotFound(): ApiError {
  return new ApiError(404, 'DEVICE_NOT_FOUND', 'No device was found.');
}
