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
import { jakartaDateString } from '../src/modules/schedules/slots';

jest.setTimeout(120_000);

class SilentEmail extends EmailPort {
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(_input: StaffInvitationEmailInput): Promise<void> {}
}

const PASSWORD = 'integration-password-1';

describe('Reports (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;

  const uniqueEmail = (): string => `it-rpt-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;
  const reportDate = jakartaDateString(new Date());
  const businessDate = new Date(`${reportDate}T00:00:00Z`);

  let ownerToken: string;
  let ownerUserId: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;

  const registerUser = async (): Promise<{ userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Report User', email: uniqueEmail(), password: PASSWORD })
      .expect(201);
    return { userId: res.body.data.user.id, accessToken: res.body.data.session.accessToken };
  };

  /** Seed a booking row for the report day directly (reports are read-only). */
  const seedBooking = async (
    status: string,
    extras: Record<string, unknown> = {},
  ): Promise<string> => {
    const id = `bkg_it${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    await prisma.booking.create({
      data: {
        id,
        bookingCode: `ANT-TEST-${randomUUID().slice(0, 12)}`,
        customerUserId: ownerUserId,
        businessId,
        outletId,
        serviceId,
        bookingType: 'scheduled',
        status,
        scheduledAt: new Date(),
        expectedEndsAt: new Date(Date.now() + 45 * 60 * 1000),
        paymentOption: 'pay_at_location',
        businessDate,
        ...extras,
      },
    });
    return id;
  };

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
    ownerUserId = owner.userId;

    const business = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `Report Barber ${randomUUID().slice(0, 8)}`,
        primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 12' } },
      })
      .expect(201);
    businessId = business.body.data.id;
    outletId = business.body.data.primaryOutlet.id;

    const svc = await http()
      .post(`/api/v1/businesses/${businessId}/services`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({ name: 'Haircut', durationMinutes: 45, price: { amount: 50000, currency: 'IDR' } })
      .expect(201);
    serviceId = svc.body.data.id;

    // Bookings: 2 confirmed, 1 waiting, 1 in_service, 1 completed, 1 cancelled, 1 no_show.
    await seedBooking('confirmed');
    await seedBooking('confirmed');
    const waitingId = await seedBooking('waiting', { checkedInAt: new Date() });
    const inServiceId = await seedBooking('in_service', { checkedInAt: new Date() });
    const completedId = await seedBooking('completed', { completedAt: new Date() });
    await seedBooking('cancelled', { cancelledAt: new Date() });
    await seedBooking('no_show', { noShowAt: new Date() });

    // Queue entries: waiting + in_service are active; the in_service one waited
    // exactly 10 minutes (checked_in → called).
    const checkedInAt = new Date(Date.now() - 30 * 60 * 1000);
    const calledAt = new Date(checkedInAt.getTime() + 10 * 60 * 1000);
    let queueNumber = 0;
    const seedEntry = async (
      bookingId: string,
      status: string,
      extras: Record<string, unknown> = {},
    ): Promise<void> => {
      queueNumber += 1;
      await prisma.queueEntry.create({
        data: {
          id: `que_it${randomUUID().replace(/-/g, '').slice(0, 20)}`,
          bookingId,
          businessId,
          outletId,
          businessDate,
          queueNumber,
          displayNumber: `A${String(queueNumber).padStart(3, '0')}`,
          status,
          sortOrder: queueNumber * 100,
          checkedInAt,
          ...extras,
        },
      });
    };
    await seedEntry(waitingId, 'waiting');
    await seedEntry(inServiceId, 'in_service', { calledAt, serviceStartedAt: new Date() });
    await seedEntry(completedId, 'completed', { calledAt, completedAt: new Date() });

    // Payments: 150k paid, 75k pending; refunds: 25k refunded.
    const seedPayment = async (
      bookingId: string,
      status: string,
      amount: number,
      extras: Record<string, unknown> = {},
    ): Promise<string> => {
      const id = `pay_it${randomUUID().replace(/-/g, '').slice(0, 20)}`;
      await prisma.payment.create({
        data: {
          id,
          bookingId,
          businessId,
          customerUserId: ownerUserId,
          provider: 'sandbox',
          paymentOption: 'full_payment',
          status,
          amount,
          currency: 'IDR',
          ...extras,
        },
      });
      return id;
    };
    const paidId = await seedPayment(completedId, 'paid', 150000, { paidAt: new Date() });
    await seedPayment(waitingId, 'pending', 75000);
    await prisma.refund.create({
      data: {
        id: `rfd_it${randomUUID().replace(/-/g, '').slice(0, 20)}`,
        paymentId: paidId,
        bookingId: completedId,
        businessId,
        status: 'refunded',
        amount: 25000,
        currency: 'IDR',
        reasonCode: 'customer_cancellation',
        requestedAt: new Date(),
        processedAt: new Date(),
      },
    });
  });

  afterAll(async () => {
    await app.close();
  });

  describe('GET /businesses/{businessId}/reports/daily-summary (§98)', () => {
    it('returns booking, queue, and payment aggregates for the outlet day', async () => {
      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/reports/daily-summary?outletId=${outletId}&date=${reportDate}`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);

      expect(res.body.data).toEqual({
        businessId,
        outletId,
        date: reportDate,
        timezone: 'Asia/Jakarta',
        bookings: {
          total: 7,
          confirmed: 2,
          waiting: 1,
          inService: 1,
          completed: 1,
          cancelled: 1,
          noShow: 1,
        },
        queue: {
          active: 2,
          averageWaitMinutes: 10,
        },
        payments: {
          grossPaid: { amount: 150000, currency: 'IDR' },
          pending: { amount: 75000, currency: 'IDR' },
          refunded: { amount: 25000, currency: 'IDR' },
        },
      });
    });

    it('defaults the date to today (Asia/Jakarta)', async () => {
      const res = await http()
        .get(`/api/v1/businesses/${businessId}/reports/daily-summary?outletId=${outletId}`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);
      expect(res.body.data.date).toBe(reportDate);
      expect(res.body.data.bookings.total).toBe(7);
    });

    it('rejects a non-member', async () => {
      const stranger = await registerUser();
      const res = await http()
        .get(`/api/v1/businesses/${businessId}/reports/daily-summary?outletId=${outletId}`)
        .set('Authorization', `Bearer ${stranger.accessToken}`)
        .expect(403);
      expect(res.body.success).toBe(false);
    });

    it("rejects another business's outlet", async () => {
      const otherOwner = await registerUser();
      const other = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${otherOwner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: `Other Barber ${randomUUID().slice(0, 8)}`,
          primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 13' } },
        })
        .expect(201);

      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/reports/daily-summary?outletId=${other.body.data.primaryOutlet.id}`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(404);
      expect(res.body.error.code).toBe('OUTLET_NOT_FOUND');
    });

    it('requires outletId', async () => {
      await http()
        .get(`/api/v1/businesses/${businessId}/reports/daily-summary`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(400);
    });
  });
});
