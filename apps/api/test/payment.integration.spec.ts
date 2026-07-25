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
import { PaymentExpirationJob } from '../src/modules/bookings/payment-expiration.job';
import { addDays, jakartaDateString } from '../src/modules/schedules/slots';

jest.setTimeout(120_000);

class SilentEmail extends EmailPort {
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(_input: StaffInvitationEmailInput): Promise<void> {}
}

const PASSWORD = 'integration-password-1';
const WEBHOOK_SECRET = 'sandbox-webhook-secret';
const ALL_DAYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;

describe('Payment endpoints (integration, M7)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;
  let sandbox: SandboxPaymentAdapter;
  let expirationJob: PaymentExpirationJob;

  const uniqueEmail = (): string => `it-pay-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;

  const today = jakartaDateString(new Date());
  const target = addDays(today, 7);
  const at = (time: string, date = target): string => `${date}T${time}:00+07:00`;

  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let depositServiceId: string;
  let staffId: string;
  let barberToken: string;

  const registerUser = async (
    emailAddr = uniqueEmail(),
  ): Promise<{ email: string; userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Payment User', email: emailAddr, password: PASSWORD })
      .expect(201);
    return {
      email: emailAddr,
      userId: res.body.data.user.id,
      accessToken: res.body.data.session.accessToken,
    };
  };

  /** Fresh customer per test — the 3-active-bookings limit is per customer. */
  const newCustomer = async (): Promise<string> => (await registerUser()).accessToken;

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
    paymentOption: 'full_payment',
    ...overrides,
  });

  const webhook = (event: Record<string, unknown>, signature?: string): request.Test => {
    const raw = JSON.stringify(event);
    return http()
      .post('/api/v1/webhooks/payments/sandbox')
      .set('Content-Type', 'application/json')
      .set('x-sandbox-signature', signature ?? signSandboxWebhook(Buffer.from(raw), WEBHOOK_SECRET))
      .send(raw);
  };

  const paidEvent = (
    providerReference: string,
    amount: number,
    overrides: Record<string, unknown> = {},
  ): Record<string, unknown> => ({
    eventId: `evt_${randomUUID()}`,
    type: 'payment.paid',
    providerReference,
    status: 'paid',
    amount,
    currency: 'IDR',
    occurredAt: new Date().toISOString(),
    ...overrides,
  });

  const getBooking = (token: string, bookingId: string): request.Test =>
    http().get(`/api/v1/bookings/${bookingId}`).set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS = '0';
    // process.env beats .env in ConfigModule — pin the secret the tests sign with.
    process.env.PAYMENT_WEBHOOK_SECRET = WEBHOOK_SECRET;
    process.env.PAYMENT_PROVIDER = 'sandbox';
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
    expirationJob = app.get(PaymentExpirationJob);

    const owner = await registerUser();
    ownerToken = owner.accessToken;

    const biz = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `Payment Barber ${randomUUID().slice(0, 8)}`,
        primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 11' } },
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

    const depositSvc = await http()
      .post(`/api/v1/businesses/${businessId}/services`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: 'Premium Cut',
        durationMinutes: 45,
        price: { amount: 50000, currency: 'IDR' },
        deposit: { type: 'fixed', value: 10000 },
      })
      .expect(201);
    depositServiceId = depositSvc.body.data.id;

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
        eligibleServiceIds: [serviceId, depositServiceId],
      })
      .expect(201);
    const invitee = await registerUser(inviteeEmail);
    barberToken = invitee.accessToken;
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
  });

  describe('online booking creation (BP3)', () => {
    it('creates a pending_payment booking with checkout details', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('09:00')).expect(201);
      const { booking, payment } = res.body.data;
      expect(booking.status).toBe('pending_payment');
      expect(booking.paymentOption).toBe('full_payment');
      expect(booking.paymentSummary).toMatchObject({
        totalAmount: { amount: 50000, currency: 'IDR' },
        requiredNow: { amount: 50000, currency: 'IDR' },
        status: 'unpaid',
      });
      expect(payment.status).toBe('pending');
      expect(payment.provider).toBe('sandbox');
      expect(payment.providerReference).toBe(`sbx_${payment.id}`);
      expect(payment.checkout).toEqual({
        type: 'redirect_url',
        url: expect.stringContaining(payment.providerReference),
      });
      const expiresIn = new Date(payment.expiresAt).getTime() - Date.now();
      expect(expiresIn).toBeGreaterThan(25 * 60_000);
      expect(expiresIn).toBeLessThanOrEqual(30 * 60_000);
    });

    it('confirms the booking when the paid webhook arrives, keeping the slot blocked', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('10:00')).expect(201);
      const { booking, payment } = res.body.data;

      await webhook(paidEvent(payment.providerReference, 50000)).expect(200, {
        received: true,
      });

      const after = await getBooking(token, booking.id).expect(200);
      expect(after.body.data.status).toBe('confirmed');
      expect(after.body.data.paymentSummary.status).toBe('paid');

      const paidPayment = await http()
        .get(`/api/v1/payments/${payment.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(paidPayment.body.data.status).toBe('paid');
      expect(paidPayment.body.data.paidAt).not.toBeNull();

      // Reservation preserved — the slot still blocks a second booking (§38).
      const clash = await createBooking(await newCustomer(), bookingBody('10:00'));
      expect(clash.status).toBe(409);
      expect(clash.body.error.code).toBe('BOOKING_SLOT_UNAVAILABLE');
    });

    it('re-delivers a duplicate webhook without repeating effects', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('11:00')).expect(201);
      const { payment } = res.body.data;
      const event = paidEvent(payment.providerReference, 50000);

      await webhook(event).expect(200);
      const first = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      await webhook(event).expect(200, { received: true });
      const second = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });

      expect(second.version).toBe(first.version);
      expect(second.paidAt?.toISOString()).toBe(first.paidAt?.toISOString());
      const events = await prisma.paymentEvent.findMany({
        where: { providerEventId: event.eventId as string },
      });
      expect(events).toHaveLength(1);
    });

    it('rejects a bad webhook signature', async () => {
      const raw = JSON.stringify(paidEvent('sbx_nope', 1));
      await http()
        .post('/api/v1/webhooks/payments/sandbox')
        .set('Content-Type', 'application/json')
        .set('x-sandbox-signature', 'deadbeef')
        .send(raw)
        .expect(401, { received: false, error: 'SIGNATURE_INVALID' });
    });

    it('quarantines an amount mismatch without touching the payment', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('12:00')).expect(201);
      const { payment } = res.body.data;
      const event = paidEvent(payment.providerReference, 99999);
      await webhook(event).expect(200);

      const row = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      expect(row.status).toBe('pending');
      const stored = await prisma.paymentEvent.findFirstOrThrow({
        where: { providerEventId: event.eventId as string },
      });
      expect(stored.processingStatus).toBe('manual_review');
      expect(stored.processingErrorCode).toBe('PAYMENT_WEBHOOK_AMOUNT_MISMATCH');
    });

    it('releases the slot when the provider reports failure', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('13:00')).expect(201);
      const { booking, payment } = res.body.data;

      await webhook(
        paidEvent(payment.providerReference, 50000, { type: 'payment.failed', status: 'failed' }),
      ).expect(200);

      const after = await getBooking(token, booking.id).expect(200);
      expect(after.body.data.status).toBe('expired');

      await createBooking(await newCustomer(), bookingBody('13:00')).expect(201);
    });

    it('retries a provider-creation failure with the same key and resumes the booking', async () => {
      const customer = await registerUser();
      sandbox.failNextCreate();
      const key = idem();
      const body = bookingBody('14:00');
      const failed = await createBooking(customer.accessToken, body, key);
      expect(failed.status).toBe(503);
      expect(failed.body.error.code).toBe('PAYMENT_PROVIDER_UNAVAILABLE');

      const retried = await createBooking(customer.accessToken, body, key).expect(201);
      const { booking, payment } = retried.body.data;
      expect(booking.status).toBe('pending_payment');
      expect(payment.providerReference).toBe(`sbx_${payment.id}`);

      const bookings = await prisma.booking.count({
        where: { customerUserId: customer.userId, scheduledAt: new Date(at('14:00')) },
      });
      expect(bookings).toBe(1);
      const row = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      expect(row.providerCreationAttempts).toBe(2);
    });
  });

  describe('expiration and recovery (BP5)', () => {
    it('expires an overdue pending payment and releases the slot', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('15:00')).expect(201);
      const { booking, payment } = res.body.data;

      await prisma.payment.update({
        where: { id: payment.id },
        data: { expiresAt: new Date(Date.now() - 60_000) },
      });
      expect(await expirationJob.runOnce()).toBeGreaterThanOrEqual(1);

      const after = await getBooking(token, booking.id).expect(200);
      expect(after.body.data.status).toBe('expired');
      const paymentRow = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      expect(paymentRow.status).toBe('expired');
      expect(
        await prisma.bookingReservation.findUnique({ where: { bookingId: booking.id } }),
      ).toBeNull();

      await createBooking(await newCustomer(), bookingBody('15:00')).expect(201);
    });

    it('quarantines and refunds a verified success that arrives after expiry (ADR 0040)', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('16:00')).expect(201);
      const { booking, payment } = res.body.data;
      await prisma.payment.update({
        where: { id: payment.id },
        data: { expiresAt: new Date(Date.now() - 60_000) },
      });
      await expirationJob.runOnce();
      // The slot was rebooked meanwhile.
      await createBooking(await newCustomer(), bookingBody('16:00')).expect(201);

      const event = paidEvent(payment.providerReference, 50000);
      await webhook(event).expect(200);

      const paymentRow = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      expect(paymentRow.status).toBe('expired');
      const stored = await prisma.paymentEvent.findFirstOrThrow({
        where: { providerEventId: event.eventId as string },
      });
      expect(stored.processingStatus).toBe('manual_review');
      const refund = await prisma.refund.findFirstOrThrow({
        where: { paymentId: payment.id, reasonCode: 'late_payment' },
      });
      expect(refund.status).toBe('refunded');
      expect(refund.amount).toBe(50000);
      expect(refund.bookingId).toBe(booking.id);
    });

    it('refreshes payment status synchronously through the webhook path (ADR 0029)', async () => {
      const token = await newCustomer();
      const res = await createBooking(token, bookingBody('17:00')).expect(201);
      const { booking, payment } = res.body.data;

      sandbox.simulateStatus(payment.providerReference, 'paid');
      const refreshed = await http()
        .post(`/api/v1/payments/${payment.id}/refresh`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(refreshed.body.data.refreshedFromProvider).toBe(true);
      expect(refreshed.body.data.payment.status).toBe('paid');
      expect(refreshed.body.data.bookingStatus).toBe('confirmed');

      const throttled = await http()
        .post(`/api/v1/payments/${payment.id}/refresh`)
        .set('Authorization', `Bearer ${token}`);
      expect(throttled.status).toBe(429);
      expect(throttled.body.error.code).toBe('PAYMENT_STATUS_REFRESH_RATE_LIMITED');

      const after = await getBooking(token, booking.id).expect(200);
      expect(after.body.data.status).toBe('confirmed');
    });

    it('answers refresh on a pay-at-location payment from stored state', async () => {
      const token = await newCustomer();
      const res = await createBooking(
        token,
        bookingBody('09:00', {
          paymentOption: 'pay_at_location',
          scheduledAt: at('09:00', addDays(target, 1)),
        }),
      ).expect(201);
      const payments = await http()
        .get(`/api/v1/bookings/${res.body.data.booking.id}/payments`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      const palPaymentId = payments.body.data.items[0].id as string;

      const refreshed = await http()
        .post(`/api/v1/payments/${palPaymentId}/refresh`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(refreshed.body.data.refreshedFromProvider).toBe(false);
      expect(refreshed.body.data.payment.status).toBe('pending');
    });
  });

  describe('deposit flow (BP6)', () => {
    let depositCustomerToken: string;
    let bookingId: string;
    let depositPaymentId: string;

    it('takes a deposit online and leaves the remainder for the outlet', async () => {
      depositCustomerToken = await newCustomer();
      const res = await createBooking(
        depositCustomerToken,
        bookingBody('10:00', {
          serviceId: depositServiceId,
          paymentOption: 'deposit',
          scheduledAt: at('10:00', addDays(target, 1)),
        }),
      ).expect(201);
      bookingId = res.body.data.booking.id;
      const { booking, payment } = res.body.data;
      depositPaymentId = payment.id;
      expect(booking.paymentSummary).toMatchObject({
        totalAmount: { amount: 50000, currency: 'IDR' },
        requiredNow: { amount: 10000, currency: 'IDR' },
      });
      expect(payment.amount).toEqual({ amount: 10000, currency: 'IDR' });

      await webhook(paidEvent(payment.providerReference, 10000)).expect(200);
      const after = await getBooking(depositCustomerToken, bookingId).expect(200);
      expect(after.body.data.status).toBe('confirmed');
      expect(after.body.data.paymentSummary).toMatchObject({
        paidAmount: { amount: 10000, currency: 'IDR' },
        remainingAmount: { amount: 40000, currency: 'IDR' },
        status: 'partially_paid',
      });
    });

    it('settles the remaining balance at the outlet (§73)', async () => {
      await http()
        .post(
          `/api/v1/businesses/${businessId}/bookings/${bookingId}/payments/pay-at-location/confirm`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 40000, currency: 'IDR' }, method: 'cash' })
        .expect(200);

      const after = await getBooking(depositCustomerToken, bookingId).expect(200);
      expect(after.body.data.paymentSummary.status).toBe('paid');
      expect(after.body.data.paymentSummary.remainingAmount.amount).toBe(0);
    });

    it('rejects a deposit booking on a service without a configured deposit', async () => {
      const res = await createBooking(
        await newCustomer(),
        bookingBody('12:00', {
          paymentOption: 'deposit',
          scheduledAt: at('12:00', addDays(target, 1)),
        }),
      );
      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('PAYMENT_OPTION_NOT_AVAILABLE');
    });

    it('refunds the deposit through the refund endpoint (§74) and reads it back (§75)', async () => {
      const refundRes = await http()
        .post(`/api/v1/businesses/${businessId}/payments/${depositPaymentId}/refunds`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({
          amount: { amount: 10000, currency: 'IDR' },
          reasonCode: 'goodwill',
          reason: 'Customer compensation.',
        })
        .expect(202);
      const refund = refundRes.body.data.refund;
      expect(refund.status).toBe('refunded');
      expect(refund.amount).toEqual({ amount: 10000, currency: 'IDR' });

      const read = await http()
        .get(`/api/v1/refunds/${refund.id}`)
        .set('Authorization', `Bearer ${depositCustomerToken}`)
        .expect(200);
      expect(read.body.data.status).toBe('refunded');

      const outsider = await registerUser();
      await http()
        .get(`/api/v1/refunds/${refund.id}`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .expect(404);

      const paymentRow = await prisma.payment.findUniqueOrThrow({
        where: { id: depositPaymentId },
      });
      expect(paymentRow.status).toBe('refunded');

      const tooMuch = await http()
        .post(`/api/v1/businesses/${businessId}/payments/${depositPaymentId}/refunds`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 1, currency: 'IDR' }, reasonCode: 'goodwill' });
      expect(tooMuch.status).toBe(422);

      await http()
        .post(`/api/v1/businesses/${businessId}/payments/${depositPaymentId}/refunds`)
        .set('Authorization', `Bearer ${barberToken}`)
        .set('Idempotency-Key', idem())
        .send({ amount: { amount: 1, currency: 'IDR' }, reasonCode: 'goodwill' })
        .expect(403);
    });
  });

  describe('cancellation refunds (BP7)', () => {
    it('refunds the full net paid amount on business cancellation (ADR 0040)', async () => {
      const token = await newCustomer();
      const res = await createBooking(
        token,
        bookingBody('13:00', { scheduledAt: at('13:00', addDays(target, 1)) }),
      ).expect(201);
      const { booking, payment } = res.body.data;
      await webhook(paidEvent(payment.providerReference, 50000)).expect(200);

      const cancelled = await http()
        .post(`/api/v1/businesses/${businessId}/bookings/${booking.id}/cancel`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ reasonCode: 'business_unavailable', reason: 'Barber is ill.' })
        .expect(200);
      expect(cancelled.body.data.refund).toMatchObject({
        required: true,
        status: 'refunded',
        amount: { amount: 50000, currency: 'IDR' },
      });

      const paymentRow = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      expect(paymentRow.status).toBe('refunded');
    });

    it('refunds per the snapshotted policy on customer cancellation (ADR 0018)', async () => {
      const token = await newCustomer();
      const res = await createBooking(
        token,
        bookingBody('14:00', { scheduledAt: at('14:00', addDays(target, 1)) }),
      ).expect(201);
      const { booking, payment } = res.body.data;
      await webhook(paidEvent(payment.providerReference, 50000)).expect(200);

      // 8 days ahead — far beyond the 360-minute full-refund threshold.
      const cancelled = await http()
        .post(`/api/v1/bookings/${booking.id}/cancel`)
        .set('Authorization', `Bearer ${token}`)
        .set('Idempotency-Key', idem())
        .send({ reasonCode: 'customer_changed_plan' })
        .expect(200);
      expect(cancelled.body.data.refund).toMatchObject({
        required: true,
        status: 'refunded',
        amount: { amount: 50000, currency: 'IDR' },
      });

      const refundRow = await prisma.refund.findFirstOrThrow({
        where: { paymentId: payment.id },
      });
      expect(refundRow.reasonCode).toBe('customer_changed_plan');
    });

    it('creates no refund when cancelling an unpaid online booking', async () => {
      const token = await newCustomer();
      const res = await createBooking(
        token,
        bookingBody('15:00', { scheduledAt: at('15:00', addDays(target, 1)) }),
      ).expect(201);
      const { booking } = res.body.data;

      const cancelled = await http()
        .post(`/api/v1/bookings/${booking.id}/cancel`)
        .set('Authorization', `Bearer ${token}`)
        .set('Idempotency-Key', idem())
        .send({})
        .expect(200);
      expect(cancelled.body.data.refund).toEqual({ required: false });
      expect(await prisma.refund.count({ where: { bookingId: booking.id } })).toBe(0);
    });
  });
});
