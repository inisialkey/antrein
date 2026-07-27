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

describe('Booking endpoints (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;

  const uniqueEmail = (): string => `it-bkg-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;

  const today = jakartaDateString(new Date());
  const target = addDays(today, 7);
  const targetCompact = target.replaceAll('-', '');
  const at = (time: string, date = target): string => `${date}T${time}:00+07:00`;

  let ownerToken: string;
  let customerToken: string;
  let customerId: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;
  let barberToken: string;

  const registerUser = async (
    emailAddr = uniqueEmail(),
  ): Promise<{ email: string; userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Booking User', email: emailAddr, password: PASSWORD })
      .expect(201);
    return {
      email: emailAddr,
      userId: res.body.data.user.id,
      accessToken: res.body.data.session.accessToken,
    };
  };

  const inviteStaff = async (
    eligibleServiceIds: string[],
  ): Promise<{ staffId: string; accessToken: string }> => {
    const inviteeEmail = uniqueEmail();
    const invite = await http()
      .post(`/api/v1/businesses/${businessId}/staff/invitations`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        email: inviteeEmail,
        displayName: 'Barber',
        role: 'barber',
        outletIds: [outletId],
        eligibleServiceIds,
      })
      .expect(201);
    const invitee = await registerUser(inviteeEmail);
    const accept = await http()
      .post(`/api/v1/staff/invitations/${invite.body.data.invitationId}/accept`)
      .set('Authorization', `Bearer ${invitee.accessToken}`)
      .set('Idempotency-Key', idem())
      .expect(200);
    return { staffId: accept.body.data.staffId as string, accessToken: invitee.accessToken };
  };

  const createBooking = (
    token: string,
    body: Record<string, unknown>,
    key = idem(),
  ): request.Test =>
    http()
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send(body);

  const bookingBody = (time: string, overrides: Record<string, unknown> = {}) => ({
    businessId,
    outletId,
    serviceId,
    staffSelection: { mode: 'specific_staff', staffId },
    scheduledAt: at(time),
    paymentOption: 'pay_at_location',
    ...overrides,
  });

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(new SilentEmail())
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    http = () => request(app.getHttpServer());

    const owner = await registerUser();
    ownerToken = owner.accessToken;
    const customer = await registerUser();
    customerToken = customer.accessToken;
    customerId = customer.userId;

    const biz = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `Booking Barber ${randomUUID().slice(0, 8)}`,
        primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 10' } },
      })
      .expect(201);
    businessId = biz.body.data.id;
    outletId = biz.body.data.primaryOutlet.id;

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

    const staff = await inviteStaff([serviceId]);
    staffId = staff.staffId;
    barberToken = staff.accessToken;
  });

  afterAll(async () => {
    await app.close();
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
  });

  let bookingId: string;
  let palPaymentId: string;

  describe('create booking (pay at location)', () => {
    it('creates a confirmed booking with snapshot, code, reservation and payment row', async () => {
      const key = idem();
      const res = await createBooking(
        customerToken,
        bookingBody('10:00', { customerNotes: 'Scissors only.' }),
        key,
      ).expect(201);

      const booking = res.body.data.booking;
      bookingId = booking.id;
      expect(booking.id).toMatch(/^bkg_/);
      expect(booking.bookingCode).toBe(`ANT-${targetCompact}-0001`);
      expect(booking.status).toBe('confirmed');
      expect(booking.type).toBe('scheduled');
      expect(booking.scheduledAt).toBe(new Date(at('10:00')).toISOString());
      expect(booking.expectedEndsAt).toBe(new Date(at('10:45')).toISOString());
      expect(booking.service).toMatchObject({
        id: serviceId,
        name: 'Haircut',
        durationMinutes: 45,
        price: { amount: 50000, currency: 'IDR' },
      });
      expect(booking.staff).toMatchObject({ id: staffId, name: 'Barber' });
      expect(booking.paymentSummary).toEqual({
        totalAmount: { amount: 50000, currency: 'IDR' },
        requiredNow: { amount: 0, currency: 'IDR' },
        paidAmount: { amount: 0, currency: 'IDR' },
        remainingAmount: { amount: 50000, currency: 'IDR' },
        status: 'unpaid',
      });
      expect(booking.cancellation.canCancel).toBe(true);
      expect(booking.cancellation.deadlineAt).toBe(new Date(at('04:00')).toISOString());
      expect(res.body.data.payment).toBeNull();

      // Idempotent replay returns the same booking.
      const replay = await createBooking(
        customerToken,
        bookingBody('10:00', { customerNotes: 'Scissors only.' }),
        key,
      ).expect(201);
      expect(replay.body.data.booking.id).toBe(bookingId);

      // Same key, different payload → conflict.
      const reused = await createBooking(
        customerToken,
        bookingBody('11:00', { customerNotes: 'Scissors only.' }),
        key,
      ).expect(409);
      expect(reused.body.error.code).toBe('IDEMPOTENCY_KEY_REUSED');

      const payments = await http()
        .get(`/api/v1/bookings/${bookingId}/payments`)
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);
      expect(payments.body.data.items).toHaveLength(1);
      expect(payments.body.data.items[0]).toMatchObject({
        provider: 'pay_at_location',
        status: 'pending',
        amount: { amount: 50000, currency: 'IDR' },
      });
      palPaymentId = payments.body.data.items[0].id;
    });

    it('requires an idempotency key and authentication', async () => {
      await http().post('/api/v1/bookings').send(bookingBody('12:00')).expect(401);
      const res = await http()
        .post('/api/v1/bookings')
        .set('Authorization', `Bearer ${customerToken}`)
        .send(bookingBody('12:00'))
        .expect(400);
      expect(res.body.error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
    });

    it('rejects overlapping bookings for the same staff, allows back-to-back', async () => {
      const other = await registerUser();
      const overlap = await createBooking(other.accessToken, bookingBody('10:30')).expect(409);
      expect(overlap.body.error.code).toBe('BOOKING_SLOT_UNAVAILABLE');

      await createBooking(other.accessToken, bookingBody('10:45')).expect(201);
    });

    it('lets exactly one of two concurrent same-slot requests win', async () => {
      const [a, b] = await Promise.all([
        registerUser().then((u) => createBooking(u.accessToken, bookingBody('16:00'))),
        registerUser().then((u) => createBooking(u.accessToken, bookingBody('16:00'))),
      ]);
      const statuses = [a.status, b.status].sort();
      expect(statuses).toEqual([201, 409]);
      const loser = a.status === 409 ? a : b;
      expect(loser.body.error.code).toBe('BOOKING_SLOT_UNAVAILABLE');
    });

    it('validates dates, hours, options, staff and references', async () => {
      const expectError = async (
        body: Record<string, unknown>,
        status: number,
        code: string,
      ): Promise<void> => {
        const res = await createBooking(customerToken, body).expect(status);
        expect(res.body.error.code).toBe(code);
      };

      await expectError(
        bookingBody('10:00', { scheduledAt: at('10:00', addDays(today, -1)) }),
        400,
        'BOOKING_DATE_IN_PAST',
      );
      await expectError(
        { ...bookingBody('10:00'), scheduledAt: new Date(Date.now() + 10 * 60_000).toISOString() },
        400,
        'BOOKING_LEAD_TIME_NOT_MET',
      );
      await expectError(
        bookingBody('10:00', { scheduledAt: at('10:00', addDays(today, 40)) }),
        400,
        'BOOKING_HORIZON_EXCEEDED',
      );
      // Outside outlet operating hours (ends after closing).
      await expectError(bookingBody('17:30'), 409, 'BOOKING_SLOT_UNAVAILABLE');
      await expectError(
        bookingBody('10:00', { paymentOption: 'full_payment' }),
        422,
        'PAYMENT_OPTION_NOT_AVAILABLE',
      );
      await expectError(
        bookingBody('12:00', { staffSelection: { mode: 'any_available' } }),
        400,
        'VALIDATION_FAILED',
      );
      await expectError(
        bookingBody('12:00', { businessId: 'biz_missing' }),
        404,
        'BUSINESS_NOT_FOUND',
      );

      // Closed date blocks the whole day.
      const closedDate = addDays(today, 8);
      await http()
        .post(`/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ date: closedDate })
        .expect(201);
      await expectError(
        bookingBody('10:00', { scheduledAt: at('10:00', closedDate) }),
        409,
        'BOOKING_SLOT_UNAVAILABLE',
      );

      // Staff not linked to the service is not eligible.
      const svc2 = await http()
        .post(`/api/v1/businesses/${businessId}/services`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ name: 'Shave', durationMinutes: 30, price: { amount: 30000, currency: 'IDR' } })
        .expect(201);
      await inviteStaff([svc2.body.data.id]);
      await expectError(
        bookingBody('12:00', { serviceId: svc2.body.data.id }),
        400,
        'STAFF_NOT_ELIGIBLE_FOR_SERVICE',
      );
    });

    it('enforces the active booking limit per customer per business', async () => {
      const heavy = await registerUser();
      await createBooking(heavy.accessToken, bookingBody('13:00')).expect(201);
      await createBooking(heavy.accessToken, bookingBody('14:00')).expect(201);
      await createBooking(heavy.accessToken, bookingBody('15:00')).expect(201);
      const limited = await createBooking(heavy.accessToken, bookingBody('12:00')).expect(409);
      expect(limited.body.error.code).toBe('BOOKING_ACTIVE_LIMIT_REACHED');
    });

    it('holds the active limit under concurrent creates by the same customer', async () => {
      const heavy = await registerUser();
      const dateB = addDays(today, 9);
      await createBooking(heavy.accessToken, {
        ...bookingBody('10:00'),
        scheduledAt: at('10:00', dateB),
      }).expect(201);
      await createBooking(heavy.accessToken, {
        ...bookingBody('11:00'),
        scheduledAt: at('11:00', dateB),
      }).expect(201);

      // Third and fourth race for the last remaining slot in the limit.
      const [a, b] = await Promise.all([
        createBooking(heavy.accessToken, {
          ...bookingBody('12:00'),
          scheduledAt: at('12:00', dateB),
        }),
        createBooking(heavy.accessToken, {
          ...bookingBody('13:00'),
          scheduledAt: at('13:00', dateB),
        }),
      ]);
      expect([a.status, b.status].sort()).toEqual([201, 409]);
      const loser = a.status === 409 ? a : b;
      expect(loser.body.error.code).toBe('BOOKING_ACTIVE_LIMIT_REACHED');
    });
  });

  describe('cancellation', () => {
    it('customer cancel releases the reservation and cancels pending payment', async () => {
      const mine = await registerUser();
      const created = await createBooking(mine.accessToken, bookingBody('12:00')).expect(201);
      const id = created.body.data.booking.id;

      const key = idem();
      const cancelled = await http()
        .post(`/api/v1/bookings/${id}/cancel`)
        .set('Authorization', `Bearer ${mine.accessToken}`)
        .set('Idempotency-Key', key)
        .send({ reasonCode: 'customer_changed_plan', reason: 'No longer available.' })
        .expect(200);
      expect(cancelled.body.data).toMatchObject({
        bookingId: id,
        status: 'cancelled',
        refund: { required: false },
      });

      // Idempotent replay.
      const replay = await http()
        .post(`/api/v1/bookings/${id}/cancel`)
        .set('Authorization', `Bearer ${mine.accessToken}`)
        .set('Idempotency-Key', key)
        .send({ reasonCode: 'customer_changed_plan', reason: 'No longer available.' })
        .expect(200);
      expect(replay.body.data.status).toBe('cancelled');

      // New key on an already-cancelled booking → conflict.
      const again = await http()
        .post(`/api/v1/bookings/${id}/cancel`)
        .set('Authorization', `Bearer ${mine.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({})
        .expect(409);
      expect(again.body.error.code).toBe('BOOKING_ALREADY_CANCELLED');

      const detail = await http()
        .get(`/api/v1/bookings/${id}`)
        .set('Authorization', `Bearer ${mine.accessToken}`)
        .expect(200);
      expect(detail.body.data.status).toBe('cancelled');
      expect(detail.body.data.cancellation.canCancel).toBe(false);

      const payments = await http()
        .get(`/api/v1/bookings/${id}/payments`)
        .set('Authorization', `Bearer ${mine.accessToken}`)
        .expect(200);
      expect(payments.body.data.items[0].status).toBe('cancelled');

      // The slot is bookable again — the reservation row is gone.
      await createBooking(mine.accessToken, bookingBody('12:00')).expect(201);
    });

    it('cancel is owner-only', async () => {
      const outsider = await registerUser();
      const res = await http()
        .post(`/api/v1/bookings/${bookingId}/cancel`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({})
        .expect(403);
      expect(res.body.error.code).toBe('FORBIDDEN_BOOKING_RESOURCE');
    });

    it('business cancel requires booking.manage and a reason', async () => {
      const mine = await registerUser();
      const created = await createBooking(mine.accessToken, bookingBody('09:00')).expect(201);
      const id = created.body.data.booking.id;

      await http()
        .post(`/api/v1/businesses/${businessId}/bookings/${id}/cancel`)
        .set('Authorization', `Bearer ${barberToken}`)
        .set('Idempotency-Key', idem())
        .send({ reasonCode: 'business_unavailable', reason: 'Staff ill.' })
        .expect(403);

      const noReason = await http()
        .post(`/api/v1/businesses/${businessId}/bookings/${id}/cancel`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({})
        .expect(400);
      expect(noReason.body.error.code).toBe('VALIDATION_FAILED');

      const cancelled = await http()
        .post(`/api/v1/businesses/${businessId}/bookings/${id}/cancel`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ reasonCode: 'business_unavailable', reason: 'Staff ill.' })
        .expect(200);
      expect(cancelled.body.data.status).toBe('cancelled');
    });
  });

  describe('pay-at-location confirmation', () => {
    it('validates amount and currency, confirms once, then conflicts', async () => {
      const mismatch = await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 40000, currency: 'IDR' }, method: 'cash' })
        .expect(409);
      expect(mismatch.body.error.code).toBe('PAYMENT_AMOUNT_MISMATCH');

      const currency = await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 50000, currency: 'USD' }, method: 'cash' })
        .expect(409);
      expect(currency.body.error.code).toBe('PAYMENT_CURRENCY_MISMATCH');

      // Barber role has no payment.confirm permission.
      await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${barberToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 50000, currency: 'IDR' }, method: 'cash' })
        .expect(403);

      const key = idem();
      const confirmed = await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', key)
        .send({ amount: { amount: 50000, currency: 'IDR' }, method: 'cash', note: 'Front desk.' })
        .expect(200);
      expect(confirmed.body.data.payment).toMatchObject({ status: 'paid', method: 'cash' });
      expect(confirmed.body.data.bookingPaymentSummary).toMatchObject({
        paidAmount: { amount: 50000, currency: 'IDR' },
        remainingAmount: { amount: 0, currency: 'IDR' },
        status: 'paid',
      });

      // Idempotent replay, then a fresh attempt conflicts.
      await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', key)
        .send({ amount: { amount: 50000, currency: 'IDR' }, method: 'cash', note: 'Front desk.' })
        .expect(200);
      const repeat = await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 0, currency: 'IDR' }, method: 'cash' })
        .expect(409);
      expect(repeat.body.error.code).toBe('PAYMENT_ALREADY_PAID');

      // Booking stays confirmed — completion is independent of balance (ADR 0032).
      const detail = await http()
        .get(`/api/v1/bookings/${bookingId}`)
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);
      expect(detail.body.data.status).toBe('confirmed');
      expect(detail.body.data.paymentSummary.status).toBe('paid');
    });

    it('payment reads are scoped to owner and business members', async () => {
      await http()
        .get(`/api/v1/payments/${palPaymentId}`)
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);
      await http()
        .get(`/api/v1/payments/${palPaymentId}`)
        .set('Authorization', `Bearer ${barberToken}`)
        .expect(200);
      const outsider = await registerUser();
      const res = await http()
        .get(`/api/v1/payments/${palPaymentId}`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .expect(404);
      expect(res.body.error.code).toBe('PAYMENT_NOT_FOUND');
    });
  });

  describe('lists and business reads', () => {
    it('lists customer bookings with filters and cursor pagination', async () => {
      const all = await http()
        .get('/api/v1/bookings')
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);
      expect(all.body.data.items.length).toBeGreaterThanOrEqual(1);
      expect(
        all.body.data.items.every(
          (b: { customer: { id: string } }) => b.customer.id === customerId,
        ),
      ).toBe(true);

      const paged = await http()
        .get('/api/v1/bookings?limit=1')
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);
      expect(paged.body.data.items).toHaveLength(1);
      expect(paged.body.meta.pagination.limit).toBe(1);

      const filtered = await http()
        .get('/api/v1/bookings?status=cancelled')
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);
      expect(
        filtered.body.data.items.every((b: { status: string }) => b.status === 'cancelled'),
      ).toBe(true);
    });

    it('lists business bookings with filters; barber can read, outsider cannot', async () => {
      const list = await http()
        .get(`/api/v1/businesses/${businessId}/bookings?date=${target}`)
        .set('Authorization', `Bearer ${barberToken}`)
        .expect(200);
      expect(list.body.data.items.length).toBeGreaterThanOrEqual(3);
      expect(
        list.body.data.items.every((b: { bookingCode: string }) =>
          new RegExp(`^ANT-${targetCompact}-\\d{4,}$`).test(b.bookingCode),
        ),
      ).toBe(true);

      const paid = await http()
        .get(`/api/v1/businesses/${businessId}/bookings?paymentStatus=paid`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);
      expect(paid.body.data.items.map((b: { id: string }) => b.id)).toContain(bookingId);

      const outsider = await registerUser();
      await http()
        .get(`/api/v1/businesses/${businessId}/bookings`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .expect(403);
    });

    it('business booking detail exposes customer contact and internal notes field', async () => {
      const detail = await http()
        .get(`/api/v1/businesses/${businessId}/bookings/${bookingId}`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);
      expect(detail.body.data.customer.id).toBe(customerId);
      expect(detail.body.data).toHaveProperty('internalNotes');

      const foreign = await http()
        .get(`/api/v1/businesses/${businessId}/bookings/bkg_missing`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(404);
      expect(foreign.body.error.code).toBe('BOOKING_NOT_FOUND');
    });

    it('customer cannot read a foreign booking', async () => {
      const outsider = await registerUser();
      const res = await http()
        .get(`/api/v1/bookings/${bookingId}`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .expect(403);
      expect(res.body.error.code).toBe('FORBIDDEN_BOOKING_RESOURCE');
    });
  });
});
