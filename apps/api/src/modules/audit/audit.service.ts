import { Injectable } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma } from '../../generated/prisma/client';

export interface AuditRecordInput {
  actorUserId: string;
  actorRole?: string;
  businessId?: string;
  outletId?: string;
  action: string;
  resourceType: string;
  resourceId: string;
  beforeData?: Record<string, unknown>;
  afterData?: Record<string, unknown>;
  reason?: string;
  requestId?: string;
}

/**
 * Append-only audit trail (database-design §47). Callers pass the transaction
 * client when the audit row must commit with the business change.
 */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async record(
    input: AuditRecordInput,
    db: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<void> {
    await db.auditLog.create({
      data: {
        id: newId('adt'),
        actorUserId: input.actorUserId,
        actorType: 'user',
        actorRole: input.actorRole,
        businessId: input.businessId,
        outletId: input.outletId,
        action: input.action,
        resourceType: input.resourceType,
        resourceId: input.resourceId,
        beforeData: input.beforeData as Prisma.InputJsonValue | undefined,
        afterData: input.afterData as Prisma.InputJsonValue | undefined,
        reason: input.reason,
        requestId: input.requestId,
      },
    });
  }
}
