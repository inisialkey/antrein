import { Injectable } from '@nestjs/common';
import { clampLimit, decodeCursor, PageMeta, pageOf } from '../../common/pagination/cursor';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { BusinessMembership, Prisma, StaffProfile } from '../../generated/prisma/client';
import { validationFailed } from '../auth/auth.errors';
import { AuditService } from '../audit/audit.service';
import { businessNotActive } from '../businesses/business.errors';
import { businessNotFound } from '../memberships/membership.errors';
import { permissionsOf } from '../memberships/memberships.service';
import { isPermission } from '../memberships/permissions';
import { UpdateStaffDto } from './dto/staff.dto';
import { outletNotInBusiness, serviceNotInBusiness, staffNotFound } from './staff.errors';

type ProfileWithLinks = StaffProfile & {
  membership: BusinessMembership;
  serviceLinks: { serviceId: string }[];
  outletAssignments: { outletId: string }[];
};

function toStaffResponse(profile: ProfileWithLinks): Record<string, unknown> {
  return {
    id: profile.id,
    userId: profile.membership.userId,
    name: profile.displayName,
    avatarUrl: null, // files module pending
    role: profile.membership.role,
    isActive: profile.status === 'active',
    rating: { average: Number(profile.ratingAverage), count: profile.ratingCount },
    permissions: permissionsOf(profile.membership),
    outletIds: profile.outletAssignments.map((a) => a.outletId),
    eligibleServiceIds: profile.serviceLinks.map((l) => l.serviceId),
    updatedAt: profile.updatedAt.toISOString(),
  };
}

const profileInclude = {
  membership: true,
  serviceLinks: { select: { serviceId: true } },
  outletAssignments: { select: { outletId: true } },
} as const;

