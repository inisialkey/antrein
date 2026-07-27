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
import { PaymentProviderPort } from '../src/infrastructure/payments/payment-provider.port';
import {
  SandboxPaymentAdapter,
  signSandboxWebhook,
} from '../src/infrastructure/payments/sandbox.adapter';
import { PrismaService } from '../src/infrastructure/database/prisma.service';
import { ConsistencyCheckJob } from '../src/modules/bookings/consistency-check.job';
import { PaymentReconciliationJob } from '../src/modules/bookings/payment-reconciliation.job';
import { addDays, jakartaDateString } from '../src/modules/schedules/slots';

jest.setTimeout(120_000);

class SilentEmail extends EmailPort {
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(_input: StaffInvitationEmailInput): Promise<void> {}
}

const PASSWORD = 'integration-password-1';
const WEBHOOK_SECRET = 'sandbox-webhook-secret';
const METRICS_TOKEN = 'metrics-scrape-token';
const ALL_DAYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;

describe('Hardening: reconciliation, consistency, metrics (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;
  let sandbox: SandboxPaymentAdapter;
  let reconciliation: PaymentReconciliationJob;
  let consistency: ConsistencyCheckJob;

  const uniqueEmail = (): string => `it-hard-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;

  const today = jakartaDateString(new Date());
  const target = addDays(today, 7);
  const at = (time: string): string => `${target}T${time}:00+07:00`;

  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;

  const registerUser = async (
    emailAddr = uniqueEmail(),
  ): Promise<{ email: string; userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Hardening User', email: emailAddr, password: PASSWORD })
      .expect(201);
    return {
      email: emailAddr,
      userId: res.body.data.user.id,
      accessToken: res.body.data.session.accessToken,
    };
  };

  const newCustomer = async (): Promise<string> => (await registerUser()).accessToken;

  const createBooking = (token: string, body: Record<string, unknown>): request.Test =>
    http()
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idem())
      .send(body);

  const bookingBody = (time: string, overrides: Record<string, unknown> = {}) => ({
    businessId,
    outletId,
    serviceId,
    staffSelection: { mode: 'specific_staff', staffId },
    scheduledAt: at(time),
    paymentOption: 'full_payment',
    ...overrides,
  });

  const webhook = (event: Record<string, unknown>): request.Test => {
    const raw = JSON.stringify(event);
    return http()
      .post('/api/v1/webhooks/payments/sandbox')
      .set('Content-Type', 'application/json')
      .set('x-sandbox-signature', signSandboxWebhook(Buffer.from(raw), WEBHOOK_SECRET))
      .send(raw);
  };

  const paidEvent = (providerReference: string, amount: number): Record<string, unknown> => ({
    eventId: `evt_${randomUUID()}`,
    type: 'payment.paid',
    providerReference,
    status: 'paid',
    amount,
    currency: 'IDR',
    occurredAt: new Date().toISOString(),
  });

  /** Backdates a payment so the reconciliation min-age filter picks it up. */
  const agePayment = (paymentId: string): Promise<unknown> =>
    prisma.payment.update({
      where: { id: paymentId },
      data: { createdAt: new Date(Date.now() - 5 * 60_000) },
    });

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS = '0';
    process.env.PAYMENT_WEBHOOK_SECRET = WEBHOOK_SECRET;
    process.env.PAYMENT_PROVIDER = 'sandbox';
    process.env.METRICS_ENABLED = 'true';
    process.env.METRICS_TOKEN = METRICS_TOKEN;
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(new SilentEmail())
      .compile();
    app = moduleRef.createNestApplication({ rawBody: true });
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    http = () => request(app.getHttpServer());
    prisma = app.get(PrismaService);
    sandbox = app.get(PaymentProviderPort) as SandboxPaymentAdapter;
    reconciliation = app.get(PaymentReconciliationJob);
    consistency = app.get(ConsistencyCheckJob);

    const owner = await registerUser();
    ownerToken = owner.accessToken;

    const biz = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `Hardening Barber ${randomUUID().slice(0, 8)}`,
        primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 12' } },
      })
      .expect(201);
    businessId = biz.body.data.id;
    outletId = biz.body.data.primaryOutlet.id;

    await http()
      .patch(`/api/v1/businesses/${businessId}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ supportedPaymentOptions: ['pay_at_location', 'full_payment', 'deposit'] })
      .expect(200);

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
        displayName: 'Barber',
        role: 'barber',
        outletIds: [outletId],
        eligibleServiceIds: [serviceId],
      })
      .expect(201);
    const invitee = await registerUser(inviteeEmail);
    const accept = await http()
      .post(`/api/v1/staff/invitations/${invite.body.data.invitationId}/accept`)
      .set('Authorization', `Bearer ${invitee.accessToken}`)
      .set('Idempotency-Key', idem())
      .expect(200);
    staffId = accept.body.data.staffId as string;
  });

  afterAll(async () => {
    await app.close();
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
    delete process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS;
    delete process.env.PAYMENT_WEBHOOK_SECRET;
    delete process.env.PAYMENT_PROVIDER;
    delete process.env.METRICS_ENABLED;
    delete process.env.METRICS_TOKEN;
  });

  describe('payment reconciliation (§42/§81)', () => {
    it('confirms a stale pending payment the provider settled without a webhook', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('09:00')).expect(201);
      const bookingId = res.body.data.booking.id as string;
      const paymentId = res.body.data.payment.id as string;

      sandbox.simulateStatus(`sbx_${paymentId}`, 'paid');
      await agePayment(paymentId);

      const result = await reconciliation.runOnce();
      expect(result.payments).toBeGreaterThanOrEqual(1);

      const payment = await prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
      expect(payment.status).toBe('paid');
      const booking = await prisma.booking.findUniqueOrThrow({ where: { id: bookingId } });
      expect(booking.status).toBe('confirmed');
    });

    it('leaves a provider-pending payment untouched (deterministic event id dedupes)', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('10:00')).expect(201);
      const paymentId = res.body.data.payment.id as string;
      await agePayment(paymentId);

      await reconciliation.runOnce();

      const payment = await prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
      expect(payment.status).toBe('pending');
    });

    it('re-settles a refund stuck in refund_pending after a provider outage', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('11:00')).expect(201);
      const bookingId = res.body.data.booking.id as string;
      const paymentId = res.body.data.payment.id as string;
      await webhook(paidEvent(`sbx_${paymentId}`, 50000)).expect(200);

      sandbox.failNextRefund();
      const cancelled = await http()
        .post(`/api/v1/bookings/${bookingId}/cancel`)
        .set('Authorization', `Bearer ${token}`)
        .set('Idempotency-Key', idem())
        .send({})
        .expect(200);
      const refundId = cancelled.body.data.refund.id as string;

      const stuck = await prisma.refund.findUniqueOrThrow({ where: { id: refundId } });
      expect(stuck.status).toBe('refund_pending');

      await prisma.refund.update({
        where: { id: refundId },
        data: { requestedAt: new Date(Date.now() - 5 * 60_000) },
      });

      const result = await reconciliation.runOnce();
      expect(result.refunds).toBeGreaterThanOrEqual(1);

      const refund = await prisma.refund.findUniqueOrThrow({ where: { id: refundId } });
      expect(refund.status).toBe('refunded');
      const payment = await prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
      expect(payment.status).toBe('refunded');
    });
  });

  describe('consistency checks (§82/§63)', () => {
    it('detects orphan reservations, missing reservations and queue/booking mismatches', async () => {
      // Orphan: terminal booking that still holds its reservation row.
      const t1 = await newCustomer();
      const b1 = (
        await createBooking(t1, bookingBody('12:00', { paymentOption: 'pay_at_location' })).expect(
          201,
        )
      ).body.data.booking.id as string;
      await prisma.booking.update({ where: { id: b1 }, data: { status: 'completed' } });

      // Missing: slot-blocking booking whose reservation row vanished.
      const t2 = await newCustomer();
      const b2 = (
        await createBooking(t2, bookingBody('13:00', { paymentOption: 'pay_at_location' })).expect(
          201,
        )
      ).body.data.booking.id as string;
      await prisma.bookingReservation.delete({ where: { bookingId: b2 } });

      // Mismatch: active queue entry whose booking was forced terminal.
      const t3 = await newCustomer();
      const b3 = (
        await createBooking(t3, bookingBody('14:00', { paymentOption: 'pay_at_location' })).expect(
          201,
        )
      ).body.data.booking.id as string;
      await prisma.booking.update({ where: { id: b3 }, data: { scheduledAt: new Date() } });
      await http()
        .post(`/api/v1/bookings/${b3}/check-in`)
        .set('Authorization', `Bearer ${t3}`)
        .set('Idempotency-Key', idem())
        .send({})
        .expect(200);
      await prisma.booking.update({ where: { id: b3 }, data: { status: 'cancelled' } });

      const report = await consistency.runOnce();
      expect(report.orphanReservations).toBeGreaterThanOrEqual(1);
      expect(report.missingReservations).toBeGreaterThanOrEqual(1);
      expect(report.queueBookingMismatches).toBeGreaterThanOrEqual(1);
      expect(typeof report.staleRefunds).toBe('number');
      expect(typeof report.outboxBacklog).toBe('number');
    });
  });

  describe('metrics endpoint', () => {
    it('hides /metrics without the bearer token', async () => {
      await http().get('/api/v1/metrics').expect(404);
      await http().get('/api/v1/metrics').set('Authorization', 'Bearer wrong-token').expect(404);
    });

    it('exposes Prometheus text with the domain counters to the token holder', async () => {
      const res = await http()
        .get('/api/v1/metrics')
        .set('Authorization', `Bearer ${METRICS_TOKEN}`)
        .expect(200);
      expect(res.headers['content-type']).toContain('text/plain');
      // Driven earlier in this suite: webhook (refund test) and check-in (consistency test).
      expect(res.text).toContain('payment_webhook_total');
      expect(res.text).toContain('payment_paid_total');
      expect(res.text).toContain('queue_check_in_total');
    });
  });
});
