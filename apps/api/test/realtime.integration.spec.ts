import { randomUUID } from 'node:crypto';
import { AddressInfo } from 'node:net';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { io as ioClient, Socket } from 'socket.io-client';
import { AppModule } from '../src/app.module';
import {
  EmailPort,
  PasswordChangedEmailInput,
  PasswordResetEmailInput,
  StaffInvitationEmailInput,
} from '../src/infrastructure/email/email.port';
import { PrismaService } from '../src/infrastructure/database/prisma.service';
import { OutboxDispatcherJob } from '../src/modules/bookings/outbox-dispatcher.job';
import { jakartaDateString } from '../src/modules/schedules/slots';

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

/** Resolve the first payload of `event`, or reject after `timeoutMs`. */
function nextEvent<T = Record<string, unknown>>(
  socket: Socket,
  event: string,
  timeoutMs = 4000,
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timed out waiting for ${event}`)), timeoutMs);
    socket.once(event, (data: T) => {
      clearTimeout(timer);
      resolve(data);
    });
  });
}

/** Assert `event` does NOT arrive within `windowMs` (privacy / isolation). */
function expectNoEvent(socket: Socket, event: string, windowMs = 700): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const timer = setTimeout(resolve, windowMs);
    socket.once(event, () => {
      clearTimeout(timer);
      reject(new Error(`unexpected ${event} received`));
    });
  });
}

describe('Realtime queue (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;
  let dispatcher: OutboxDispatcherJob;
  let port: number;
  const sockets: Socket[] = [];

  const idem = (): string => `idem_${randomUUID()}`;
  const uniqueEmail = (): string => `it-rt-${randomUUID()}@example.com`;
  const today = jakartaDateString(new Date());
  // Create-time slots go on tomorrow so they clear the future + min-lead check
  // regardless of the CI wall-clock; the row's scheduledAt is overwritten to now
  // right after, so the queue business_date stays `today`.
  const bookingDate = jakartaDateString(new Date(Date.now() + 24 * 60 * 60 * 1000));

  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;

  const connect = (token: string): Socket => {
    const socket = ioClient(`http://127.0.0.1:${port}/realtime`, {
      auth: { accessToken: token },
      transports: ['websocket'],
      reconnection: false,
    });
    sockets.push(socket);
    return socket;
  };

  const registerUser = async (): Promise<{ userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'RT User', email: uniqueEmail(), password: PASSWORD })
      .expect(201);
    return { userId: res.body.data.user.id, accessToken: res.body.data.session.accessToken };
  };

  let slotSeq = 0;
  const nextScheduledAt = (): string => {
    const n = slotSeq++;
    const hour = String(9 + (n % 8)).padStart(2, '0');
    return `${bookingDate}T${hour}:00:00+07:00`;
  };

  /** A confirmed booking pulled into the check-in window with its slot freed. */
  const checkableBooking = async (): Promise<{
    bookingId: string;
    token: string;
    userId: string;
  }> => {
    const customer = await registerUser();
    const res = await http()
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${customer.accessToken}`)
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
    const bookingId = res.body.data.booking.id as string;
    await prisma.bookingReservation.deleteMany({ where: { bookingId } });
    await prisma.booking.update({ where: { id: bookingId }, data: { scheduledAt: new Date() } });
    return { bookingId, token: customer.accessToken, userId: customer.userId };
  };

  const checkIn = async (token: string, bookingId: string): Promise<string> => {
    const res = await http()
      .post(`/api/v1/bookings/${bookingId}/check-in`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idem())
      .send({ method: 'customer_app' })
      .expect(200);
    return res.body.data.queue.id as string;
  };

  const call = (entryId: string): request.Test =>
    http()
      .post(`/api/v1/businesses/${businessId}/queue/${entryId}/call`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({ expectedVersion: 1 });

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS = '0';
    process.env.OUTBOX_DISPATCHER_INTERVAL_MS = '0'; // drive runOnce() by hand
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(new SilentEmail())
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    await app.listen(0);
    port = (app.getHttpServer().address() as AddressInfo).port;
    http = () => request(app.getHttpServer());
    prisma = app.get(PrismaService);
    dispatcher = app.get(OutboxDispatcherJob);

    const owner = await registerUser();
    ownerToken = owner.accessToken;
    const business = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `RT Barber ${randomUUID().slice(0, 8)}`,
        primaryOutlet: { name: 'Main', address: { formatted: 'Jl. Example No. 1' } },
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

  afterEach(() => {
    for (const socket of sockets.splice(0)) socket.disconnect();
  });

  afterAll(async () => {
    await app.close();
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
    delete process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS;
    delete process.env.OUTBOX_DISPATCHER_INTERVAL_MS;
  });

  describe('connection auth (§101/§102)', () => {
    it('accepts a valid access token and acknowledges the connection', async () => {
      const owner = await registerUser();
      const socket = connect(owner.accessToken);
      const ready = await nextEvent<{ data: { userId: string } }>(socket, 'connection.ready.v1');
      expect(ready.data.userId).toBe(owner.userId);
    });

    it('rejects an invalid access token', async () => {
      const socket = connect('not.a.valid.token');
      const error = await nextEvent<{ error: { code: string } }>(socket, 'server.error.v1');
      expect(error.error.code).toBe('UNAUTHENTICATED');
    });
  });

  describe('subscription authorization (§103)', () => {
    it('authorizes the owner for the outlet queue but rejects a stranger', async () => {
      const ownerSocket = connect(ownerToken);
      await nextEvent(ownerSocket, 'connection.ready.v1');
      ownerSocket.emit('subscription.join.v1', {
        requestId: 'ws_req_owner',
        channels: [{ type: 'outlet_queue', resourceId: outletId, businessDate: today }],
      });
      const ownerAck = await nextEvent<{ joined: unknown[]; rejected: unknown[] }>(
        ownerSocket,
        'subscription.joined.v1',
      );
      expect(ownerAck.joined).toHaveLength(1);
      expect(ownerAck.rejected).toHaveLength(0);

      const stranger = await registerUser();
      const strangerSocket = connect(stranger.accessToken);
      await nextEvent(strangerSocket, 'connection.ready.v1');
      strangerSocket.emit('subscription.join.v1', {
        requestId: 'ws_req_stranger',
        channels: [{ type: 'outlet_queue', resourceId: outletId, businessDate: today }],
      });
      const strangerAck = await nextEvent<{
        joined: unknown[];
        rejected: Array<{ code: string }>;
      }>(strangerSocket, 'subscription.joined.v1');
      expect(strangerAck.joined).toHaveLength(0);
      expect(strangerAck.rejected[0].code).toBe('FORBIDDEN_QUEUE_RESOURCE');
    });
  });

  describe('outbox delivery (§49) end-to-end', () => {
    it('check-in writes an outbox row committed with the queue entry', async () => {
      const { bookingId, token } = await checkableBooking();
      const entryId = await checkIn(token, bookingId);
      const rows = await prisma.outboxEvent.findMany({ where: { aggregateId: entryId } });
      expect(rows.length).toBeGreaterThanOrEqual(1);
      expect(rows[0].eventType).toBe('queue.entry.updated.v1');
      expect(rows[0].status).toBe('pending');
    });

    it('a staff call fans out to the customer and the outlet snapshot; other customers are excluded', async () => {
      const { bookingId, token, userId } = await checkableBooking();
      const entryId = await checkIn(token, bookingId);

      // Subject customer (auto-joined user room) + staff subscribed to the outlet.
      const customerSocket = connect(token);
      const customerReady = await nextEvent<{ data: { userId: string } }>(
        customerSocket,
        'connection.ready.v1',
      );
      expect(customerReady.data.userId).toBe(userId);

      const staffSocket = connect(ownerToken);
      await nextEvent(staffSocket, 'connection.ready.v1');
      staffSocket.emit('subscription.join.v1', {
        channels: [{ type: 'outlet_queue', resourceId: outletId, businessDate: today }],
      });
      await nextEvent(staffSocket, 'subscription.joined.v1');

      // A different customer must never see the subject's private queue event.
      const other = await registerUser();
      const otherSocket = connect(other.accessToken);
      await nextEvent(otherSocket, 'connection.ready.v1');

      const customerEvent = nextEvent<{ data: Record<string, unknown> }>(
        customerSocket,
        'queue.entry.updated.v1',
      );
      const snapshotEvent = nextEvent<{ data: Record<string, unknown> }>(
        staffSocket,
        'queue.snapshot.updated.v1',
      );
      const otherSilent = expectNoEvent(otherSocket, 'queue.entry.updated.v1');

      await call(entryId).expect(200);
      // Pump the dispatcher (the real one polls on an interval); drain fully so a
      // marker committed a hair after the first claim is still delivered.
      for (let i = 0; i < 5; i++) {
        if ((await dispatcher.runOnce()) === 0) break;
      }

      const customer = await customerEvent;
      expect(customer.data.bookingId).toBe(bookingId);
      expect(customer.data.status).toBe('called');

      const snapshot = await snapshotEvent;
      expect(snapshot.data.outletId).toBe(outletId);
      expect((snapshot.data.currentServing as { displayNumber: string }).displayNumber).toMatch(
        /^A\d{3,}$/,
      );

      await otherSilent;

      // Rows drained to processed once delivered (no stuck pending/failed).
      const pending = await prisma.outboxEvent.count({
        where: { aggregateId: entryId, status: { in: ['pending', 'failed'] } },
      });
      expect(pending).toBe(0);
    });
  });
});
