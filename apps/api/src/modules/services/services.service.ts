import { Injectable } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { clampLimit, decodeCursor, PageMeta, pageOf } from '../../common/pagination/cursor';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma, Service } from '../../generated/prisma/client';
import { validationFailed } from '../auth/auth.errors';
import { businessNotActive } from '../businesses/business.errors';
import { idr } from '../businesses/business.mapper';
import { businessNotFound } from '../memberships/membership.errors';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { CreateServiceDto, ListServicesQueryDto, UpdateServiceDto } from './dto/service.dto';
import {
  serviceInvalidDeposit,
  serviceInvalidDuration,
  serviceInvalidPrice,
  serviceNameAlreadyExists,
  serviceNotFound,
  staffNotFound,
  staffNotInBusiness,
} from './service.errors';

const MAX_DURATION_MINUTES = 600;

export function normalizeServiceName(name: string): string {
  return name.trim().toLowerCase().replace(/\s+/g, ' ');
}

export function toServiceResponse(
  service: Service,
  eligibleStaffIds: string[],
): Record<string, unknown> {
  return {
    id: service.id,
    businessId: service.businessId,
    name: service.name,
    description: service.description,
    imageUrl: null, // files module pending
    durationMinutes: service.durationMinutes,
    price: idr(service.priceAmount),
    deposit:
      service.depositType === 'none'
        ? null
        : {
            type: service.depositType,
            value: service.depositValue,
            requiredAmount: idr(service.depositValue),
          },
    eligibleStaffIds,
    isActive: service.status === 'active',
    createdAt: service.createdAt.toISOString(),
  };
}

