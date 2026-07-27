import { Injectable, Optional } from '@nestjs/common';
import { newId } from '../../../common/id/id';
import { Prisma } from '../../../generated/prisma/client';
import { PrismaService } from '../../../infrastructure/database/prisma.service';
import { MetricsService } from '../../../infrastructure/metrics/metrics.service';
import { AuditService } from '../../audit/audit.service';
import { ApiError, validationFailed } from '../../auth/auth.errors';
import { businessNotActive, outletNotFound } from '../../businesses/business.errors';
import { IdempotencyService } from '../../idempotency/idempotency.service';
import { businessNotFound } from '../../memberships/membership.errors';
import { staffNotEligibleForService } from '../../schedules/schedule.errors';
import { jakartaDateString } from '../../schedules/slots';
import { serviceNotFound } from '../../services/service.errors';
import { staffNotFound } from '../../staff/staff.errors';
import { formatBookingCode } from '../domain/booking-code';
import { CancellationPolicySnapshot } from '../domain/cancellation-policy';
import { bookingNotFound, serviceNotActive, staffNotActive } from '../booking.errors';
import {
  CompleteServiceDto,
  CreateWalkInDto,
  NoShowBookingDto,
  NoShowQueueEntryDto,
  OutletQueueQueryDto,
  QueueCommandDto,
  ReorderQueueDto,
  SkipQueueEntryDto,
  StartServiceDto,
} from './dto/queue.dto';
import { formatDisplayNumber } from './domain/queue-math';
import {
  bookingStatusForQueue,
  REORDERABLE_STATUSES,
  QueueStatus,
} from './domain/queue-status.policy';
import {
  bookingNotConfirmed,
  forbiddenQueueResource,
  queueEntryAlreadyCompleted,
  queueEntryNotCalled,
  queueEntryNotFound,
  queueEntryNotInService,
  queueEntryNotSkipped,
  queueEntryNotWaiting,
  queueHasCalledEntry,
  queueReorderInvalidEntries,
  staffNotAvailable,
} from './domain/queue.errors';
import {
  ACTIVE_QUEUE_STATUSES,
  bumpQueueVersion,
  customerViewOf,
  enqueueQueueEvent,
  insertBookingHistory,
  insertQueueHistory,
  jakartaBusinessDate,
  nextQueueNumber,
  releaseReservation,
  transitionBookingWithQueue,
  versionedQueueUpdate,
} from './queue-support';

const isUniqueViolation = (error: unknown): boolean =>
  error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';