@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async listPublic(
    businessId: string,
    query: {
      outletId?: string;
      serviceId?: string;
      activeOnly?: string;
      cursor?: string;
      limit?: number;
    },
  ): Promise<{ items: unknown[]; pagination: PageMeta }> {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      select: { status: true },
    });
    if (!business) throw businessNotFound();
    if (business.status !== 'active') throw businessNotActive();

    const limit = clampLimit(query.limit);
    const where: Prisma.StaffProfileWhereInput = { businessId };
    if (query.activeOnly !== 'false') where.status = 'active';
    if (query.outletId) where.outletAssignments = { some: { outletId: query.outletId } };
    if (query.serviceId) where.serviceLinks = { some: { serviceId: query.serviceId } };
    if (query.cursor) {
      const c = decodeCursor(query.cursor);
      const createdAt = new Date(c.createdAt ?? 0);
      if (Number.isNaN(createdAt.getTime())) throw validationFailed('Cursor is invalid.');
      where.OR = [{ createdAt: { gt: createdAt } }, { createdAt, id: { gt: c.id ?? '' } }];
    }

    const rows = await this.prisma.staffProfile.findMany({
      where,
      include: profileInclude,
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: limit + 1,
    });

    const page = pageOf(rows, limit, (row) => ({
      createdAt: row.createdAt.toISOString(),
      id: row.id,
    }));
    // Public list omits management-only fields (permissions, outlet scope).
    return {
      items: page.items.map((row) => ({
        id: row.id,
        userId: row.membership.userId,
        name: row.displayName,
        avatarUrl: null,
        role: row.membership.role,
        isActive: row.status === 'active',
        rating: { average: Number(row.ratingAverage), count: row.ratingCount },
        eligibleServiceIds: row.serviceLinks.map((l) => l.serviceId),
      })),
      pagination: page.pagination,
    };
  }

  async update(
    actorUserId: string,
    businessId: string,
    staffId: string,
    dto: UpdateStaffDto,
    requestId?: string,
  ): Promise<Record<string, unknown>> {
    const profile = await this.prisma.staffProfile.findUnique({
      where: { id: staffId },
      include: profileInclude,
    });
    if (!profile || profile.businessId !== businessId) throw staffNotFound();
    if (profile.membership.role === 'owner') throw staffNotFound(); // owner is not managed staff

    const permissions = dto.permissions ? this.validatePermissions(dto.permissions) : undefined;
    if (dto.outletIds) await this.assertOutletsInBusiness(businessId, dto.outletIds);
    if (dto.eligibleServiceIds) {
      await this.assertServicesInBusiness(businessId, dto.eligibleServiceIds);
    }

    const before = {
      role: profile.membership.role,
      permissions: permissionsOf(profile.membership),
    };

    await this.prisma.$transaction(async (tx) => {
      await tx.staffProfile.update({
        where: { id: staffId },
        data: {
          ...(dto.displayName !== undefined ? { displayName: dto.displayName.trim() } : {}),
          ...(dto.avatarFileId !== undefined ? { avatarFileId: dto.avatarFileId } : {}),
          ...(dto.isActive !== undefined ? { status: dto.isActive ? 'active' : 'inactive' } : {}),
        },
      });
      if (dto.role !== undefined || permissions !== undefined || dto.isActive !== undefined) {
        await tx.businessMembership.update({
          where: { id: profile.membershipId },
          data: {
            ...(dto.role !== undefined ? { role: dto.role } : {}),
            ...(permissions !== undefined
              ? { permissions: permissions as Prisma.InputJsonValue }
              : {}),
            ...(dto.isActive !== undefined ? { status: dto.isActive ? 'active' : 'inactive' } : {}),
          },
        });
      }
      if (dto.outletIds) {
        await tx.staffOutlet.deleteMany({ where: { staffId } });
        if (dto.outletIds.length > 0) {
          await tx.staffOutlet.createMany({
            data: [...new Set(dto.outletIds)].map((outletId) => ({ staffId, outletId })),
          });
        }
      }
      if (dto.eligibleServiceIds) {
        await tx.staffService.deleteMany({ where: { staffId } });
        if (dto.eligibleServiceIds.length > 0) {
          await tx.staffService.createMany({
            data: [...new Set(dto.eligibleServiceIds)].map((serviceId) => ({
              staffId,
              serviceId,
            })),
          });
        }
      }
      // Permission/role changes are audited (product invariant).
      if (dto.role !== undefined || permissions !== undefined) {
        await this.audit.record(
          {
            actorUserId,
            businessId,
            action: 'staff.permissions_changed',
            resourceType: 'staff_profile',
            resourceId: staffId,
            beforeData: before,
            afterData: {
              role: dto.role ?? before.role,
              permissions: permissions ?? before.permissions,
            },
            requestId,
          },
          tx,
        );
      }
    });

    const updated = await this.prisma.staffProfile.findUniqueOrThrow({
      where: { id: staffId },
      include: profileInclude,
    });
    return toStaffResponse(updated);
  }

  async deactivate(businessId: string, staffId: string): Promise<Record<string, unknown>> {
    const profile = await this.prisma.staffProfile.findUnique({
      where: { id: staffId },
      include: { membership: true },
    });
    if (!profile || profile.businessId !== businessId) throw staffNotFound();
    if (profile.membership.role === 'owner') throw staffNotFound();

    // ponytail: STAFF_HAS_ACTIVE_BOOKINGS gate (ADR 0036) lands with the
    // bookings module — no bookings table exists yet, so nothing can block.
    const updated = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.staffProfile.update({
        where: { id: staffId },
        data: { status: 'inactive' },
      });
      await tx.businessMembership.update({
        where: { id: profile.membershipId },
        data: { status: 'inactive' },
      });
      return updated;
    });
    return {
      id: updated.id,
      status: updated.status,
      deactivatedAt: updated.updatedAt.toISOString(),
    };
  }

  private validatePermissions(requested: string[]): string[] {
    const invalid = requested.filter((p) => !isPermission(p));
    if (invalid.length > 0) throw validationFailed(`Unknown permissions: ${invalid.join(', ')}`);
    return [...new Set(requested)];
  }

  private async assertOutletsInBusiness(businessId: string, outletIds: string[]): Promise<void> {
    const unique = [...new Set(outletIds)];
    if (unique.length === 0) return;
    const outlets = await this.prisma.outlet.findMany({
      where: { id: { in: unique }, businessId },
      select: { id: true },
    });
    const known = new Set(outlets.map((o) => o.id));
    const foreign = unique.filter((id) => !known.has(id));
    if (foreign.length > 0) throw outletNotInBusiness(foreign);
  }

  private async assertServicesInBusiness(businessId: string, serviceIds: string[]): Promise<void> {
    const unique = [...new Set(serviceIds)];
    if (unique.length === 0) return;
    const services = await this.prisma.service.findMany({
      where: { id: { in: unique }, businessId },
      select: { id: true },
    });
    const known = new Set(services.map((s) => s.id));
    const foreign = unique.filter((id) => !known.has(id));
    if (foreign.length > 0) throw serviceNotInBusiness(foreign);
  }
}
