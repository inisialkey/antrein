import { Injectable } from '@nestjs/common';
import { newId } from '../../../common/id/id';
import { Prisma } from '../../../generated/prisma/client';
import { PrismaService } from '../../../infrastructure/database/prisma.service';
import { IdempotencyService } from '../../idempotency/idempotency.service';
import { MembershipsService } from '../../memberships/memberships.service';
import { bookingNotFound } from '../booking.errors';
import { assertBookingTransition } from '../domain/booking-status.policy';
import { CheckInDto } from './dto/queue.dto';
import { checkInWindowState, formatDisplayNumber } from './domain/queue-math';
import {
  bookingCheckInTooEarly,
  bookingCheckInTooLate,
  bookingNotConfirmed,
  forbiddenQueueResource,
  outletQueueClosed,
  queueEntryAlreadyExists,
  queueEntryNotFound,
} from './domain/queue.errors';
import { toCheckInQueueBlock, toCustomerQueueResource } from './queue.mapper';
import {
  customerViewOf,
  insertBookingHistory,
  insertQueueHistory,
  jakartaBusinessDate,
  nextQueueNumber,
} from './queue-support';

/** Customer-facing queue: self/staff check-in (contract §64) and own queue view (§81). */
@Injectable()
export class QueueService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
    private readonly memberships: MembershipsService,
  ) {}

  async checkIn(
    actorUserId: string,
    bookingId: string,
    dto: CheckInDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: actorUserId,
      action: `check_in:${bookingId}`,
      key: idempotencyKey,
      payload: { bookingId, method: dto.method ?? 'customer_app' },
      resourceOf: (r) => ({ type: 'queue_entry', id: (r.queue as { id: string }).id }),
      run: () => this.checkInRun(actorUserId, bookingId, dto),
    });
  }

  private async checkInRun(
    actorUserId: string,
    bookingId: string,
    dto: CheckInDto,
  ): Promise<Record<string, unknown>> {
    const now = new Date();
    const method = dto.method ?? 'customer_app';

    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) throw bookingNotFound();

    const isOwner = booking.customerUserId === actorUserId;
    // Staff-assisted check-in needs queue.manage in the booking's business (§64).
    if (!isOwner) {
      await this.memberships.requirePermission(actorUserId, booking.businessId, 'queue.manage');
    }

    if (await this.prisma.queueEntry.findUnique({ where: { bookingId } })) {
      throw queueEntryAlreadyExists();
    }
    // Only confirmed scheduled bookings check in; walk-ins are created in the queue.
    if (
      booking.status !== 'confirmed' ||
      booking.bookingType !== 'scheduled' ||
      !booking.scheduledAt
    ) {
      throw bookingNotConfirmed();
    }

    const policy = await this.prisma.businessPolicy.findUnique({
      where: { businessId: booking.businessId },
    });
    const window = checkInWindowState(
      booking.scheduledAt,
      now,
      policy?.checkInEarlyMinutes ?? 30,
      policy?.checkInLateMinutes ?? 15,
    );
    if (window === 'too_early') throw bookingCheckInTooEarly();
    if (window === 'too_late') throw bookingCheckInTooLate();

    const outlet = await this.prisma.outlet.findUnique({ where: { id: booking.outletId } });
    if (!outlet || outlet.status !== 'active') throw outletQueueClosed();
    const { str: businessDateStr, date: businessDate } = jakartaBusinessDate(now);
    const closed = await this.prisma.closedDate.findUnique({
      where: { outletId_closedDate: { outletId: outlet.id, closedDate: businessDate } },
    });
    if (closed) throw outletQueueClosed();

    const entryId = newId('que');
    const actorType = isOwner ? 'customer' : 'staff';
    try {
      await this.prisma.$transaction(async (tx) => {
        // Lock the booking so a concurrent cancel cannot race the confirmed check.
        const locked = await tx.$queryRaw<Array<{ status: string }>>`
          SELECT status FROM bookings WHERE id = ${bookingId} FOR UPDATE`;
        if (locked[0]?.status !== 'confirmed') throw bookingNotConfirmed();

        const { number } = await nextQueueNumber(tx, outlet.id, businessDateStr);
        await tx.queueEntry.create({
          data: {
            id: entryId,
            bookingId,
            businessId: booking.businessId,
            outletId: outlet.id,
            staffId: booking.staffId,
            businessDate,
            queueNumber: number,
            displayNumber: formatDisplayNumber(outlet.queuePrefix, number),
            status: 'waiting',
            sortOrder: number,
            checkedInAt: now,
          },
        });

        // confirmed → checked_in → waiting (product brief §16.1): both hops are
        // validated and audited, but collapse into ONE physical write to the
        // final `waiting` state — `checked_in` is transient (never observed
        // outside this tx) and status is authoritative, so a second UPDATE would
        // only bump version again. Reservation stays held through `waiting`.
        assertBookingTransition('confirmed', 'checked_in');
        assertBookingTransition('checked_in', 'waiting');
        await tx.booking.update({
          where: { id: bookingId },
          data: { status: 'waiting', checkedInAt: now, version: { increment: 1 }, updatedAt: now },
        });
        await insertBookingHistory(tx, {
          bookingId,
          fromStatus: 'confirmed',
          toStatus: 'checked_in',
          actorUserId,
          actorType,
          metadata: { method },
        });
        await insertBookingHistory(tx, {
          bookingId,
          fromStatus: 'checked_in',
          toStatus: 'waiting',
          actorUserId,
          actorType,
        });
        await insertQueueHistory(tx, {
          queueEntryId: entryId,
          fromStatus: null,
          toStatus: 'waiting',
          actorUserId,
          actorType,
          metadata: { method, source: 'check_in' },
        });
        // ponytail: queue.entry.created outbox event lands with the realtime milestone.
      });
    } catch (error) {
      // Concurrent check-in loses the UNIQUE(booking_id) race.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw queueEntryAlreadyExists();
      }
      throw error;
    }

    const entry = await this.prisma.queueEntry.findUniqueOrThrow({ where: { id: entryId } });
    const view = await customerViewOf(this.prisma, entry);
    return {
      bookingId,
      bookingStatus: 'waiting',
      checkedInAt: now.toISOString(),
      queue: toCheckInQueueBlock(entry, view),
    };
  }

  async getCustomerQueue(actorUserId: string, bookingId: string): Promise<Record<string, unknown>> {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      select: { customerUserId: true },
    });
    if (!booking) throw queueEntryNotFound();
    if (booking.customerUserId !== actorUserId) throw forbiddenQueueResource();

    const entry = await this.prisma.queueEntry.findUnique({ where: { bookingId } });
    if (!entry) throw queueEntryNotFound();
    const view = await customerViewOf(this.prisma, entry);
    return toCustomerQueueResource(entry, view);
  }
}
