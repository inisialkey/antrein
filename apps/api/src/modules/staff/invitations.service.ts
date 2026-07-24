import { createHash, randomBytes } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { EmailPort } from '../../infrastructure/email/email.port';
import { Prisma, StaffInvitation } from '../../generated/prisma/client';
import { validationFailed } from '../auth/auth.errors';
import { normalizeEmail } from '../auth/auth.policies';
import { AccessTokenPrincipal } from '../auth/token.service';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { isPermission, MembershipRole, ROLE_DEFAULT_PERMISSIONS } from '../memberships/permissions';
import { InviteStaffDto } from './dto/staff.dto';
import {
  outletNotInBusiness,
  serviceNotInBusiness,
  staffAlreadyMember,
  staffInvitationAlreadyPending,
  staffInvitationExpired,
  staffInvitationNotFound,
} from './staff.errors';

const INVITATION_TTL_DAYS = 7;

@Injectable()
export class InvitationsService {
  private readonly logger = new Logger(InvitationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly email: EmailPort,
  ) {}

  async invite(
    userId: string,
    businessId: string,
    dto: InviteStaffDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: `staff.invite:${businessId}`,
      key: idempotencyKey,
      payload: dto,
      resourceOf: (result) => ({ type: 'staff_invitation', id: result.invitationId as string }),
      run: async () => {
        const emailNormalized = normalizeEmail(dto.email);
        const permissions = this.resolvePermissions(dto.role, dto.permissions);
        const outletIds = [...new Set(dto.outletIds ?? [])];
        const serviceIds = [...new Set(dto.eligibleServiceIds ?? [])];
        await this.assertRefsInBusiness(businessId, outletIds, serviceIds);

        const invitee = await this.prisma.user.findUnique({
          where: { emailNormalized },
          select: { id: true },
        });
        if (invitee) {
          const membership = await this.prisma.businessMembership.findUnique({
            where: { businessId_userId: { businessId, userId: invitee.id } },
          });
          if (membership && membership.status !== 'inactive') throw staffAlreadyMember();
        }

        try {
          const invitation = await this.prisma.staffInvitation.create({
            data: {
              id: newId('inv'),
              businessId,
              emailNormalized,
              displayName: dto.displayName.trim(),
              role: dto.role,
              permissions,
              outletIds,
              eligibleServiceIds: serviceIds,
              tokenHash: createHash('sha256').update(randomBytes(32)).digest('hex'),
              invitedByUserId: userId,
              expiresAt: new Date(Date.now() + INVITATION_TTL_DAYS * 86_400_000),
            },
          });

          const business = await this.prisma.business.findUniqueOrThrow({
            where: { id: businessId },
            select: { name: true },
          });
          try {
            await this.email.sendStaffInvitation({
              to: dto.email.trim(),
              displayName: invitation.displayName,
              businessName: business.name,
              invitationId: invitation.id,
              expiresAt: invitation.expiresAt,
            });
          } catch (error) {
            // Invitation stands even if the email bounces; owner can re-share the id.
            this.logger.warn(`staff.invitation_email_failed invitation=${invitation.id}`, error);
          }

          return {
            invitationId: invitation.id,
            email: dto.email.trim(),
            status: invitation.status,
            expiresAt: invitation.expiresAt.toISOString(),
          };
        } catch (error) {
          if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
            throw staffInvitationAlreadyPending();
          }
          throw error;
        }
      },
    });
  }

  async accept(
    principal: AccessTokenPrincipal,
    invitationId: string,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: principal.userId,
      action: 'staff.invitation.accept',
      key: idempotencyKey,
      payload: { invitationId },
      run: async () => {
        const user = await this.prisma.user.findUniqueOrThrow({
          where: { id: principal.userId },
          select: { id: true, emailNormalized: true },
        });
        const invitation = await this.prisma.staffInvitation.findUnique({
          where: { id: invitationId },
        });
        // Wrong id, revoked, or someone else's invitation all read as not-found.
        if (
          !invitation ||
          invitation.status === 'revoked' ||
          invitation.emailNormalized !== user.emailNormalized
        ) {
          throw staffInvitationNotFound();
        }
        if (invitation.status === 'accepted') {
          return this.acceptedResponse(invitation);
        }
        if (invitation.status === 'expired' || invitation.expiresAt < new Date()) {
          throw staffInvitationExpired();
        }

        const existing = await this.prisma.businessMembership.findUnique({
          where: {
            businessId_userId: { businessId: invitation.businessId, userId: user.id },
          },
        });
        if (existing && existing.status !== 'inactive') throw staffAlreadyMember();

        const staffId = await this.prisma.$transaction(async (tx) => {
          const now = new Date();
          const membership = existing
            ? await tx.businessMembership.update({
                where: { id: existing.id },
                data: {
                  role: invitation.role,
                  permissions: invitation.permissions as Prisma.InputJsonValue,
                  status: 'active',
                  joinedAt: now,
                },
              })
            : await tx.businessMembership.create({
                data: {
                  id: newId('mem'),
                  businessId: invitation.businessId,
                  userId: user.id,
                  role: invitation.role,
                  permissions: invitation.permissions as Prisma.InputJsonValue,
                  status: 'active',
                  joinedAt: now,
                },
              });

          // A reactivated membership may already carry a profile.
          const priorProfile = await tx.staffProfile.findUnique({
            where: { membershipId: membership.id },
          });
          const profile = priorProfile
            ? await tx.staffProfile.update({
                where: { id: priorProfile.id },
                data: { displayName: invitation.displayName, status: 'active' },
              })
            : await tx.staffProfile.create({
                data: {
                  id: newId('stf'),
                  businessId: invitation.businessId,
                  membershipId: membership.id,
                  displayName: invitation.displayName,
                  staffType: invitation.role === 'barber' ? 'barber' : invitation.role,
                },
              });

          const outletIds = (invitation.outletIds as string[]) ?? [];
          await tx.staffOutlet.deleteMany({ where: { staffId: profile.id } });
          if (outletIds.length > 0) {
            await tx.staffOutlet.createMany({
              data: outletIds.map((outletId) => ({ staffId: profile.id, outletId })),
            });
          }
          const serviceIds = (invitation.eligibleServiceIds as string[]) ?? [];
          await tx.staffService.deleteMany({ where: { staffId: profile.id } });
          if (serviceIds.length > 0) {
            await tx.staffService.createMany({
              data: serviceIds.map((serviceId) => ({ staffId: profile.id, serviceId })),
            });
          }

          await tx.staffInvitation.update({
            where: { id: invitation.id },
            data: { status: 'accepted', acceptedAt: now, acceptedByUserId: user.id },
          });
          return profile.id;
        });

        this.logger.log(`staff.invitation_accepted invitation=${invitation.id} staff=${staffId}`);
        return {
          staffId,
          businessId: invitation.businessId,
          role: invitation.role,
          status: 'active',
        };
      },
    });
  }

  private async acceptedResponse(invitation: StaffInvitation): Promise<Record<string, unknown>> {
    const membership = await this.prisma.businessMembership.findUnique({
      where: {
        businessId_userId: {
          businessId: invitation.businessId,
          userId: invitation.acceptedByUserId ?? '',
        },
      },
      include: { staffProfile: { select: { id: true } } },
    });
    if (!membership?.staffProfile) throw staffInvitationNotFound();
    return {
      staffId: membership.staffProfile.id,
      businessId: invitation.businessId,
      role: membership.role,
      status: membership.status,
    };
  }

  private resolvePermissions(role: string, requested?: string[]): string[] {
    if (!requested) {
      return [...ROLE_DEFAULT_PERMISSIONS[role as Exclude<MembershipRole, 'owner'>]];
    }
    const invalid = requested.filter((p) => !isPermission(p));
    if (invalid.length > 0) {
      throw validationFailed(`Unknown permissions: ${invalid.join(', ')}`);
    }
    return [...new Set(requested)];
  }

  private async assertRefsInBusiness(
    businessId: string,
    outletIds: string[],
    serviceIds: string[],
  ): Promise<void> {
    if (outletIds.length > 0) {
      const outlets = await this.prisma.outlet.findMany({
        where: { id: { in: outletIds }, businessId },
        select: { id: true },
      });
      const known = new Set(outlets.map((o) => o.id));
      const foreign = outletIds.filter((id) => !known.has(id));
      if (foreign.length > 0) throw outletNotInBusiness(foreign);
    }
    if (serviceIds.length > 0) {
      const services = await this.prisma.service.findMany({
        where: { id: { in: serviceIds }, businessId },
        select: { id: true },
      });
      const known = new Set(services.map((s) => s.id));
      const foreign = serviceIds.filter((id) => !known.has(id));
      if (foreign.length > 0) throw serviceNotInBusiness(foreign);
    }
  }
}
