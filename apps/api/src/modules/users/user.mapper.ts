import { User, UserNotificationPreference } from '../../generated/prisma/client';

export interface UserResponse {
  id: string;
  name: string;
  email: string;
  phoneNumber: string | null;
  avatarUrl: string | null;
  status: string;
  roles: string[];
  businessMemberships: unknown[];
  createdAt: string;
}

/**
 * Contract user shape. Roles/memberships are customer-only until the
 * memberships module lands (M4) — the backend derives them, never the client.
 */
export function toUserResponse(user: User): UserResponse {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phoneNumber: user.phoneNumber,
    avatarUrl: null,
    status: user.status,
    roles: ['customer'],
    businessMemberships: [],
    createdAt: user.createdAt.toISOString(),
  };
}

export function toMeResponse(
  user: User,
  prefs: UserNotificationPreference | null,
): UserResponse & { notificationPreferences: Record<string, boolean>; updatedAt: string } {
  return {
    ...toUserResponse(user),
    notificationPreferences: {
      bookingUpdates: prefs?.bookingUpdates ?? true,
      paymentUpdates: prefs?.paymentUpdates ?? true,
      queueUpdates: prefs?.queueUpdates ?? true,
      marketing: prefs?.marketing ?? false,
    },
    updatedAt: user.updatedAt.toISOString(),
  };
}