/** Staff-facing queue operations (contract §67, §82–§90). */
@Injectable()
export class QueueCommandsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly audit: AuditService,
    @Optional()
    private readonly metrics?: MetricsService,
  ) {}

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  async getOutletSnapshot(
    businessId: string,
    outletId: string,
    query: OutletQueueQueryDto,
  ): Promise<Record<string, unknown>> {
    const outlet = await this.prisma.outlet.findUnique({ where: { id: outletId } });
    if (!outlet || outlet.businessId !== businessId) throw outletNotFound();

    const businessDateStr = query.date ?? jakartaDateString(new Date());
    const businessDate = new Date(`${businessDateStr}T00:00:00Z`);
    // ponytail: query.status is reserved — the snapshot always returns the full
    // currentServing/waiting/skipped structure (contract §82). Terminal entries
    // (completed/cancelled/no_show) accumulate over a day and are never shown, so
    // filter them out at the query (covered by queue_entries_outlet_date_status_idx).
    const entries = await this.prisma.queueEntry.findMany({
      where: { outletId, businessDate, status: { in: ACTIVE_QUEUE_STATUSES } },
      orderBy: [{ sortOrder: 'asc' }, { checkedInAt: 'asc' }, { queueNumber: 'asc' }],
    });

    const bookingIds = entries.map((e) => e.bookingId);
    const bookings = await this.prisma.booking.findMany({
      where: { id: { in: bookingIds } },
      select: { id: true, customerUserId: true, walkInCustomerName: true },
    });
    const snapshots = await this.prisma.bookingSnapshot.findMany({
      where: { bookingId: { in: bookingIds } },
      select: { bookingId: true, serviceName: true },
    });
    const userIds = bookings.map((b) => b.customerUserId).filter((v): v is string => !!v);
    const users = userIds.length
      ? await this.prisma.user.findMany({
          where: { id: { in: userIds } },
          select: { id: true, name: true },
        })
      : [];
    const staffIds = entries.map((e) => e.staffId).filter((v): v is string => !!v);
    const staff = staffIds.length
      ? await this.prisma.staffProfile.findMany({
          where: { id: { in: staffIds } },
          select: { id: true, displayName: true },
        })
      : [];

    const bookingById = new Map(bookings.map((b) => [b.id, b]));
    const serviceByBooking = new Map(snapshots.map((s) => [s.bookingId, s.serviceName]));
    const userById = new Map(users.map((u) => [u.id, u.name]));
    const staffById = new Map(staff.map((s) => [s.id, s.displayName]));

    // Staff snapshot carries operational names only — never phone numbers (ADR 0041).
    const toItem = (e: (typeof entries)[number]): Record<string, unknown> => {
      const booking = bookingById.get(e.bookingId);
      const customerName =
        booking?.walkInCustomerName ??
        (booking?.customerUserId ? (userById.get(booking.customerUserId) ?? null) : null);
      return {
        queueEntryId: e.id,
        displayNumber: e.displayNumber,
        bookingId: e.bookingId,
        customer: { name: customerName },
        service: { name: serviceByBooking.get(e.bookingId) ?? null },
        staff: e.staffId ? { id: e.staffId, name: staffById.get(e.staffId) ?? null } : null,
        status: e.status,
        // Per-entry version so staff can supply expectedVersion on commands (§20).
        version: e.version,
        checkedInAt: e.checkedInAt.toISOString(),
      };
    };

    const serving =
      entries.find((e) => e.status === 'in_service') ?? entries.find((e) => e.status === 'called');
    const counter = await this.prisma.queueCounter.findUnique({
      where: { outletId_businessDate: { outletId, businessDate } },
    });
    const closed = await this.prisma.closedDate.findUnique({
      where: { outletId_closedDate: { outletId, closedDate: businessDate } },
    });

    return {
      businessDate: businessDateStr,
      outletId,
      isOpen: outlet.status === 'active' && !closed,
      currentServing: serving ? toItem(serving) : null,
      waiting: entries.filter((e) => e.status === 'waiting').map(toItem),
      skipped: entries.filter((e) => e.status === 'skipped').map(toItem),
      version: counter?.version ?? 1,
      updatedAt: (counter?.updatedAt ?? new Date()).toISOString(),
    };
  }

  // -------------------------------------------------------------------------
  // Walk-in (contract §67)
  // -------------------------------------------------------------------------

  async createWalkIn(
    actorUserId: string,
    businessId: string,
    dto: CreateWalkInDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `walk_in:${businessId}`,
      key: idempotencyKey,
      payload: dto,
      resourceOf: (r) => ({ type: 'booking', id: (r.booking as { id: string }).id }),
      run: () => this.walkInRun(actorUserId, businessId, dto),
    });
  }

  private async walkInRun(
    actorUserId: string,
    businessId: string,
    dto: CreateWalkInDto,
  ): Promise<Record<string, unknown>> {
    const now = new Date();
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      include: { policy: true },
    });
    if (!business) throw businessNotFound();
    if (business.status !== 'active') throw businessNotActive();

    const outlet = await this.prisma.outlet.findUnique({ where: { id: dto.outletId } });
    if (!outlet || outlet.businessId !== businessId || outlet.status !== 'active')
      throw outletNotFound();

    const service = await this.prisma.service.findUnique({
      where: { id: dto.serviceId },
      include: { staffLinks: { select: { staffId: true } } },
    });
    if (!service || service.businessId !== businessId) throw serviceNotFound();
    if (service.status !== 'active') throw serviceNotActive();

    let staffId: string | null = null;
    let staffName: string | null = null;
    if (dto.staffSelection.mode === 'specific_staff') {
      if (!dto.staffSelection.staffId)
        throw validationFailed('staffSelection.staffId is required.');
      const staff = await this.prisma.staffProfile.findUnique({
        where: { id: dto.staffSelection.staffId },
      });
      if (!staff || staff.businessId !== businessId) throw staffNotFound();
      if (staff.status !== 'active') throw staffNotActive();
      if (
        service.staffLinks.length > 0 &&
        !service.staffLinks.some((l) => l.staffId === staff.id)
      ) {
        throw staffNotEligibleForService();
      }
      staffId = staff.id;
      staffName = staff.displayName;
    }

    const { str: businessDateStr, date: businessDate } = jakartaBusinessDate(now);
    const bookingId = newId('bkg');
    const entryId = newId('que');
    const cancellationPolicy: CancellationPolicySnapshot = {
      fullRefundBeforeMinutes: business.policy?.fullRefundBeforeMinutes ?? 360,
      partialRefundBeforeMinutes: business.policy?.partialRefundBeforeMinutes ?? 120,
      partialRefundPercentage: business.policy?.partialRefundPercentage ?? 50,
      noShowRefundPercentage: business.policy?.noShowRefundPercentage ?? 0,
    };

    await this.prisma.$transaction(async (tx) => {
      const counter = await tx.$queryRaw<Array<{ last_number: number }>>`
        INSERT INTO booking_code_counters (business_id, business_date, last_number)
        VALUES (${businessId}, ${businessDateStr}::date, 1)
        ON CONFLICT (business_id, business_date)
        DO UPDATE SET last_number = booking_code_counters.last_number + 1
        RETURNING last_number`;
      const bookingCode = formatBookingCode(businessDateStr, counter[0].last_number);

      await tx.booking.create({
        data: {
          id: bookingId,
          bookingCode,
          customerUserId: null,
          businessId,
          outletId: outlet.id,
          serviceId: service.id,
          staffId,
          bookingType: 'walk_in',
          status: 'waiting',
          paymentOption: 'pay_at_location',
          businessDate,
          walkInCustomerName: dto.customer.name,
          walkInPhoneNumber: dto.customer.phoneNumber ?? null,
          customerNotes: dto.notes ?? null,
          createdByUserId: actorUserId,
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
          depositType: 'none',
          depositValue: 0,
          requiredPaymentAmount: 0,
          staffName,
          cancellationPolicy: cancellationPolicy as unknown as Prisma.InputJsonValue,
        },
      });
      await insertBookingHistory(tx, {
        bookingId,
        fromStatus: null,
        toStatus: 'waiting',
        actorUserId,
        actorType: 'staff',
        metadata: { source: 'walk_in' },
      });
      // Walk-ins settle at the location: one pending pay-at-location receipt, no
      // reservation (served immediately in queue order).
      await tx.payment.create({
        data: {
          id: newId('pay'),
          bookingId,
          businessId,
          customerUserId: null,
          provider: 'pay_at_location',
          paymentOption: 'pay_at_location',
          status: 'pending',
          amount: service.priceAmount,
        },
      });
      const { number } = await nextQueueNumber(tx, outlet.id, businessDateStr);
      await tx.queueEntry.create({
        data: {
          id: entryId,
          bookingId,
          businessId,
          outletId: outlet.id,
          staffId,
          businessDate,
          queueNumber: number,
          displayNumber: formatDisplayNumber(outlet.queuePrefix, number),
          status: 'waiting',
          sortOrder: number,
          checkedInAt: now,
        },
      });
      await insertQueueHistory(tx, {
        queueEntryId: entryId,
        fromStatus: null,
        toStatus: 'waiting',
        actorUserId,
        actorType: 'staff',
        metadata: { source: 'walk_in' },
      });
      await enqueueQueueEvent(tx, {
        queueEntryId: entryId,
        bookingId,
        outletId: outlet.id,
        businessDate,
      });
    });

    const entry = await this.prisma.queueEntry.findUniqueOrThrow({ where: { id: entryId } });
    const view = await customerViewOf(this.prisma, entry);
    return {
      booking: { id: bookingId, type: 'walk_in', status: 'waiting' },
      queue: {
        id: entryId,
        queueNumber: entry.queueNumber,
        displayNumber: entry.displayNumber,
        status: 'waiting',
        peopleAhead: view.peopleAhead,
      },
    };
  }

  // -------------------------------------------------------------------------
  // Versioned staff commands (contract §83–§89)
  // -------------------------------------------------------------------------

  call(
    actor: string,
    businessId: string,
    entryId: string,
    dto: QueueCommandDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_call',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'waiting') throw queueEntryNotWaiting();
        try {
          await versionedQueueUpdate(
            tx,
            entry.id,
            dto.expectedVersion,
            { status: 'called', calledAt: at },
            at,
          );
        } catch (error) {
          if (isUniqueViolation(error)) throw queueHasCalledEntry(); // one called entry per outlet+date
          throw error;
        }
        await this.syncBooking(tx, entry, 'waiting', 'called', actor, at);
        await insertQueueHistory(tx, this.history(entry, 'waiting', 'called', actor));
        return {
          queueEntryId: entry.id,
          status: 'called',
          calledAt: at.toISOString(),
          version: dto.expectedVersion + 1,
        };
      },
    );
  }

  recall(
    actor: string,
    businessId: string,
    entryId: string,
    dto: QueueCommandDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_recall',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'called') throw queueEntryNotCalled();
        await versionedQueueUpdate(
          tx,
          entry.id,
          dto.expectedVersion,
          { lastRecalledAt: at, recallCount: { increment: 1 } },
          at,
        );
        await insertQueueHistory(tx, {
          ...this.history(entry, 'called', 'called', actor),
          metadata: { action: 'recall' },
        });
        return {
          queueEntryId: entry.id,
          status: 'called',
          lastRecalledAt: at.toISOString(),
          recallCount: entry.recallCount + 1,
          version: dto.expectedVersion + 1,
        };
      },
    );
  }

  skip(
    actor: string,
    businessId: string,
    entryId: string,
    dto: SkipQueueEntryDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_skip',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'called') throw queueEntryNotCalled();
        await versionedQueueUpdate(tx, entry.id, dto.expectedVersion, { status: 'skipped' }, at);
        await this.syncBooking(tx, entry, 'called', 'skipped', actor, at, dto.reason);
        await insertQueueHistory(tx, {
          ...this.history(entry, 'called', 'skipped', actor),
          reason: dto.reason,
        });
        return {
          queueEntryId: entry.id,
          status: 'skipped',
          version: dto.expectedVersion + 1,
          updatedAt: at.toISOString(),
        };
      },
    );
  }

  returnToWaiting(
    actor: string,
    businessId: string,
    entryId: string,
    dto: QueueCommandDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_return',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'skipped') throw queueEntryNotSkipped();
        // ADR 0041: returned entries go to the END of the waiting queue.
        const max = await tx.queueEntry.aggregate({
          where: {
            outletId: entry.outletId,
            businessDate: entry.businessDate,
            status: { in: ACTIVE_QUEUE_STATUSES },
          },
          _max: { sortOrder: true },
        });
        const sortOrder = (max._max.sortOrder ?? entry.sortOrder) + 1;
        await versionedQueueUpdate(
          tx,
          entry.id,
          dto.expectedVersion,
          { status: 'waiting', sortOrder },
          at,
        );
        // Booking already 'waiting' (skipped maps to waiting) — no booking transition.
        await insertQueueHistory(tx, this.history(entry, 'skipped', 'waiting', actor));
        return {
          queueEntryId: entry.id,
          status: 'waiting',
          version: dto.expectedVersion + 1,
          updatedAt: at.toISOString(),
        };
      },
    );
  }

  startService(
    actor: string,
    businessId: string,
    entryId: string,
    dto: StartServiceDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_start',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'called') throw queueEntryNotCalled();
        const staffId = dto.staffId ?? entry.staffId;
        if (!staffId) throw staffNotAvailable();
        const staff = await tx.staffProfile.findUnique({ where: { id: staffId } });
        if (!staff || staff.businessId !== businessId || staff.status !== 'active')
          throw staffNotAvailable();
        try {
          await versionedQueueUpdate(
            tx,
            entry.id,
            dto.expectedVersion,
            { status: 'in_service', staffId, serviceStartedAt: at },
            at,
          );
        } catch (error) {
          if (isUniqueViolation(error)) throw staffNotAvailable(); // one in-service entry per staff
          throw error;
        }
        await this.syncBooking(tx, entry, 'called', 'in_service', actor, at);
        await insertQueueHistory(tx, this.history(entry, 'called', 'in_service', actor));
        return {
          queueEntryId: entry.id,
          queueStatus: 'in_service',
          bookingStatus: 'in_service',
          serviceStartedAt: at.toISOString(),
          version: dto.expectedVersion + 1,
        };
      },
    );
  }

  complete(
    actor: string,
    businessId: string,
    entryId: string,
    dto: CompleteServiceDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_complete',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'in_service') {
          throw entry.status === 'completed'
            ? queueEntryAlreadyCompleted()
            : queueEntryNotInService();
        }
        await versionedQueueUpdate(
          tx,
          entry.id,
          dto.expectedVersion,
          { status: 'completed', completedAt: at },
          at,
        );
        await this.syncBooking(tx, entry, 'in_service', 'completed', actor, at, dto.internalNote);
        // Completion may leave a pay-at-location balance (§88); release the slot.
        await releaseReservation(tx, entry.bookingId);
        await insertQueueHistory(tx, {
          ...this.history(entry, 'in_service', 'completed', actor),
          reason: dto.internalNote,
        });
        const paymentSummary = await this.paymentSummaryOf(tx, entry.bookingId);
        return {
          queueEntryId: entry.id,
          queueStatus: 'completed',
          bookingStatus: 'completed',
          completedAt: at.toISOString(),
          version: dto.expectedVersion + 1,
          paymentSummary,
        };
      },
    );
  }

  markNoShowEntry(
    actor: string,
    businessId: string,
    entryId: string,
    dto: NoShowQueueEntryDto,
    key: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.command(
      actor,
      businessId,
      entryId,
      'queue_no_show',
      dto,
      key,
      async (tx, entry, at) => {
        if (entry.status !== 'called' && entry.status !== 'skipped') throw queueEntryNotCalled();
        const from = entry.status as QueueStatus;
        await versionedQueueUpdate(
          tx,
          entry.id,
          dto.expectedVersion,
          { status: 'no_show', noShowAt: at },
          at,
        );
        await this.syncBooking(tx, entry, from, 'no_show', actor, at, dto.reason);
        await releaseReservation(tx, entry.bookingId);
        await insertQueueHistory(tx, {
          ...this.history(entry, from, 'no_show', actor),
          reason: dto.reason,
        });
        return {
          queueEntryId: entry.id,
          status: 'no_show',
          version: dto.expectedVersion + 1,
          markedAt: at.toISOString(),
        };
      },
    );
  }

  /** §68 booking-level no-show: a confirmed booking that never entered the queue. */
  async markNoShowBooking(
    actorUserId: string,
    businessId: string,
    bookingId: string,
    dto: NoShowBookingDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `booking_no_show:${bookingId}`,
      key: idempotencyKey,
      payload: { bookingId, reason: dto.reason },
      resourceOf: () => ({ type: 'booking', id: bookingId }),
      run: async () => {
        const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
        if (!booking || booking.businessId !== businessId) throw bookingNotFound();
        if (booking.status !== 'confirmed') throw bookingNotConfirmed();
        const at = new Date();
        await this.prisma.$transaction(async (tx) => {
          await transitionBookingWithQueue(tx, {
            bookingId,
            fromStatus: 'confirmed',
            toStatus: 'no_show',
            actorUserId,
            actorType: 'staff',
            reason: dto.reason,
            at,
          });
          await releaseReservation(tx, bookingId);
          // ponytail: no-show refund is 0% by default (ADR 0018); a >0 policy
          // would issue a refund here — deferred until a business configures one.
        });
        return { bookingId, status: 'no_show', markedAt: at.toISOString() };
      },
    });
  }

  // -------------------------------------------------------------------------
  // Reorder (contract §90)
  // -------------------------------------------------------------------------

  async reorder(
    actorUserId: string,
    businessId: string,
    outletId: string,
    dto: ReorderQueueDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `queue_reorder:${outletId}:${dto.businessDate}`,
      key: idempotencyKey,
      payload: dto,
      run: async () => {
        const result = await this.reorderRun(actorUserId, businessId, outletId, dto);
        this.metrics?.inc('queue_reorder_total');
        return result;
      },
    });
  }

  private async reorderRun(
    actorUserId: string,
    businessId: string,
    outletId: string,
    dto: ReorderQueueDto,
  ): Promise<Record<string, unknown>> {
    const outlet = await this.prisma.outlet.findUnique({ where: { id: outletId } });
    if (!outlet || outlet.businessId !== businessId) throw outletNotFound();
    const businessDate = new Date(`${dto.businessDate}T00:00:00Z`);

    return this.prisma.$transaction(async (tx) => {
      const queueVersion = await bumpQueueVersion(
        tx,
        outletId,
        dto.businessDate,
        dto.expectedQueueVersion,
      );

      const active = await tx.queueEntry.findMany({
        where: { outletId, businessDate, status: { in: [...REORDERABLE_STATUSES] } },
        select: { id: true, sortOrder: true },
        orderBy: { sortOrder: 'asc' },
      });
      const activeIds = new Set(active.map((e) => e.id));
      const requested = dto.orderedQueueEntryIds;
      const uniqueRequested = new Set(requested);
      // Request must be exactly the set of reorderable entries (§33).
      if (
        requested.length !== active.length ||
        uniqueRequested.size !== requested.length ||
        !requested.every((id) => activeIds.has(id))
      ) {
        throw queueReorderInvalidEntries();
      }

      const previousOrder = active.map((e) => e.id);
      const at = new Date();
      for (let i = 0; i < requested.length; i++) {
        await tx.queueEntry.update({
          where: { id: requested[i] },
          data: { sortOrder: i + 1, updatedAt: at },
        });
      }
      await tx.queueReorder.create({
        data: {
          id: newId('qre'),
          businessId,
          outletId,
          businessDate,
          actorUserId,
          previousOrder: previousOrder as unknown as Prisma.InputJsonValue,
          newOrder: requested as unknown as Prisma.InputJsonValue,
          reason: dto.reason,
        },
      });
      await this.audit.record(
        {
          actorUserId,
          businessId,
          outletId,
          action: 'queue.reorder',
          resourceType: 'outlet_queue',
          resourceId: outletId,
          beforeData: { order: previousOrder },
          afterData: { order: requested },
          reason: dto.reason,
        },
        tx,
      );
      // Reorder changes staff-visible order only — snapshot event, no per-customer event.
      await enqueueQueueEvent(tx, { outletId, businessDate });
      return { businessDate: dto.businessDate, queueVersion, updatedAt: at.toISOString() };
    });
  }

  // -------------------------------------------------------------------------
  // Shared scaffolding
  // -------------------------------------------------------------------------

  private command(
    actorUserId: string,
    businessId: string,
    entryId: string,
    action: string,
    dto: QueueCommandDto,
    idempotencyKey: string | undefined,
    handler: (
      tx: Prisma.TransactionClient,
      entry: Prisma.QueueEntryGetPayload<object>,
      at: Date,
    ) => Promise<Record<string, unknown>>,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `${action}:${entryId}`,
      key: idempotencyKey,
      payload: { entryId, ...dto },
      resourceOf: () => ({ type: 'queue_entry', id: entryId }),
      run: async () => {
        const entry = await this.prisma.queueEntry.findUnique({ where: { id: entryId } });
        if (!entry) throw queueEntryNotFound();
        // Knowing the id is not permission: the entry must belong to the business.
        if (entry.businessId !== businessId) throw forbiddenQueueResource();
        try {
          const outcome = await this.prisma.$transaction(async (tx) => {
            const result = await handler(tx, entry, new Date());
            // Every versioned command touches this entry — one marker per command
            // fans out to the customer + staff snapshot events (§49). Call and
            // recall are the push-worthy ones (realtime-queue §54).
            await enqueueQueueEvent(tx, {
              queueEntryId: entry.id,
              bookingId: entry.bookingId,
              outletId: entry.outletId,
              businessDate: entry.businessDate,
              push: action === 'queue_call' || action === 'queue_recall' ? 'called' : undefined,
            });
            return result;
          });
          this.metrics?.inc(`${action}_total`);
          return outcome;
        } catch (error) {
          // ApiError carries its stable code inside the HttpException response body.
          const code =
            error instanceof ApiError ? (error.getResponse() as { code?: string }).code : undefined;
          if (code === 'QUEUE_VERSION_CONFLICT') {
            this.metrics?.inc('queue_version_conflict_total');
          }
          throw error;
        }
      },
    });
  }

  private syncBooking(
    tx: Prisma.TransactionClient,
    entry: Prisma.QueueEntryGetPayload<object>,
    fromQueue: QueueStatus,
    toQueue: QueueStatus,
    actorUserId: string,
    at: Date,
    reason?: string | null,
  ): Promise<void> {
    return transitionBookingWithQueue(tx, {
      bookingId: entry.bookingId,
      fromStatus: bookingStatusForQueue(fromQueue),
      toStatus: bookingStatusForQueue(toQueue),
      actorUserId,
      actorType: 'staff',
      reason,
      at,
    });
  }

  private history(
    entry: Prisma.QueueEntryGetPayload<object>,
    fromStatus: QueueStatus,
    toStatus: QueueStatus,
    actorUserId: string,
  ): {
    queueEntryId: string;
    fromStatus: QueueStatus;
    toStatus: QueueStatus;
    actorUserId: string;
    actorType: string;
  } {
    return { queueEntryId: entry.id, fromStatus, toStatus, actorUserId, actorType: 'staff' };
  }

  private async paymentSummaryOf(
    tx: Prisma.TransactionClient,
    bookingId: string,
  ): Promise<Record<string, unknown>> {
    const snapshot = await tx.bookingSnapshot.findUnique({
      where: { bookingId },
      select: { servicePriceAmount: true, currency: true },
    });
    const payments = await tx.payment.findMany({
      where: { bookingId },
      select: { status: true, amount: true },
    });
    const currency = snapshot?.currency ?? 'IDR';
    const total = snapshot?.servicePriceAmount ?? 0;
    const paid = payments.filter((p) => p.status === 'paid').reduce((sum, p) => sum + p.amount, 0);
    const remaining = Math.max(0, total - paid);
    const money = (amount: number) => ({ amount, currency });
    return {
      totalAmount: money(total),
      paidAmount: money(paid),
      remainingAmount: money(remaining),
      status: paid >= total && total > 0 ? 'paid' : paid > 0 ? 'partially_paid' : 'unpaid',
    };
  }
}
