import { randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import {
  EmailPort,
  PasswordChangedEmailInput,
  PasswordResetEmailInput,
  StaffInvitationEmailInput,
} from '../src/infrastructure/email/email.port';
import { PrismaService } from '../src/infrastructure/database/prisma.service';
import { addDays, jakartaDateString } from '../src/modules/schedules/slots';

jest.setTimeout(120_000);

class SilentEmail extends EmailPort {
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(_input: StaffInvitationEmailInput): Promise<void> {}
}

const PASSWORD = 'integration-password-1';
const ALL_DAYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;

describe('Queue endpoints (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;

  const uniqueEmail = (): string => `it-que-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;
  const target = addDays(jakartaDateString(new Date()), 7);
  const today = jakartaDateString(new Date());

  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;

  const registerUser = async (): Promise<{ userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Queue User', email: uniqueEmail(), password: PASSWORD })
      .expect(201);
    return { userId: res.body.data.user.id, accessToken: res.body.data.session.accessToken };
  };

  // Distinct slot per booking so the shared staff's reservations never overlap
  // (45-min service, 60-min spacing, rolling across days within the 30-day horizon).
  let slotSeq = 0;
  const nextScheduledAt = (): string => {
    const n = slotSeq++;
    const date = addDays(target, Math.floor(n / 9));
    const hour = String(9 + (n % 9)).padStart(2, '0');
    return `${date}T${hour}:00:00+07:00`;
  };

  const createBooking = (token: string, key = idem()): request.Test =>
    http()
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({
        businessId,
        outletId,
        serviceId,
        staffSelection: { mode: 'specific_staff', staffId },
        scheduledAt: nextScheduledAt(),
        paymentOption: 'pay_at_location',
      });

  /** A confirmed booking pulled into the check-in window with its slot freed. */
  const checkableBooking = async (): Promise<{
    bookingId: string;
    token: string;
    userId: string;
  }> => {
    const customer = await registerUser();
    const res = await createBooking(customer.accessToken).expect(201);
    const bookingId = res.body.data.booking.id as string;
    await prisma.bookingReservation.deleteMany({ where: { bookingId } });
    await prisma.booking.update({ where: { id: bookingId }, data: { scheduledAt: new Date() } });
    return { bookingId, token: customer.accessToken, userId: customer.userId };
  };

  const checkIn = (token: string, bookingId: string, key = idem(), method = 'customer_app') =>
    http()
      .post(`/api/v1/bookings/${bookingId}/check-in`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({ method });

  const biz = (path: string, body: object, key = idem()) =>
    http()
      .post(`/api/v1/businesses/${businessId}${path}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', key)
      .send(body);

  const snapshot = async () => {
    const res = await http()
      .get(`/api/v1/businesses/${businessId}/outlets/${outletId}/queue`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .expect(200);
    return res.body.data;
  };

  const versionOf = async (entryId: string): Promise<number> => {
    const snap = await snapshot();
    const all = [snap.currentServing, ...snap.waiting, ...snap.skipped].filter(Boolean);
    return all.find((e: { queueEntryId: string }) => e.queueEntryId === entryId).version;
  };

  /** Check in and resolve to a called entry, returning id + current version. */
  const callFresh = async (): Promise<{ entryId: string; version: number }> => {
    const { bookingId, token } = await checkableBooking();
    const res = await checkIn(token, bookingId).expect(200);
    const entryId = res.body.data.queue.id as string;
    const called = await biz(`/queue/${entryId}/call`, { expectedVersion: 1 }).expect(200);
    return { entryId, version: called.body.data.version as number };
  };

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS = '0';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(new SilentEmail())
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    http = () => request(app.getHttpServer());
    prisma = app.get(PrismaService);

    const owner = await registerUser();
    ownerToken = owner.accessToken;

    const business = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `Queue Barber ${randomUUID().slice(0, 8)}`,
        primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 10' } },
      })
      .expect(201);
    businessId = business.body.data.id;
    outletId = business.body.data.primaryOutlet.id;

    await http()
      .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        timezone: 'Asia/Jakarta',
        days: ALL_DAYS.map((dayOfWeek) => ({
          dayOfWeek,
          isClosed: false,
          periods: [{ opensAt: '09:00', closesAt: '18:00' }],
        })),
      })
      .expect(200);

    const svc = await http()
      .post(`/api/v1/businesses/${businessId}/services`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({ name: 'Haircut', durationMinutes: 45, price: { amount: 50000, currency: 'IDR' } })
      .expect(201);
    serviceId = svc.body.data.id;

    const inviteeEmail = uniqueEmail();
    const invite = await http()
      .post(`/api/v1/businesses/${businessId}/staff/invitations`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        email: inviteeEmail,
        displayName: 'Andi',
        role: 'barber',
        outletIds: [outletId],
        eligibleServiceIds: [serviceId],
      })
      .expect(201);
    const inviteeRes = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Andi', email: inviteeEmail, password: PASSWORD })
      .expect(201);
    const accept = await http()
      .post(`/api/v1/staff/invitations/${invite.body.data.invitationId}/accept`)
      .set('Authorization', `Bearer ${inviteeRes.body.data.session.accessToken}`)
      .set('Idempotency-Key', idem())
      .expect(200);
    staffId = accept.body.data.staffId;
  });

  afterAll(async () => {
    await app.close();
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
    delete process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS;
  });

  describe('check-in (§64)', () => {
    it('creates a waiting queue entry and moves the booking to waiting', async () => {
      const { bookingId, token } = await checkableBooking();
      const res = await checkIn(token, bookingId).expect(200);

      expect(res.body.data.bookingStatus).toBe('waiting');
      expect(res.body.data.queue.status).toBe('waiting');
      expect(res.body.data.queue.id).toMatch(/^que_/);
      expect(res.body.data.queue.displayNumber).toMatch(/^A\d{3,}$/);
      expect(res.body.data.queue.businessDate).toBe(today);

      const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
      expect(booking?.status).toBe('waiting');
      expect(booking?.checkedInAt).not.toBeNull();
      const history = await prisma.bookingStatusHistory.findMany({ where: { bookingId } });
      // create(null→confirmed) + check-in(confirmed→checked_in→waiting)
      expect(history.map((h) => h.toStatus)).toEqual(
        expect.arrayContaining(['checked_in', 'waiting']),
      );
    });

    it('replays the same idempotency key without a second entry', async () => {
      const { bookingId, token } = await checkableBooking();
      const key = idem();
      const first = await checkIn(token, bookingId, key).expect(200);
      const second = await checkIn(token, bookingId, key).expect(200);
      expect(second.body.data.queue.id).toBe(first.body.data.queue.id);
      const count = await prisma.queueEntry.count({ where: { bookingId } });
      expect(count).toBe(1);
    });

    it('rejects a second check-in under a different key with QUEUE_ENTRY_ALREADY_EXISTS', async () => {
      const { bookingId, token } = await checkableBooking();
      await checkIn(token, bookingId).expect(200);
      const res = await checkIn(token, bookingId).expect(409);
      expect(res.body.error.code).toBe('QUEUE_ENTRY_ALREADY_EXISTS');
    });

    it('rejects check-in before the window opens with BOOKING_CHECK_IN_TOO_EARLY', async () => {
      // A booking left at its far-future scheduled time is outside the window.
      const customer = await registerUser();
      const created = await createBooking(customer.accessToken).expect(201);
      const res = await checkIn(customer.accessToken, created.body.data.booking.id).expect(422);
      expect(res.body.error.code).toBe('BOOKING_CHECK_IN_TOO_EARLY');
    });

    it('increments the queue number for the next check-in', async () => {
      const a = await checkableBooking();
      const b = await checkableBooking();
      const first = await checkIn(a.token, a.bookingId).expect(200);
      const second = await checkIn(b.token, b.bookingId).expect(200);
      expect(second.body.data.queue.queueNumber).toBeGreaterThan(first.body.data.queue.queueNumber);
    });
  });

  describe('customer queue (§81)', () => {
    it('returns the owner queue view but forbids other customers', async () => {
      const { bookingId, token } = await checkableBooking();
      await checkIn(token, bookingId).expect(200);

      const own = await http()
        .get(`/api/v1/bookings/${bookingId}/queue`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(own.body.data.bookingId).toBe(bookingId);
      expect(own.body.data).toHaveProperty('peopleAhead');
      expect(own.body.data).toHaveProperty('estimatedWaitMinutes');

      const other = await registerUser();
      const forbidden = await http()
        .get(`/api/v1/bookings/${bookingId}/queue`)
        .set('Authorization', `Bearer ${other.accessToken}`)
        .expect(403);
      expect(forbidden.body.error.code).toBe('FORBIDDEN_QUEUE_RESOURCE');
    });
  });

  describe('staff lifecycle (§82–§89)', () => {
    it('call → start-service → complete syncs booking status and releases the slot', async () => {
      const { bookingId, token } = await checkableBooking();
      const checkedIn = await checkIn(token, bookingId).expect(200);
      const entryId = checkedIn.body.data.queue.id;

      const called = await biz(`/queue/${entryId}/call`, { expectedVersion: 1 }).expect(200);
      expect(called.body.data.status).toBe('called');
      expect((await prisma.booking.findUnique({ where: { id: bookingId } }))?.status).toBe(
        'called',
      );

      const started = await biz(`/queue/${entryId}/start-service`, {
        expectedVersion: called.body.data.version,
        staffId,
      }).expect(200);
      expect(started.body.data.queueStatus).toBe('in_service');
      expect(started.body.data.bookingStatus).toBe('in_service');

      const completed = await biz(`/queue/${entryId}/complete`, {
        expectedVersion: started.body.data.version,
      }).expect(200);
      expect(completed.body.data.queueStatus).toBe('completed');
      expect(completed.body.data.bookingStatus).toBe('completed');
      expect(completed.body.data.paymentSummary.status).toBe('unpaid');

      const reservation = await prisma.bookingReservation.findUnique({ where: { bookingId } });
      expect(reservation).toBeNull();
    });

    it('rejects a stale expectedVersion with QUEUE_VERSION_CONFLICT', async () => {
      const { entryId, version } = await callFresh();
      const conflict = await biz(`/queue/${entryId}/skip`, { expectedVersion: 1 }).expect(409);
      expect(conflict.body.error.code).toBe('QUEUE_VERSION_CONFLICT');
      // resolve the called entry so it does not block later calls
      await biz(`/queue/${entryId}/skip`, { expectedVersion: version }).expect(200);
    });

    it('allows only one called entry per outlet (QUEUE_HAS_CALLED_ENTRY)', async () => {
      const first = await callFresh();
      const { bookingId, token } = await checkableBooking();
      const checkedIn = await checkIn(token, bookingId).expect(200);
      const secondId = checkedIn.body.data.queue.id;

      const blocked = await biz(`/queue/${secondId}/call`, { expectedVersion: 1 }).expect(409);
      expect(blocked.body.error.code).toBe('QUEUE_HAS_CALLED_ENTRY');
      // free the outlet
      await biz(`/queue/${first.entryId}/skip`, { expectedVersion: first.version }).expect(200);
    });

    it('recalls a called entry and increments the recall count', async () => {
      const { entryId, version } = await callFresh();
      const recalled = await biz(`/queue/${entryId}/recall`, { expectedVersion: version }).expect(
        200,
      );
      expect(recalled.body.data.recallCount).toBe(1);
      await biz(`/queue/${entryId}/skip`, { expectedVersion: recalled.body.data.version }).expect(
        200,
      );
    });

    it('skip keeps the booking waiting; return-to-waiting re-queues it', async () => {
      const { bookingId, token } = await checkableBooking();
      const checkedIn = await checkIn(token, bookingId).expect(200);
      const entryId = checkedIn.body.data.queue.id;

      const called = await biz(`/queue/${entryId}/call`, { expectedVersion: 1 }).expect(200);
      const skipped = await biz(`/queue/${entryId}/skip`, {
        expectedVersion: called.body.data.version,
        reason: 'Not present.',
      }).expect(200);
      expect(skipped.body.data.status).toBe('skipped');
      expect((await prisma.booking.findUnique({ where: { id: bookingId } }))?.status).toBe(
        'waiting',
      );

      const returned = await biz(`/queue/${entryId}/return-to-waiting`, {
        expectedVersion: skipped.body.data.version,
      }).expect(200);
      expect(returned.body.data.status).toBe('waiting');
    });

    it('enforces one in-service entry per staff (STAFF_NOT_AVAILABLE)', async () => {
      const a = await callFresh();
      await biz(`/queue/${a.entryId}/start-service`, {
        expectedVersion: a.version,
        staffId,
      }).expect(200);

      const b = await callFresh();
      const blocked = await biz(`/queue/${b.entryId}/start-service`, {
        expectedVersion: b.version,
        staffId,
      }).expect(422);
      expect(blocked.body.error.code).toBe('STAFF_NOT_AVAILABLE');

      // resolve both so nothing lingers called/in_service
      const aVersion = await versionOf(a.entryId);
      await biz(`/queue/${a.entryId}/complete`, { expectedVersion: aVersion }).expect(200);
      await biz(`/queue/${b.entryId}/skip`, { expectedVersion: b.version }).expect(200);
    });

    it('marks a called entry no-show and releases the slot', async () => {
      const { entryId, version } = await callFresh();
      const res = await biz(`/queue/${entryId}/no-show`, {
        expectedVersion: version,
        reason: 'No response.',
      }).expect(200);
      expect(res.body.data.status).toBe('no_show');
      const entry = await prisma.queueEntry.findUnique({ where: { id: entryId } });
      expect(entry?.status).toBe('no_show');
    });
  });

  describe('outlet snapshot (§82)', () => {
    it('exposes operational names and per-entry version but no phone numbers', async () => {
      const { bookingId, token } = await checkableBooking();
      await checkIn(token, bookingId).expect(200);
      const snap = await snapshot();

      expect(snap.businessDate).toBe(today);
      expect(snap.isOpen).toBe(true);
      expect(Array.isArray(snap.waiting)).toBe(true);
      const item = snap.waiting.find((e: { bookingId: string }) => e.bookingId === bookingId);
      expect(item).toBeDefined();
      expect(item.customer).toHaveProperty('name');
      expect(item).toHaveProperty('version');
      expect(JSON.stringify(item)).not.toContain('phone');
    });
  });

  describe('booking no-show before check-in (§68)', () => {
    it('marks a confirmed booking no_show and releases the slot', async () => {
      const customer = await registerUser();
      const created = await createBooking(customer.accessToken).expect(201);
      const bookingId = created.body.data.booking.id;

      const res = await biz(`/bookings/${bookingId}/no-show`, {
        reason: 'Did not arrive.',
      }).expect(200);
      expect(res.body.data.status).toBe('no_show');
      expect((await prisma.booking.findUnique({ where: { id: bookingId } }))?.status).toBe(
        'no_show',
      );
    });
  });

  describe('walk-in (§67)', () => {
    it('creates a walk_in booking + queue entry with the customer name in the snapshot', async () => {
      const res = await biz('/walk-ins', {
        outletId,
        customer: { name: 'Budi Walk', phoneNumber: '+628111' },
        serviceId,
        staffSelection: { mode: 'any_available' },
        paymentOption: 'pay_at_location',
      }).expect(201);

      expect(res.body.data.booking.type).toBe('walk_in');
      expect(res.body.data.booking.status).toBe('waiting');
      expect(res.body.data.queue.displayNumber).toMatch(/^A\d{3,}$/);

      const entryId = res.body.data.queue.id;
      const snap = await snapshot();
      const item = snap.waiting.find((e: { queueEntryId: string }) => e.queueEntryId === entryId);
      expect(item.customer.name).toBe('Budi Walk');
    });
  });

  describe('reorder (§90)', () => {
    it('reorders waiting entries and bumps the queue version; guards version + entries', async () => {
      const a = await checkableBooking();
      const b = await checkableBooking();
      const first = (await checkIn(a.token, a.bookingId).expect(200)).body.data.queue.id;
      const second = (await checkIn(b.token, b.bookingId).expect(200)).body.data.queue.id;

      const before = await snapshot();
      const bad = await biz(`/outlets/${outletId}/queue/reorder`, {
        businessDate: today,
        expectedQueueVersion: before.version,
        orderedQueueEntryIds: [first], // incomplete set
        reason: 'Priority.',
      }).expect(422);
      expect(bad.body.error.code).toBe('QUEUE_REORDER_INVALID_ENTRIES');

      // full reorderable set = every waiting + skipped entry (§33), swapped
      const reorderableIds = [...before.waiting, ...before.skipped].map(
        (e: { queueEntryId: string }) => e.queueEntryId,
      );
      expect(reorderableIds).toEqual(expect.arrayContaining([first, second]));
      const reordered = [...reorderableIds].reverse();
      const ok = await biz(`/outlets/${outletId}/queue/reorder`, {
        businessDate: today,
        expectedQueueVersion: before.version,
        orderedQueueEntryIds: reordered,
        reason: 'Priority customer.',
      }).expect(200);
      expect(ok.body.data.queueVersion).toBe(before.version + 1);

      const stale = await biz(`/outlets/${outletId}/queue/reorder`, {
        businessDate: today,
        expectedQueueVersion: before.version, // now stale
        orderedQueueEntryIds: reordered,
        reason: 'Again.',
      }).expect(409);
      expect(stale.body.error.code).toBe('QUEUE_VERSION_CONFLICT');
    });
  });

  describe('concurrency (§66)', () => {
    it('two concurrent check-ins create exactly one queue entry', async () => {
      const { bookingId, token } = await checkableBooking();
      const results = await Promise.allSettled([
        checkIn(token, bookingId, idem()),
        checkIn(token, bookingId, idem()),
      ]);
      const statuses = results.map((r) =>
        r.status === 'fulfilled' ? (r.value as request.Response).status : 0,
      );
      expect(statuses.filter((s) => s === 200)).toHaveLength(1);
      const count = await prisma.queueEntry.count({ where: { bookingId } });
      expect(count).toBe(1);
    });

    it('two simultaneous check-ins receive distinct queue numbers', async () => {
      // Both hit nextQueueNumber() at once; the atomic queue_counters upsert
      // must hand out two distinct numbers, never the same one twice.
      const [a, b] = await Promise.all([checkableBooking(), checkableBooking()]);
      const [ra, rb] = await Promise.all([
        checkIn(a.token, a.bookingId, idem()),
        checkIn(b.token, b.bookingId, idem()),
      ]);
      expect(ra.status).toBe(200);
      expect(rb.status).toBe(200);
      expect(ra.body.data.queue.queueNumber).not.toBe(rb.body.data.queue.queueNumber);
    });
  });
});
