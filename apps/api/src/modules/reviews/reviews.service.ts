import { Injectable } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { clampLimit, decodeCursor, pageOf, PageMeta } from '../../common/pagination/cursor';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma, Review } from '../../generated/prisma/client';
import { validationFailed } from '../auth/auth.errors';
import { bookingNotFound } from '../bookings/booking.errors';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { businessNotFound } from '../memberships/membership.errors';
import { CreateReviewDto, ListReviewsQueryDto, ReviewSort } from './dto/review.dto';
import {
  reviewAlreadyExists,
  reviewBookingNotCompleted,
  reviewNotAllowed,
  reviewRatingInvalid,
} from './review.errors';

const SORT_ORDER: Record<ReviewSort, Prisma.ReviewOrderByWithRelationInput[]> = {
  newest: [{ createdAt: 'desc' }, { id: 'desc' }],
  oldest: [{ createdAt: 'asc' }, { id: 'asc' }],
  rating_desc: [{ rating: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }],
  rating_asc: [{ rating: 'asc' }, { createdAt: 'desc' }, { id: 'desc' }],
};

@Injectable()
export class ReviewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async createReview(
    userId: string,
    bookingId: string,
    dto: CreateReviewDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: 'review.create',
      key: idempotencyKey,
      payload: dto,
      resourceOf: (result) => ({ type: 'review', id: result.id as string }),
      run: () => this.createReviewRun(userId, bookingId, dto),
    });
  }

  private async createReviewRun(
    userId: string,
    bookingId: string,
    dto: CreateReviewDto,
  ): Promise<Record<string, unknown>> {
    if (!Number.isInteger(dto.rating) || dto.rating < 1 || dto.rating > 5) {
      throw reviewRatingInvalid();
    }

    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { id: true, customerUserId: true, businessId: true, staffId: true, status: true },
    });
    if (!booking) throw bookingNotFound();
    if (!booking.customerUserId || booking.customerUserId !== userId) throw reviewNotAllowed();
    if (booking.status !== 'completed') throw reviewBookingNotCompleted();

    const existing = await this.prisma.review.findUnique({ where: { bookingId } });
    if (existing) throw reviewAlreadyExists();

    try {
      const review = await this.prisma.$transaction(async (tx) => {
        // ADR 0038: rating aggregates are stored and updated inside the review
        // transaction. The business row lock serializes concurrent recomputes
        // (a staff belongs to one business, so it also covers the staff row).
        await tx.$queryRaw`SELECT id FROM businesses WHERE id = ${booking.businessId} FOR UPDATE`;

        const created = await tx.review.create({
          data: {
            id: newId('rev'),
            bookingId,
            businessId: booking.businessId,
            customerUserId: userId,
            staffId: booking.staffId,
            rating: dto.rating,
            comment: dto.comment ?? null,
            status: 'published',
          },
        });

        await this.recomputeBusinessAggregate(tx, booking.businessId);
        if (booking.staffId) await this.recomputeStaffAggregate(tx, booking.staffId);
        return created;
      });
      return toReviewResponse(review);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw reviewAlreadyExists();
      }
      throw e;
    }
  }

  private async recomputeBusinessAggregate(
    tx: Prisma.TransactionClient,
    businessId: string,
  ): Promise<void> {
    const [agg] = await tx.$queryRaw<Array<{ count: number; avg: number }>>`
      SELECT count(*)::int AS count, COALESCE(ROUND(AVG(rating), 2), 0)::float AS avg
      FROM reviews WHERE business_id = ${businessId} AND status = 'published'`;
    await tx.business.update({
      where: { id: businessId },
      data: { ratingAverage: agg.avg, ratingCount: agg.count },
    });
  }

  private async recomputeStaffAggregate(
    tx: Prisma.TransactionClient,
    staffId: string,
  ): Promise<void> {
    const [agg] = await tx.$queryRaw<Array<{ count: number; avg: number }>>`
      SELECT count(*)::int AS count, COALESCE(ROUND(AVG(rating), 2), 0)::float AS avg
      FROM reviews WHERE staff_id = ${staffId} AND status = 'published'`;
    await tx.staffProfile.update({
      where: { id: staffId },
      data: { ratingAverage: agg.avg, ratingCount: agg.count },
    });
  }

  /** Public reviews list + live summary (§97). Published reviews only. */
  async listBusinessReviews(
    businessId: string,
    query: ListReviewsQueryDto,
  ): Promise<{ summary: unknown; items: unknown[]; pagination: PageMeta }> {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      select: { id: true },
    });
    if (!business) throw businessNotFound();

    const published = { businessId, status: 'published' } as const;

    const grouped = await this.prisma.review.groupBy({
      by: ['rating'],
      where: published,
      _count: true,
    });
    const distribution: Record<string, number> = { '5': 0, '4': 0, '3': 0, '2': 0, '1': 0 };
    let count = 0;
    let sum = 0;
    for (const g of grouped) {
      distribution[String(g.rating)] = g._count;
      count += g._count;
      sum += g.rating * g._count;
    }
    const summary = {
      average: count === 0 ? 0 : Math.round((sum / count) * 10) / 10,
      count,
      distribution,
    };

    const limit = clampLimit(query.limit);
    const cursorId = query.cursor ? decodeCursor(query.cursor).id : undefined;
    if (query.cursor && !cursorId) throw validationFailed('Cursor is invalid.');
    const rows = await this.prisma.review.findMany({
      where: { ...published, ...(query.rating !== undefined ? { rating: query.rating } : {}) },
      orderBy: SORT_ORDER[query.sort ?? 'newest'],
      take: limit + 1,
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
      include: { customer: { select: { name: true } } },
    });

    const { items, pagination } = pageOf(rows, limit, (row) => ({ id: row.id }));
    return {
      summary,
      items: items.map((row) => ({
        id: row.id,
        customer: { displayName: row.customer.name },
        rating: row.rating,
        comment: row.comment,
        createdAt: row.createdAt.toISOString(),
      })),
      pagination,
    };
  }
}

function toReviewResponse(review: Review): Record<string, unknown> {
  return {
    id: review.id,
    bookingId: review.bookingId,
    businessId: review.businessId,
    rating: review.rating,
    comment: review.comment,
    status: review.status,
    createdAt: review.createdAt.toISOString(),
  };
}
