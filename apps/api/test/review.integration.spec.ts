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

describe('Reviews (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;

  const uniqueEmail = (): string => `it-rev-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;
  const bookingDate = jakartaDateString(new Date(Date.now() + 24 * 60 * 60 * 1000));

  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;

  const registerUser = async (): Promise<{ userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Review User', email: uniqueEmail(), password: PASSWORD })
      .expect(201);
    return { userId: res.body.data.user.id, accessToken: res.body.data.session.accessToken };
  };

  let slotSeq = 0;
  const nextScheduledAt = (): string => {
    const n = slotSeq++;
    const date = addDays(bookingDate, Math.floor(n / 9));
    const hour = String(9 + (n % 9)).padStart(2, '0');
    return `${date}T${hour}:00:00+07:00`;
  };

  const createBooking = async (token: string): Promise<string> => {
    const res = await http()
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idem())
      .send({
        businessId,
        outletId,
        serviceId,
        staffSelection: { mode: 'specific_staff', staffId },
        scheduledAt: nextScheduledAt(),
        paymentOption: 'pay_at_location',
      })
      .expect(201);
    return res.body.data.booking.id as string;
  };

  /** Test seed: jump the booking straight to completed (review precondition). */
  const completedBooking = async (token: string): Promise<string> => {
    const bookingId = await createBooking(token);
    await prisma.bookingReservation.deleteMany({ where: { bookingId } });
    await prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'completed', completedAt: new Date() },
    });
    return bookingId;
  };

  const postReview = (
    token: string,
    bookingId: string,
    body: Record<string, unknown>,
    key = idem(),
  ) =>
    http()
      .post(`/api/v1/bookings/${bookingId}/review`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send(body);

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS = '0';
    process.env.OUTBOX_DISPATCHER_INTERVAL_MS = '0';
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
        name: `Review Barber ${randomUUID().slice(0, 8)}`,
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
  });

  describe('POST /bookings/{bookingId}/review (§96)', () => {
    it('creates a review and updates business + staff rating aggregates', async () => {
      const customer = await registerUser();
      const bookingId = await completedBooking(customer.accessToken);

      const res = await postReview(customer.accessToken, bookingId, {
        rating: 5,
        comment: 'Great service and short waiting time.',
      }).expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data).toMatchObject({
        bookingId,
        businessId,
        rating: 5,
        comment: 'Great service and short waiting time.',
        status: 'published',
      });
      expect(res.body.data.id).toMatch(/^rev_/);

      const detail = await http().get(`/api/v1/businesses/${businessId}`).expect(200);
      expect(detail.body.data.rating.count).toBeGreaterThanOrEqual(1);
      expect(detail.body.data.rating.average).toBeGreaterThan(0);

      const staff = await http().get(`/api/v1/businesses/${businessId}/staff`).expect(200);
      const reviewed = staff.body.data.items.find((s: { id: string }) => s.id === staffId);
      expect(reviewed.rating.count).toBeGreaterThanOrEqual(1);
      expect(reviewed.rating.average).toBeGreaterThan(0);
    });

    it('replays the same idempotency key without double-counting aggregates', async () => {
      const customer = await registerUser();
      const bookingId = await completedBooking(customer.accessToken);
      const key = idem();

      const first = await postReview(customer.accessToken, bookingId, { rating: 4 }, key).expect(
        201,
      );
      const before = await http().get(`/api/v1/businesses/${businessId}`).expect(200);

      const replay = await postReview(customer.accessToken, bookingId, { rating: 4 }, key).expect(
        201,
      );
      expect(replay.body.data.id).toBe(first.body.data.id);

      const after = await http().get(`/api/v1/businesses/${businessId}`).expect(200);
      expect(after.body.data.rating.count).toBe(before.body.data.rating.count);
    });

    it('rejects a second review for the same booking', async () => {
      const customer = await registerUser();
      const bookingId = await completedBooking(customer.accessToken);
      await postReview(customer.accessToken, bookingId, { rating: 5 }).expect(201);

      const res = await postReview(customer.accessToken, bookingId, { rating: 1 }).expect(409);
      expect(res.body.error.code).toBe('REVIEW_ALREADY_EXISTS');
    });

    it('rejects reviewing a booking that is not completed', async () => {
      const customer = await registerUser();
      const bookingId = await createBooking(customer.accessToken);

      const res = await postReview(customer.accessToken, bookingId, { rating: 5 }).expect(409);
      expect(res.body.error.code).toBe('REVIEW_BOOKING_NOT_COMPLETED');
    });

    it("rejects reviewing another customer's booking", async () => {
      const customer = await registerUser();
      const stranger = await registerUser();
      const bookingId = await completedBooking(customer.accessToken);

      const res = await postReview(stranger.accessToken, bookingId, { rating: 5 }).expect(403);
      expect(res.body.error.code).toBe('REVIEW_NOT_ALLOWED');
    });

    it('rejects an out-of-range rating', async () => {
      const customer = await registerUser();
      const bookingId = await completedBooking(customer.accessToken);

      const res = await postReview(customer.accessToken, bookingId, { rating: 6 }).expect(400);
      expect(res.body.error.code).toBe('REVIEW_RATING_INVALID');
    });

    it('requires an idempotency key', async () => {
      const customer = await registerUser();
      const bookingId = await completedBooking(customer.accessToken);

      const res = await http()
        .post(`/api/v1/bookings/${bookingId}/review`)
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .send({ rating: 5 })
        .expect(400);
      expect(res.body.error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
    });

    it('returns BOOKING_NOT_FOUND for an unknown booking', async () => {
      const customer = await registerUser();
      const res = await postReview(customer.accessToken, 'bkg_missing', { rating: 5 }).expect(404);
      expect(res.body.error.code).toBe('BOOKING_NOT_FOUND');
    });
  });

  describe('GET /businesses/{businessId}/reviews (§97, public)', () => {
    // Isolated business so summary/list assertions are exact.
    let listBusinessId: string;
    let listOutletId: string;
    let listServiceId: string;
    const reviewIds: string[] = [];

    beforeAll(async () => {
      const owner = await registerUser();
      const business = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: `List Barber ${randomUUID().slice(0, 8)}`,
          primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 11' } },
        })
        .expect(201);
      listBusinessId = business.body.data.id;
      listOutletId = business.body.data.primaryOutlet.id;

      await http()
        .put(`/api/v1/businesses/${listBusinessId}/outlets/${listOutletId}/operating-hours`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
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
        .post(`/api/v1/businesses/${listBusinessId}/services`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({ name: 'Shave', durationMinutes: 30, price: { amount: 30000, currency: 'IDR' } })
        .expect(201);
      listServiceId = svc.body.data.id;

      // Three published reviews (5, 3, 4) in that creation order. The list
      // business has no staff, so completed bookings are seeded via prisma.
      for (const rating of [5, 3, 4]) {
        const customer = await registerUser();
        const bookingId = `bkg_it${randomUUID().replace(/-/g, '').slice(0, 20)}`;
        await prisma.booking.create({
          data: {
            id: bookingId,
            bookingCode: `ANT-TEST-${randomUUID().slice(0, 8)}`,
            customerUserId: customer.userId,
            businessId: listBusinessId,
            outletId: listOutletId,
            serviceId: listServiceId,
            bookingType: 'scheduled',
            status: 'completed',
            completedAt: new Date(),
            scheduledAt: new Date(),
            expectedEndsAt: new Date(Date.now() + 30 * 60 * 1000),
            paymentOption: 'pay_at_location',
            businessDate: new Date(`${bookingDate}T00:00:00Z`),
          },
        });
        const created = await postReview(customer.accessToken, bookingId, {
          rating,
          comment: `Rated ${rating}`,
        }).expect(201);
        reviewIds.push(created.body.data.id as string);
      }
    });

    it('returns summary + newest-first items without exposing customer identity', async () => {
      const res = await http().get(`/api/v1/businesses/${listBusinessId}/reviews`).expect(200);

      expect(res.body.data.summary).toEqual({
        average: 4,
        count: 3,
        distribution: { '5': 1, '4': 1, '3': 1, '2': 0, '1': 0 },
      });
      const items = res.body.data.items as Array<Record<string, unknown>>;
      expect(items.map((i) => i.rating)).toEqual([4, 3, 5]);
      expect(items[0].customer).toEqual({ displayName: expect.any(String) });
      expect(JSON.stringify(items)).not.toContain('@example.com');
      expect(res.body.meta.pagination).toMatchObject({ hasMore: false, nextCursor: null });
    });

    it('filters by rating and sorts by rating', async () => {
      const filtered = await http()
        .get(`/api/v1/businesses/${listBusinessId}/reviews?rating=5`)
        .expect(200);
      expect(filtered.body.data.items).toHaveLength(1);
      expect(filtered.body.data.items[0].rating).toBe(5);

      const asc = await http()
        .get(`/api/v1/businesses/${listBusinessId}/reviews?sort=rating_asc`)
        .expect(200);
      expect((asc.body.data.items as Array<{ rating: number }>).map((i) => i.rating)).toEqual([
        3, 4, 5,
      ]);
    });

    it('paginates with an opaque cursor', async () => {
      const first = await http()
        .get(`/api/v1/businesses/${listBusinessId}/reviews?limit=2`)
        .expect(200);
      expect(first.body.data.items).toHaveLength(2);
      expect(first.body.meta.pagination.hasMore).toBe(true);

      const second = await http()
        .get(
          `/api/v1/businesses/${listBusinessId}/reviews?limit=2&cursor=${first.body.meta.pagination.nextCursor}`,
        )
        .expect(200);
      expect(second.body.data.items).toHaveLength(1);
      expect(second.body.meta.pagination.hasMore).toBe(false);
      const seen = [
        ...first.body.data.items.map((i: { id: string }) => i.id),
        ...second.body.data.items.map((i: { id: string }) => i.id),
      ];
      expect(new Set(seen).size).toBe(3);
    });

    it('excludes non-published reviews from summary and items', async () => {
      await prisma.review.update({
        where: { id: reviewIds[0] },
        data: { status: 'hidden', moderatedAt: new Date() },
      });

      const res = await http().get(`/api/v1/businesses/${listBusinessId}/reviews`).expect(200);
      expect(res.body.data.summary.count).toBe(2);
      expect((res.body.data.items as Array<{ id: string }>).map((i) => i.id)).not.toContain(
        reviewIds[0],
      );

      await prisma.review.update({
        where: { id: reviewIds[0] },
        data: { status: 'published', moderatedAt: null },
      });
    });

    it('returns BUSINESS_NOT_FOUND for an unknown business', async () => {
      const res = await http().get('/api/v1/businesses/biz_missing/reviews').expect(404);
      expect(res.body.error.code).toBe('BUSINESS_NOT_FOUND');
    });
  });
});
