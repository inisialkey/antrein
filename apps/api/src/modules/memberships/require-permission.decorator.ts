import { SetMetadata } from '@nestjs/common';
import { Permission } from './permissions';

export const BUSINESS_PERMISSION_KEY = 'businessPermission';

/**
 * Requires an active membership in the `:businessId` of the route, holding
 * `permission`. Pass `null` for membership-only endpoints (e.g. GET
 * /businesses/:businessId/management). Enforced by BusinessMemberGuard.
 */
export const RequireBusinessPermission = (
  permission: Permission | null,
): MethodDecorator & ClassDecorator => SetMetadata(BUSINESS_PERMISSION_KEY, { permission });
