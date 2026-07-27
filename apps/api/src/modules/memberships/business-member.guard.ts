import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { BusinessMembership } from '../../generated/prisma/client';
import { accessTokenInvalid } from '../auth/auth.errors';
import { MembershipsService } from './memberships.service';
import { Permission } from './permissions';
import { BUSINESS_PERMISSION_KEY } from './require-permission.decorator';

declare module 'express-serve-static-core' {
  interface Request {
    membership?: BusinessMembership;
  }
}

/**
 * Runs after the global AuthGuard on routes tagged with
 * @RequireBusinessPermission: resolves the caller's membership in
 * `:businessId` and attaches it to the request.
 */
@Injectable()
export class BusinessMemberGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly memberships: MembershipsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requirement = this.reflector.getAllAndOverride<{ permission: Permission | null }>(
      BUSINESS_PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requirement) return true;

    const req = context.switchToHttp().getRequest<Request>();
    const principal = req.principal;
    if (!principal) throw accessTokenInvalid();
    const businessId = String(req.params.businessId ?? '');

    req.membership = await this.memberships.requirePermission(
      principal.userId,
      businessId,
      requirement.permission,
    );
    return true;
  }
}
