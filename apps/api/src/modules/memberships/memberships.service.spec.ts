import { BusinessMembership } from '../../generated/prisma/client';
import { deriveRoles, permissionsOf } from './memberships.service';

const membership = (role: string, status = 'active'): Pick<BusinessMembership, 'role' | 'status'> =>
  ({ role, status }) as Pick<BusinessMembership, 'role' | 'status'>;

describe('deriveRoles', () => {
  it('is customer-only without memberships', () => {
    expect(deriveRoles([])).toEqual(['customer']);
  });

  it('adds business_owner for an owner membership', () => {
    expect(deriveRoles([membership('owner')])).toEqual(['customer', 'business_owner']);
  });

  it('adds staff for non-owner memberships', () => {
    expect(deriveRoles([membership('barber')])).toEqual(['customer', 'staff']);
  });

  it('combines and ignores inactive memberships', () => {
    expect(deriveRoles([membership('owner'), membership('front_desk')])).toEqual([
      'customer',
      'business_owner',
      'staff',
    ]);
    expect(deriveRoles([membership('owner', 'inactive')])).toEqual(['customer']);
  });
});

describe('permissionsOf', () => {
  it('reads the jsonb array and tolerates malformed values', () => {
    expect(
      permissionsOf({ permissions: ['queue.manage'] } as unknown as BusinessMembership),
    ).toEqual(['queue.manage']);
    expect(permissionsOf({ permissions: null } as unknown as BusinessMembership)).toEqual([]);
  });
});
