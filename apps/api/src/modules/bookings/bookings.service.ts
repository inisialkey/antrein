import { Injectable } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { clampLimit, decodeCursor, pageOf } from '../../common/pagination/cursor';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { validationFailed } from '../auth/auth.errors';
import { businessNotActive, outletNotFound } from '../businesses/business.errors';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { businessNotFound } from '../memberships/membership.errors';
import { MembershipsService } from '../memberships/memberships.service';
import { staffNotEligibleForService } from '../schedules/schedule.errors';
import { staffAvailabilityRangesOf } from '../schedules/schedules.service';
import {
  JAKARTA_UTC_OFFSET_MINUTES,
  MinuteRange,
  addDays,
  dbTimeToString,
  jakartaDateString,
  jakartaDayOfWeek,
  toMinutes,
} from '../schedules/slots';
import { serviceNotFound } from '../services/service.errors';
import { staffNotFound } from '../staff/staff.errors';
import {
  bookingActiveLimitReached,
  bookingAlreadyCancelled,
  bookingAlreadyCompleted,
  bookingCannotBeCancelled,
  bookingDateInPast,
  bookingHorizonExceeded,
  bookingLeadTimeNotMet,
  bookingNotFound,
  bookingSlotUnavailable,
  forbiddenBookingResource,
  outletNotActive,
  paymentOptionNotAvailable,
  paymentProviderUnavailable,
  serviceNotActive,
  staffNotActive,
} from './booking.errors';
import {
  BookingWithRelations,
  bookingInclude,
  netOnlinePaidOf,
  toBookingResource,
} from './booking.mapper';
import { formatBookingCode } from './domain/booking-code';
import {
  BLOCKING_BOOKING_STATUSES,
  BookingStatus,
  assertBookingTransition,
} from './domain/booking-status.policy';
import { CancellationPolicySnapshot, refundAmountFor } from './domain/cancellation-policy';
import {
  BusinessCancelBookingDto,
  CancelBookingDto,
  CreateBookingDto,
  ListBusinessBookingsQueryDto,
  ListCustomerBookingsQueryDto,
} from './dto/booking.dto';

// ponytail: ADR 0034 default; becomes a business_policies column if it ever
// needs to vary per business.
const MAX_ACTIVE_BOOKINGS = 3;
const CUSTOMER_CANCELLABLE: BookingStatus[] = ['pending_payment', 'confirmed'];

const dateToDb = (date: string): Date => new Date(`${date}T00:00:00Z`);

const jakartaMinutesOfDay = (instant: Date): number => {
  const shifted = new Date(instant.getTime() + JAKARTA_UTC_OFFSET_MINUTES * 60_000);
  return shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
};

const insideOne = (ranges: MinuteRange[], start: number, end: number): boolean =>
  ranges.some((r) => r.start <= start && end <= r.end);

function isExclusionViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2010' &&
    (String((error.meta as { code?: unknown } | undefined)?.code) === '23P01' ||
      error.message.includes('booking_reservations_no_overlap'))
  );
}

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly memberships: MembershipsService,
    private readonly audit: AuditService,
  ) {}

  async createBooking(
    userId: string,
    dto: CreateBookingDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: 'booking.create',
      key: idempotencyKey,
      payload: dto,
      resourceOf: (result) => ({
        type: 'booking',
        id: (result.booking as { id: string }).id,
      }),
      run: () => this.createBookingRun(userId, dto),
    });
  }

  private async createBookingRun(
    userId: string,
    dto: CreateBookingDto,
  ): Promise<Record<string, unknown>> {
    const now = new Date();

    const business = await this.prisma.business.findUnique({
      where: { id: dto.businessId },
      include: { policy: true },
    });
    if (!business) throw businessNotFound();
    if (business.status !== 'active') throw businessNotActive();
    const policy = business.policy;

    const outlet = await this.prisma.outlet.findUnique({ where: { id: dto.outletId } });
    if (!outlet || outlet.businessId !== business.id) throw outletNotFound();
    if (outlet.status !== 'active') throw outletNotActive();

    const service = await this.prisma.service.findUnique({
      where: { id: dto.serviceId },
      include: { staffLinks: { select: { staffId: true } } },
    });
    if (!service || service.businessId !== business.id) throw serviceNotFound();
    if (service.status !== 'active') throw serviceNotActive();

    if (dto.paymentOption === 'pay_at_location') {
      if (policy && !policy.allowPayAtLocation) throw paymentOptionNotAvailable();
    } else {
      const enabled =
        dto.paymentOption === 'full_payment' ? policy?.allowFullPayment : policy?.allowDeposit;
      if (!enabled) throw paymentOptionNotAvailable();
      // ponytail: online payments land with the provider milestone (M7); until
      // then an enabled online option has no provider to charge through.
      throw paymentProviderUnavailable();
    }

    // ADR 0019: any_available staff selection is out of MVP scope.
    if (dto.staffSelection.mode !== 'specific_staff' || !dto.staffSelection.staffId) {
      throw validationFailed(
        'staffSelection.staffId is required; any_available selection is not supported yet.',
      );
    }
    const staff = await this.prisma.staffProfile.findUnique({
      where: { id: dto.staffSelection.staffId },
      include: {
        outletAssignments: { select: { outletId: true } },
        schedules: { include: { breaks: true } },
      },
    });
    if (!staff || staff.businessId !== business.id) throw staffNotFound();
    if (staff.status !== 'active') throw staffNotActive();
    if (service.staffLinks.length > 0 && !service.staffLinks.some((l) => l.staffId === staff.id)) {
      throw staffNotEligibleForService();
    }

    const parsed = Date.parse(dto.scheduledAt);
    if (Number.isNaN(parsed)) throw validationFailed('scheduledAt is not a valid timestamp.');
    const scheduledAt = new Date(Math.floor(parsed / 60_000) * 60_000);
    const expectedEndsAt = new Date(scheduledAt.getTime() + service.durationMinutes * 60_000);

    if (scheduledAt <= now) throw bookingDateInPast();
    const minimumLeadMinutes = policy?.minimumLeadMinutes ?? 60;
    if (scheduledAt.getTime() < now.getTime() + minimumLeadMinutes * 60_000) {
      throw bookingLeadTimeNotMet(minimumLeadMinutes);
    }
    const businessDate = jakartaDateString(scheduledAt);
    const maximumAdvanceDays = policy?.maximumAdvanceDays ?? 30;
    if (businessDate > addDays(jakartaDateString(now), maximumAdvanceDays)) {
      throw bookingHorizonExceeded(maximumAdvanceDays);
    }

    await this.assertSlotWithinSchedules(
      outlet.id,
      staff,
      businessDate,
      scheduledAt,
      expectedEndsAt,
    );

    const cancellationPolicy: CancellationPolicySnapshot = {
      fullRefundBeforeMinutes: policy?.fullRefundBeforeMinutes ?? 360,
      partialRefundBeforeMinutes: policy?.partialRefundBeforeMinutes ?? 120,
      partialRefundPercentage: policy?.partialRefundPercentage ?? 50,
      noShowRefundPercentage: policy?.noShowRefundPercentage ?? 0,
    };

    const bookingId = newId('bkg');
    try {
      await this.prisma.$transaction(async (tx) => {
        // Serializes same-customer creates for this business so the active-limit
        // count below cannot race (plain count is read-then-write otherwise).
        await tx.$executeRaw`
          SELECT pg_advisory_xact_lock(hashtextextended(${`${userId}:${business.id}`}, 0))`;
        const activeCount = await tx.booking.count({
          where: {
            customerUserId: userId,
            businessId: business.id,
            status: { in: [...BLOCKING_BOOKING_STATUSES] },
          },
        });
        if (activeCount >= MAX_ACTIVE_BOOKINGS) {
          throw bookingActiveLimitReached(MAX_ACTIVE_BOOKINGS);
        }

        const counter = await tx.$queryRaw<Array<{ last_number: number }>>`
          INSERT INTO booking_code_counters (business_id, business_date, last_number)
          VALUES (${business.id}, ${dateToDb(businessDate)}::date, 1)
          ON CONFLICT (business_id, business_date)
          DO UPDATE SET last_number = booking_code_counters.last_number + 1
          RETURNING last_number`;
        const bookingCode = formatBookingCode(businessDate, counter[0].last_number);

        await tx.booking.create({
          data: {
            id: bookingId,
            bookingCode,
            customerUserId: userId,
            businessId: business.id,
            outletId: outlet.id,
            serviceId: service.id,
            staffId: staff.id,
            bookingType: 'scheduled',
            // ADR 0015: pay-at-location bookings confirm immediately.
            status: 'confirmed',
            scheduledAt,
            expectedEndsAt,
            customerNotes: dto.customerNotes ?? null,
            paymentOption: dto.paymentOption,
            businessDate: dateToDb(businessDate),
            createdByUserId: userId,
          },
        });
        await tx.bookingSnapshot.create({
          data: {
            bookingId,
            businessName: business.name,
            outletName: outlet.name,
            outletAddressFormatted: outlet.addressFormatted,
            outletTimezone: outlet.timezone,
            serviceName: service.name,
            serviceDurationMinutes: service.durationMinutes,
            servicePriceAmount: service.priceAmount,
            currency: 'IDR',
            depositType: service.depositType,
            depositValue: service.depositValue,
            requiredPaymentAmount: 0,
            staffName: staff.displayName,
            cancellationPolicy: cancellationPolicy as unknown as Prisma.InputJsonValue,
          },
        });
        await tx.bookingStatusHistory.create({
          data: {
            id: newId('bsh'),
            bookingId,
            fromStatus: null,
            toStatus: 'confirmed',
            actorUserId: userId,
            actorType: 'customer',
          },
        });
        // GiST exclusion constraint (ADR 0027) is the final overlap authority.
        await tx.$executeRaw`
          INSERT INTO booking_reservations (booking_id, staff_id, outlet_id, schedule_range)
          VALUES (${bookingId}, ${staff.id}, ${outlet.id},
                  tstzrange(${scheduledAt}, ${expectedEndsAt}, '[)'))`;
        await tx.payment.create({
          data: {
            id: newId('pay'),
            bookingId,
            businessId: business.id,
            customerUserId: userId,
            provider: 'pay_at_location',
            paymentOption: dto.paymentOption,
            status: 'pending',
            amount: service.priceAmount,
          },
        });
        // ponytail: booking.created outbox event lands with the realtime
        // milestone — there is no outbox_events table yet.
      });
    } catch (error) {
      if (isExclusionViolation(error)) throw bookingSlotUnavailable();
      throw error;
    }

    const booking = await this.requireBooking(bookingId);
    return { booking: toBookingResource(booking), payment: null };
  }

  /** Revalidates outlet hours, closed dates and the staff schedule (§12 steps 14–17). */
  private async assertSlotWithinSchedules(
    outletId: string,
    staff: Parameters<typeof staffAvailabilityRangesOf>[0],
    businessDate: string,
    scheduledAt: Date,
    expectedEndsAt: Date,
  ): Promise<void> {
    const closed = await this.prisma.closedDate.findUnique({
      where: { outletId_closedDate: { outletId, closedDate: dateToDb(businessDate) } },
    });
    if (closed) throw bookingSlotUnavailable();

    const day = jakartaDayOfWeek(businessDate);
    const hourRows = await this.prisma.outletOperatingHour.findMany({
      where: { outletId, dayOfWeek: day },
    });
    const outletPeriods: MinuteRange[] = hourRows
      .filter((r) => !r.isClosed && r.opensAt && r.closesAt)
      .map((r) => ({
        start: toMinutes(dbTimeToString(r.opensAt as Date)),
        end: toMinutes(dbTimeToString(r.closesAt as Date)),
      }));

    const startMinutes = jakartaMinutesOfDay(scheduledAt);
    const endMinutes = startMinutes + (expectedEndsAt.getTime() - scheduledAt.getTime()) / 60_000;
    const staffRanges = staffAvailabilityRangesOf(staff, outletId, day, outletPeriods);
    if (!insideOne(outletPeriods, startMinutes, endMinutes)) throw bookingSlotUnavailable();
    if (!insideOne(staffRanges, startMinutes, endMinutes)) throw bookingSlotUnavailable();
  }

  async getCustomerBooking(userId: string, bookingId: string): Promise<Record<string, unknown>> {
    const booking = await this.requireBooking(bookingId);
    if (booking.customerUserId !== userId) throw forbiddenBookingResource();
    return toBookingResource(booking);
  }

  async listCustomerBookings(
    userId: string,
    query: ListCustomerBookingsQueryDto,
  ): Promise<Record<string, unknown>> {
    const where: Prisma.BookingWhereInput = { customerUserId: userId };
    this.applyListFilters(where, query);
    return this.listPage(where, query);
  }

  async listBusinessBookings(
    businessId: string,
    query: ListBusinessBookingsQueryDto,
  ): Promise<Record<string, unknown>> {
    const where: Prisma.BookingWhereInput = { businessId };
    if (query.outletId) where.outletId = query.outletId;
    if (query.staffId) where.staffId = query.staffId;
    if (query.type) where.bookingType = query.type;
    if (query.date) where.businessDate = dateToDb(query.date);
    if (query.paymentStatus) where.payments = { some: { status: query.paymentStatus } };
    this.applyListFilters(where, query);
    return this.listPage(where, query, { businessView: true });
  }

  async getBusinessBooking(
    businessId: string,
    bookingId: string,
  ): Promise<Record<string, unknown>> {
    const booking = await this.requireBooking(bookingId);
    if (booking.businessId !== businessId) throw bookingNotFound();
    return toBookingResource(booking, { businessView: true });
  }

  async cancelCustomerBooking(
    userId: string,
    bookingId: string,
    dto: CancelBookingDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: `booking.cancel:${bookingId}`,
      key: idempotencyKey,
      payload: dto,
      run: async () => {
        const booking = await this.requireBooking(bookingId);
        if (booking.customerUserId !== userId) throw forbiddenBookingResource();
        this.assertCancellable(booking);

        const now = new Date();
        const policy = booking.snapshot?.cancellationPolicy as unknown as
          CancellationPolicySnapshot | undefined;
        const refundAmount =
          policy && booking.scheduledAt
            ? refundAmountFor(policy, booking.scheduledAt, now, netOnlinePaidOf(booking))
            : 0;

        await this.cancelTransaction(booking, {
          actorUserId: userId,
          actorType: 'customer',
          reasonCode: dto.reasonCode ?? null,
          reason: dto.reason ?? null,
          cancelledAt: now,
        });
        // ponytail: refundAmount is always 0 until online payments exist (ADR
        // 0018 — only online net paid refunds); the refunds table lands in M7.
        return {
          bookingId: booking.id,
          status: 'cancelled',
          cancelledAt: now.toISOString(),
          refund: { required: refundAmount > 0 },
        };
      },
    });
  }

  async cancelBusinessBooking(
    actorUserId: string,
    businessId: string,
    bookingId: string,
    dto: BusinessCancelBookingDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `booking.business_cancel:${bookingId}`,
      key: idempotencyKey,
      payload: dto,
      run: async () => {
        const booking = await this.requireBooking(bookingId);
        if (booking.businessId !== businessId) throw bookingNotFound();
        this.assertCancellable(booking);

        const now = new Date();
        // ADR 0040: business cancellation refunds the full net paid amount
        // regardless of thresholds — always 0 until online payments (M7).
        const refundAmount = netOnlinePaidOf(booking);

        await this.cancelTransaction(booking, {
          actorUserId,
          actorType: 'staff',
          reasonCode: dto.reasonCode,
          reason: dto.reason,
          cancelledAt: now,
          audit: { businessId },
        });
        // ponytail: customer notification lands with the notifications milestone.
        return {
          bookingId: booking.id,
          status: 'cancelled',
          cancelledAt: now.toISOString(),
          refund: { required: refundAmount > 0 },
        };
      },
    });
  }

  private assertCancellable(booking: BookingWithRelations): void {
    if (booking.status === 'cancelled') throw bookingAlreadyCancelled();
    if (booking.status === 'completed') throw bookingAlreadyCompleted();
    if (!CUSTOMER_CANCELLABLE.includes(booking.status as BookingStatus)) {
      throw bookingCannotBeCancelled();
    }
    if (booking.scheduledAt && booking.scheduledAt <= new Date()) {
      throw bookingCannotBeCancelled();
    }
    assertBookingTransition(booking.status as BookingStatus, 'cancelled');
  }

  private async cancelTransaction(
    booking: BookingWithRelations,
    input: {
      actorUserId: string;
      actorType: 'customer' | 'staff';
      reasonCode: string | null;
      reason: string | null;
      cancelledAt: Date;
      audit?: { businessId: string };
    },
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const updated = await tx.booking.updateMany({
        where: { id: booking.id, status: booking.status },
        data: {
          status: 'cancelled',
          cancelledAt: input.cancelledAt,
          version: { increment: 1 },
        },
      });
      // Somebody else transitioned the booking between read and write.
      if (updated.count === 0) throw bookingCannotBeCancelled();

      await tx.bookingReservation.deleteMany({ where: { bookingId: booking.id } });
      await tx.payment.updateMany({
        where: { bookingId: booking.id, status: 'pending' },
        data: { status: 'cancelled', cancelledAt: input.cancelledAt, version: { increment: 1 } },
      });
      await tx.bookingStatusHistory.create({
        data: {
          id: newId('bsh'),
          bookingId: booking.id,
          fromStatus: booking.status,
          toStatus: 'cancelled',
          actorUserId: input.actorUserId,
          actorType: input.actorType,
          reasonCode: input.reasonCode,
          reason: input.reason,
        },
      });
      if (input.audit) {
        await this.audit.record(
          {
            actorUserId: input.actorUserId,
            businessId: input.audit.businessId,
            outletId: booking.outletId,
            action: 'booking.business_cancel',
            resourceType: 'booking',
            resourceId: booking.id,
            beforeData: { status: booking.status },
            afterData: { status: 'cancelled' },
            reason: input.reason ?? undefined,
          },
          tx,
        );
      }
    });
  }

  /** Booking owner or an active member of the booking's business. */
  async assertCanReadBookingPayments(
    userId: string,
    booking: { customerUserId: string | null; businessId: string },
  ): Promise<void> {
    if (booking.customerUserId === userId) return;
    try {
      await this.memberships.requirePermission(userId, booking.businessId, null);
    } catch {
      throw forbiddenBookingResource();
    }
  }

  async requireBooking(bookingId: string): Promise<BookingWithRelations> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: bookingInclude,
    });
    if (!booking) throw bookingNotFound();
    return booking;
  }

  private applyListFilters(
    where: Prisma.BookingWhereInput,
    query: ListCustomerBookingsQueryDto,
  ): void {
    if (query.status) where.status = query.status;
    if (query.dateFrom || query.dateTo) {
      const businessDate: Prisma.DateTimeFilter = {};
      if (query.dateFrom) businessDate.gte = dateToDb(query.dateFrom);
      if (query.dateTo) businessDate.lte = dateToDb(query.dateTo);
      where.businessDate = businessDate;
    }
  }

  private async listPage(
    where: Prisma.BookingWhereInput,
    query: ListCustomerBookingsQueryDto,
    opts: { businessView?: boolean } = {},
  ): Promise<Record<string, unknown>> {
    const limit = clampLimit(query.limit);
    if (query.cursor) {
      const c = decodeCursor(query.cursor);
      const createdAt = new Date(c.createdAt ?? '');
      if (Number.isNaN(createdAt.getTime())) throw validationFailed('Cursor is invalid.');
      where.OR = [{ createdAt: { lt: createdAt } }, { createdAt, id: { lt: c.id ?? '' } }];
    }
    const rows = await this.prisma.booking.findMany({
      where,
      include: bookingInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const page = pageOf(rows, limit, (row) => ({
      createdAt: row.createdAt.toISOString(),
      id: row.id,
    }));
    return {
      items: page.items.map((row) => toBookingResource(row, opts)),
      pagination: page.pagination,
    };
  }
}
