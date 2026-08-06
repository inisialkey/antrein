import { fileUrl } from '../../common/files/file-url';
import { User, UserNotificationPreference } from '../../generated/prisma/client';
import { deriveRoles, MembershipSummary } from '../memberships/memberships.service';

export interface UserResponse {
  id: string;
  name: string;
  email: string;
  phoneNumber: string | null;
  avatarUrl: string | null;
  status: string;
  roles: string[];
  businessMemberships: MembershipSummary[];
  createdAt: string;
}

/** Contract user shape. Roles/memberships are derived by the backend, never the client. */
export function toUserResponse(user: User, memberships: MembershipSummary[]): UserResponse {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phoneNumber: user.phoneNumber,
    avatarUrl: fileUrl(user.avatarFileId),
    status: user.status,
    roles: deriveRoles(memberships.map((m) => ({ role: m.role, status: 'active' }))),
    businessMemberships: memberships,
    createdAt: user.createdAt.toISOString(),
  };
}

export function toMeResponse(
  user: User,
  prefs: UserNotificationPreference | null,
  memberships: MembershipSummary[],
): UserResponse & { notificationPreferences: Record<string, boolean>; updatedAt: string } {
  return {
    ...toUserResponse(user, memberships),
    notificationPreferences: {
      bookingUpdates: prefs?.bookingUpdates ?? true,
      paymentUpdates: prefs?.paymentUpdates ?? true,
      queueUpdates: prefs?.queueUpdates ?? true,
      marketing: prefs?.marketing ?? false,
    },
    updatedAt: user.updatedAt.toISOString(),
  };
}
