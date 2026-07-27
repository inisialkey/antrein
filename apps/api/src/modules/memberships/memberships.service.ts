import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { BusinessMembership } from '../../generated/prisma/client';
import {
  businessNotFound,
  forbiddenBusinessResource,
  membershipInactive,
  permissionRequired,
} from './membership.errors';
import { Permission } from './permissions';

export interface MembershipSummary {
  businessId: string;
  businessName: string;
  role: string;
  permissions: string[];
  outletIds: string[];
}

export function permissionsOf(membership: BusinessMembership): string[] {
  return Array.isArray(membership.permissions) ? (membership.permissions as string[]) : [];
}

/** Product roles derived from memberships (ADR 0020 shared multi-role account). */
export function deriveRoles(memberships: Pick<BusinessMembership, 'role' | 'status'>[]): string[] {
  const active = memberships.filter((m) => m.status === 'active');
  const roles = ['customer'];
  if (active.some((m) => m.role === 'owner')) roles.push('business_owner');
  if (active.some((m) => m.role !== 'owner')) roles.push('staff');
  return roles;
}

@Injectable()
export class MembershipsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Active memberships with the outlet scope shown in GET /me. */
  async listForUser(userId: string): Promise<MembershipSummary[]> {
    const memberships = await this.prisma.businessMembership.findMany({
      where: { userId, status: 'active' },
      include: {
        business: {
          select: { name: true, outlets: { where: { status: 'active' }, select: { id: true } } },
        },
        staffProfile: { select: { outletAssignments: { select: { outletId: true } } } },
      },
      orderBy: { createdAt: 'asc' },
    });
    return memberships.map((m) => ({
      businessId: m.businessId,
      businessName: m.business.name,
      role: m.role,
      permissions: permissionsOf(m),
      outletIds: m.staffProfile
        ? m.staffProfile.outletAssignments.map((a) => a.outletId)
        : m.business.outlets.map((o) => o.id),
    }));
  }

  async listRolesForUser(userId: string): Promise<string[]> {
    const memberships = await this.prisma.businessMembership.findMany({
      where: { userId },
      select: { role: true, status: true },
    });
    return deriveRoles(memberships as BusinessMembership[]);
  }

  /**
   * Authorization ladder (CLAUDE.md invariant): business exists → membership
   * exists → membership active → permission present. Knowing an ID is never
   * permission, so a non-member gets 403, not the resource.
   */
  async requirePermission(
    userId: string,
    businessId: string,
    permission: Permission | null,
  ): Promise<BusinessMembership> {
    const membership = await this.prisma.businessMembership.findUnique({
      where: { businessId_userId: { businessId, userId } },
      include: { business: { select: { id: true } } },
    });
    if (!membership) {
      const business = await this.prisma.business.findUnique({
        where: { id: businessId },
        select: { id: true },
      });
      if (!business) throw businessNotFound();
      throw forbiddenBusinessResource();
    }
    if (membership.status !== 'active') throw membershipInactive();
    if (permission && !permissionsOf(membership).includes(permission)) {
      throw permissionRequired(permission);
    }
    return membership;
  }
}
