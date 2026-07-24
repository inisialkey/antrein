import { Injectable, Logger } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { clampLimit, decodeCursor, PageMeta, pageOf } from '../../common/pagination/cursor';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma } from '../../generated/prisma/client';
import { validationFailed } from '../auth/auth.errors';
import { businessNotFound } from '../memberships/membership.errors';
import { OWNER_PERMISSIONS } from '../memberships/permissions';
import { IdempotencyService } from '../idempotency/idempotency.service';
import {
  businessLimitReached,
  businessNotActive,
  paymentOptionNotSupported,
} from './business.errors';
import { toBusinessDetails, toBusinessSummary, toManagementResponse } from './business.mapper';
import {
  CreateBusinessDto,
  ListBusinessesQueryDto,
  PAYMENT_OPTION_LABELS,
  UpdateBusinessDto,
} from './dto/business.dto';
import { slugify, withSuffix } from './slug';

const businessWithRelations = { policy: true, outlets: { where: { status: 'active' } } } as const;

@Injectable()
export class BusinessesService {
  private readonly logger = new Logger(BusinessesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async create(
    userId: string,
    dto: CreateBusinessDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: 'business.create',
      key: idempotencyKey,
      payload: dto,
      resourceOf: (result) => ({ type: 'business', id: result.id as string }),
      run: async () => {
        const owned = await this.prisma.business.count({ where: { ownerUserId: userId } });
        if (owned > 0) throw businessLimitReached();

        const slug = await this.freeSlug(dto.name);
        const now = new Date();
        try {
          const { business, outlet } = await this.prisma.$transaction(async (tx) => {
            const business = await tx.business.create({
              data: {
                id: newId('biz'),
                ownerUserId: userId,
                name: dto.name.trim(),
                slug,
                description: dto.description ?? null,
                logoFileId: dto.logoFileId ?? null,
                // Self-serve businesses activate immediately (ADR 0021).
                status: 'active',
                timezone: dto.timezone ?? 'Asia/Jakarta',
                verifiedAt: now,
              },
            });
            await tx.businessPolicy.create({ data: { businessId: business.id } });
            const outlet = await tx.outlet.create({
              data: {
                id: newId('out'),
                businessId: business.id,
                name: dto.primaryOutlet.name.trim(),
                phoneNumber: dto.primaryOutlet.phoneNumber ?? null,
                timezone: dto.timezone ?? 'Asia/Jakarta',
                addressFormatted: dto.primaryOutlet.address.formatted,
                latitude: dto.primaryOutlet.address.latitude ?? null,
                longitude: dto.primaryOutlet.address.longitude ?? null,
              },
            });
            await tx.businessMembership.create({
              data: {
                id: newId('mem'),
                businessId: business.id,
                userId,
                role: 'owner',
                permissions: [...OWNER_PERMISSIONS],
                status: 'active',
                joinedAt: now,
              },
            });
            return { business, outlet };
          });

          this.logger.log(`business.created business=${business.id} owner=${userId}`);
          return {
            id: business.id,
            name: business.name,
            status: business.status,
            ownerUserId: userId,
            primaryOutlet: { id: outlet.id, name: outlet.name },
            createdAt: business.createdAt.toISOString(),
          };
        } catch (error) {
          // Slug was pre-checked, so a unique violation here is the
          // one-owned-business index racing a concurrent create (ADR 0026).
          if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
            throw businessLimitReached();
          }
          throw error;
        }
      },
    });
  }

  async listPublic(
    query: ListBusinessesQueryDto,
  ): Promise<{ items: unknown[]; pagination: PageMeta }> {
    const limit = clampLimit(query.limit);
    const sort = query.sort === 'name_asc' ? 'name_asc' : 'rating_desc'; // recommended == rating_desc in MVP

    const where: Prisma.BusinessWhereInput = { status: 'active' };
    if (query.q) where.name = { contains: query.q, mode: 'insensitive' };
    if (query.serviceId) {
      where.services = { some: { id: query.serviceId, status: 'active' } };
    }
    if (query.cursor) {
      const c = decodeCursor(query.cursor);
      const rating = c.rating ?? '0';
      // A syntactically valid cursor can still carry a non-numeric rating —
      // reject it here so Prisma's Decimal parser never turns it into a 500.
      if (sort !== 'name_asc' && Number.isNaN(Number(rating))) {
        throw validationFailed('Cursor is invalid.');
      }
      where.AND =
        sort === 'name_asc'
          ? [
              {
                OR: [
                  { name: { gt: c.name ?? '' } },
                  { name: c.name ?? '', id: { gt: c.id ?? '' } },
                ],
              },
            ]
          : [
              {
                OR: [
                  { ratingAverage: { lt: rating } },
                  { ratingAverage: rating, id: { gt: c.id ?? '' } },
                ],
              },
            ];
    }

    const rows = await this.prisma.business.findMany({
      where,
      include: businessWithRelations,
      orderBy:
        sort === 'name_asc'
          ? [{ name: 'asc' }, { id: 'asc' }]
          : [{ ratingAverage: 'desc' }, { id: 'asc' }],
      take: limit + 1,
    });

    const priceRanges = await this.prisma.service.groupBy({
      by: ['businessId'],
      where: { businessId: { in: rows.map((r) => r.id) }, status: 'active' },
      _min: { priceAmount: true },
      _max: { priceAmount: true },
    });
    const priceByBusiness = new Map(
      priceRanges.map((p) => [
        p.businessId,
        { minimum: p._min.priceAmount ?? 0, maximum: p._max.priceAmount ?? 0 },
      ]),
    );

    const cursorOf = (row: (typeof rows)[number]): Record<string, string> =>
      sort === 'name_asc'
        ? { name: row.name, id: row.id }
        : { rating: String(row.ratingAverage), id: row.id };
    const page = pageOf(rows, limit, cursorOf);
    return {
      items: page.items.map((row) => toBusinessSummary(row, priceByBusiness.get(row.id) ?? null)),
      pagination: page.pagination,
    };
  }

  async getPublicDetails(businessId: string): Promise<Record<string, unknown>> {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      include: businessWithRelations,
    });
    if (!business) throw businessNotFound();
    if (business.status !== 'active') throw businessNotActive();
    return toBusinessDetails(business);
  }

  async getManagement(businessId: string): Promise<Record<string, unknown>> {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      include: { policy: true },
    });
    if (!business) throw businessNotFound();
    return toManagementResponse(business);
  }

  async update(businessId: string, dto: UpdateBusinessDto): Promise<Record<string, unknown>> {
    for (const option of dto.supportedPaymentOptions ?? []) {
      if (!(PAYMENT_OPTION_LABELS as readonly string[]).includes(option)) {
        throw paymentOptionNotSupported(option);
      }
    }

    const policyData: Prisma.BusinessPolicyUpdateInput = {};
    if (dto.supportedPaymentOptions) {
      policyData.allowPayAtLocation = dto.supportedPaymentOptions.includes('pay_at_location');
      policyData.allowFullPayment = dto.supportedPaymentOptions.includes('full_payment');
      policyData.allowDeposit = dto.supportedPaymentOptions.includes('deposit');
    }
    if (dto.bookingPolicy) {
      const b = dto.bookingPolicy;
      if (b.minimumLeadMinutes !== undefined) policyData.minimumLeadMinutes = b.minimumLeadMinutes;
      if (b.maximumAdvanceDays !== undefined) policyData.maximumAdvanceDays = b.maximumAdvanceDays;
      if (b.automaticConfirmation !== undefined) {
        policyData.automaticConfirmation = b.automaticConfirmation;
      }
    }
    if (dto.depositPolicy) {
      policyData.allowDeposit = dto.depositPolicy.enabled;
      if (dto.depositPolicy.defaultType !== undefined) {
        policyData.defaultDepositType = dto.depositPolicy.defaultType;
      }
      if (dto.depositPolicy.defaultValue !== undefined) {
        policyData.defaultDepositValue = dto.depositPolicy.defaultValue;
      }
    }
    if (dto.cancellationPolicy) {
      const c = dto.cancellationPolicy;
      if (c.fullRefundBeforeMinutes !== undefined) {
        policyData.fullRefundBeforeMinutes = c.fullRefundBeforeMinutes;
      }
      if (c.partialRefundBeforeMinutes !== undefined) {
        policyData.partialRefundBeforeMinutes = c.partialRefundBeforeMinutes;
      }
      if (c.partialRefundPercentage !== undefined) {
        policyData.partialRefundPercentage = c.partialRefundPercentage;
      }
      if (c.noShowRefundPercentage !== undefined) {
        policyData.noShowRefundPercentage = c.noShowRefundPercentage;
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.business.update({
        where: { id: businessId },
        data: {
          ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
          ...(dto.description !== undefined ? { description: dto.description } : {}),
          ...(dto.logoFileId !== undefined ? { logoFileId: dto.logoFileId } : {}),
        },
      });
      if (Object.keys(policyData).length > 0) {
        await tx.businessPolicy.update({ where: { businessId }, data: policyData });
      }
    });

    return this.getManagement(businessId);
  }

  /** Deterministic collision-free slug: scan taken suffixes, pick the first gap. */
  private async freeSlug(name: string): Promise<string> {
    const base = slugify(name);
    const taken = new Set(
      (
        await this.prisma.business.findMany({
          where: { slug: { startsWith: base } },
          select: { slug: true },
        })
      ).map((b) => b.slug),
    );
    for (let attempt = 0; ; attempt += 1) {
      const candidate = withSuffix(base, attempt);
      if (!taken.has(candidate)) return candidate;
    }
  }
}