@Injectable()
export class ServicesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async create(
    userId: string,
    businessId: string,
    dto: CreateServiceDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: `service.create:${businessId}`,
      key: idempotencyKey,
      payload: dto,
      resourceOf: (result) => ({ type: 'service', id: result.id as string }),
      run: async () => {
        this.validateDomain(dto.durationMinutes, dto.price, dto.deposit);
        const staffIds = [...new Set(dto.eligibleStaffIds ?? [])];
        await this.assertStaffInBusiness(businessId, staffIds);

        try {
          const service = await this.prisma.$transaction(async (tx) => {
            const last = await tx.service.findFirst({
              where: { businessId },
              orderBy: { sortOrder: 'desc' },
              select: { sortOrder: true },
            });
            const service = await tx.service.create({
              data: {
                id: newId('svc'),
                businessId,
                name: dto.name.trim(),
                nameNormalized: normalizeServiceName(dto.name),
                description: dto.description ?? null,
                imageFileId: dto.imageFileId ?? null,
                durationMinutes: dto.durationMinutes,
                priceAmount: dto.price.amount,
                depositType: dto.deposit?.type ?? 'none',
                depositValue: dto.deposit?.value ?? 0,
                status: (dto.isActive ?? true) ? 'active' : 'inactive',
                sortOrder: (last?.sortOrder ?? -1) + 1,
              },
            });
            if (staffIds.length > 0) {
              await tx.staffService.createMany({
                data: staffIds.map((staffId) => ({ staffId, serviceId: service.id })),
              });
            }
            return service;
          });
          return toServiceResponse(service, staffIds);
        } catch (error) {
          if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
            throw serviceNameAlreadyExists();
          }
          throw error;
        }
      },
    });
  }

  async update(
    businessId: string,
    serviceId: string,
    dto: UpdateServiceDto,
  ): Promise<Record<string, unknown>> {
    const existing = await this.prisma.service.findUnique({ where: { id: serviceId } });
    if (!existing || existing.businessId !== businessId) throw serviceNotFound();

    this.validateDomain(
      dto.durationMinutes ?? existing.durationMinutes,
      dto.price ?? { amount: existing.priceAmount, currency: existing.currency },
      dto.deposit,
    );
    const staffIds =
      dto.eligibleStaffIds !== undefined ? [...new Set(dto.eligibleStaffIds)] : undefined;
    if (staffIds) await this.assertStaffInBusiness(businessId, staffIds);

    try {
      const service = await this.prisma.$transaction(async (tx) => {
        const service = await tx.service.update({
          where: { id: serviceId },
          data: {
            ...(dto.name !== undefined
              ? { name: dto.name.trim(), nameNormalized: normalizeServiceName(dto.name) }
              : {}),
            ...(dto.description !== undefined ? { description: dto.description } : {}),
            ...(dto.imageFileId !== undefined ? { imageFileId: dto.imageFileId } : {}),
            ...(dto.durationMinutes !== undefined ? { durationMinutes: dto.durationMinutes } : {}),
            ...(dto.price !== undefined ? { priceAmount: dto.price.amount } : {}),
            ...(dto.deposit !== undefined
              ? { depositType: dto.deposit.type, depositValue: dto.deposit.value }
              : {}),
            ...(dto.isActive !== undefined ? { status: dto.isActive ? 'active' : 'inactive' } : {}),
          },
        });
        if (staffIds) {
          await tx.staffService.deleteMany({ where: { serviceId } });
          if (staffIds.length > 0) {
            await tx.staffService.createMany({
              data: staffIds.map((staffId) => ({ staffId, serviceId })),
            });
          }
        }
        return service;
      });
      return toServiceResponse(service, staffIds ?? (await this.eligibleStaffIdsOf(serviceId)));
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw serviceNameAlreadyExists();
      }
      throw error;
    }
  }

  async deactivate(businessId: string, serviceId: string): Promise<Record<string, unknown>> {
    const existing = await this.prisma.service.findUnique({ where: { id: serviceId } });
    if (!existing || existing.businessId !== businessId) throw serviceNotFound();

    // Deactivate, never delete — booking snapshots reference history.
    const service = await this.prisma.service.update({
      where: { id: serviceId },
      data: { status: 'inactive' },
    });
    return {
      id: service.id,
      isActive: false,
      deactivatedAt: service.updatedAt.toISOString(),
    };
  }

  async listPublic(
    businessId: string,
    query: ListServicesQueryDto,
  ): Promise<{ items: unknown[]; pagination: PageMeta }> {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      select: { status: true },
    });
    if (!business) throw businessNotFound();
    if (business.status !== 'active') throw businessNotActive();

    const limit = clampLimit(query.limit);
    const where: Prisma.ServiceWhereInput = { businessId };
    where.status = query.activeOnly === 'false' ? { not: 'archived' } : 'active';
    if (query.staffId) where.staffLinks = { some: { staffId: query.staffId } };
    if (query.cursor) {
      const c = decodeCursor(query.cursor);
      const sortOrder = Number(c.sortOrder ?? '0');
      if (!Number.isInteger(sortOrder)) throw validationFailed('Cursor is invalid.');
      where.OR = [{ sortOrder: { gt: sortOrder } }, { sortOrder, id: { gt: c.id ?? '' } }];
    }

    const rows = await this.prisma.service.findMany({
      where,
      include: { staffLinks: { select: { staffId: true } } },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      take: limit + 1,
    });

    const page = pageOf(rows, limit, (row) => ({
      sortOrder: String(row.sortOrder),
      id: row.id,
    }));
    return {
      items: page.items.map((row) =>
        toServiceResponse(
          row,
          row.staffLinks.map((l) => l.staffId),
        ),
      ),
      pagination: page.pagination,
    };
  }

  private async eligibleStaffIdsOf(serviceId: string): Promise<string[]> {
    const links = await this.prisma.staffService.findMany({
      where: { serviceId },
      select: { staffId: true },
    });
    return links.map((l) => l.staffId);
  }

  private validateDomain(
    durationMinutes: number,
    price: { amount: number; currency: string },
    deposit?: { type: string; value: number },
  ): void {
    if (
      !Number.isInteger(durationMinutes) ||
      durationMinutes <= 0 ||
      durationMinutes > MAX_DURATION_MINUTES
    ) {
      throw serviceInvalidDuration();
    }
    if (price.amount < 0 || price.currency !== 'IDR') throw serviceInvalidPrice();
    if (!deposit || deposit.type === 'none') return;
    // Fixed-only deposits in MVP (ADR 0022).
    if (deposit.type !== 'fixed') {
      throw serviceInvalidDeposit('Only fixed deposits are supported.');
    }
    if (deposit.value <= 0 || deposit.value > price.amount) {
      throw serviceInvalidDeposit('Deposit must be positive and not exceed the service price.');
    }
  }

  private async assertStaffInBusiness(businessId: string, staffIds: string[]): Promise<void> {
    if (staffIds.length === 0) return;
    const profiles = await this.prisma.staffProfile.findMany({
      where: { id: { in: staffIds } },
      select: { id: true, businessId: true },
    });
    const found = new Map(profiles.map((p) => [p.id, p.businessId]));
    const missing = staffIds.filter((id) => !found.has(id));
    if (missing.length > 0) throw staffNotFound(missing);
    const foreign = staffIds.filter((id) => found.get(id) !== businessId);
    if (foreign.length > 0) throw staffNotInBusiness(foreign);
  }
}
