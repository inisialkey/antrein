/**
 * Permission catalog (api-contract §127). Stored per membership as a jsonb
 * array (ADR 0038); owners hold the full set (§128).
 */
export const ALL_PERMISSIONS = [
  'business.read',
  'business.manage',
  'service.read',
  'service.manage',
  'staff.read',
  'staff.manage',
  'schedule.read',
  'schedule.manage',
  'booking.read',
  'booking.manage',
  'queue.read',
  'queue.manage',
  'queue.reorder',
  'payment.read',
  'payment.confirm',
  'payment.refund',
  'reports.read',
  'review.moderate',
] as const;

export type Permission = (typeof ALL_PERMISSIONS)[number];

export const OWNER_PERMISSIONS: readonly Permission[] = ALL_PERMISSIONS;

export function isPermission(value: string): value is Permission {
  return (ALL_PERMISSIONS as readonly string[]).includes(value);
}

export const MEMBERSHIP_ROLES = ['owner', 'manager', 'barber', 'front_desk', 'cashier'] as const;
export type MembershipRole = (typeof MEMBERSHIP_ROLES)[number];

/** Roles staff can be invited as — `owner` only ever comes from creation. */
export const INVITABLE_ROLES = MEMBERSHIP_ROLES.filter((r) => r !== 'owner');

/** Role default permissions (api-contract §128); explicit invite lists override. */
export const ROLE_DEFAULT_PERMISSIONS: Record<Exclude<MembershipRole, 'owner'>, Permission[]> = {
  manager: [
    'business.read',
    'service.read',
    'staff.read',
    'schedule.read',
    'booking.read',
    'booking.manage',
    'queue.read',
    'queue.manage',
    'payment.read',
    'payment.confirm',
    'reports.read',
  ],
  barber: ['booking.read', 'queue.read', 'queue.manage', 'payment.read'],
  front_desk: [
    'booking.read',
    'booking.manage',
    'queue.read',
    'queue.manage',
    'payment.read',
    'payment.confirm',
  ],
  // §128 has no cashier row — payment-desk subset until ratified otherwise.
  cashier: ['booking.read', 'queue.read', 'payment.read', 'payment.confirm'],
};
