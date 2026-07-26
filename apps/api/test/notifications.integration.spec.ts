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
import { OutboxDispatcherJob } from '../src/modules/bookings/outbox-dispatcher.job';
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

describe('Notifications + devices (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;
  let dispatcher: OutboxDispatcherJob;

  const uniqueEmail = (): string => `it-ntf-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;
  const newDeviceId = (): string => `dev_${randomUUID().replace(/-/g, '').toUpperCase()}`;
  // Create-time slots on tomorrow so they clear future + min-lead checks at any
  // CI wall-clock; scheduledAt is overwritten to now after creation.
  const bookingDate = jakartaDateString(new Date(Date.now() + 24 * 60 * 60 * 1000));

  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;

  const registerUser = async (): Promise<{ userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Notif User', email: uniqueEmail(), password: PASSWORD })
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

  /** A confirmed booking pulled into the check-in window with its slot freed. */
  const checkableBooking = async (customer: {
    userId: string;
    accessToken: string;
  }): Promise<string> => {
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
    return bookingId;
  };

  const checkIn = (token: string, bookingId: string) =>
    http()
      .post(`/api/v1/bookings/${bookingId}/check-in`)
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', idem())
      .send({ method: 'customer_app' });

  const drainOutbox = async (): Promise<void> => {
    for (let i = 0; i < 10; i++) {
      if ((await dispatcher.runOnce()) === 0) break;
    }
  };

  const listNotifications = async (token: string) => {
    const res = await http()
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    return res.body.data;
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
    dispatcher = app.get(OutboxDispatcherJob);

    const owner = await registerUser();
    ownerToken = owner.accessToken;

    const business = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: `Notif Barber ${randomUUID().slice(0, 8)}`,
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

  describe('device registration', () => {
    it('registers, re-registers, and removes a device', async () => {
      const user = await registerUser();
      const deviceId = newDeviceId();

      const put = await http()
        .put(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({
          platform: 'android',
          appVersion: '1.0.0',
          pushToken: `tok-${randomUUID()}`,
          pushProvider: 'onesignal',
          deviceName: 'Pixel 9',
          locale: 'id-ID',
          timezone: 'Asia/Jakarta',
        })
        .expect(200);
      expect(put.body.data).toMatchObject({ deviceId, registered: true });
      expect(put.body.data.updatedAt).toEqual(expect.any(String));

      // Idempotent upsert: same id, new token.
      await http()
        .put(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ platform: 'android', pushToken: `tok-${randomUUID()}`, pushProvider: 'onesignal' })
        .expect(200);
      expect(await prisma.device.count({ where: { userId: user.userId } })).toBe(1);

      const del = await http()
        .delete(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .expect(200);
      expect(del.body.data).toEqual({ removed: true });

      const again = await http()
        .delete(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .expect(404);
      expect(again.body.error.code).toBe('DEVICE_NOT_FOUND');
    });

    it('rejects an unknown platform', async () => {
      const user = await registerUser();
      const res = await http()
        .put(`/api/v1/me/devices/${newDeviceId()}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ platform: 'blackberry' })
        .expect(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    });

    it('re-registering a device under another account moves it', async () => {
      const first = await registerUser();
      const second = await registerUser();
      const deviceId = newDeviceId();
      await http()
        .put(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${first.accessToken}`)
        .send({ platform: 'ios' })
        .expect(200);
      await http()
        .put(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${second.accessToken}`)
        .send({ platform: 'ios' })
        .expect(200);
      // The device now belongs to the second account only.
      await http()
        .delete(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${first.accessToken}`)
        .expect(404);
      await http()
        .delete(`/api/v1/me/devices/${deviceId}`)
        .set('Authorization', `Bearer ${second.accessToken}`)
        .expect(200);
    });
  });

  describe('queue push pipeline', () => {
    it('check-in creates an in-app notification and a sent delivery per device', async () => {
      const customer = await registerUser();
      await http()
        .put(`/api/v1/me/devices/${newDeviceId()}`)
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .send({ platform: 'android', pushToken: `tok-${randomUUID()}`, pushProvider: 'onesignal' })
        .expect(200);

      const bookingId = await checkableBooking(customer);
      await checkIn(customer.accessToken, bookingId).expect(200);
      await drainOutbox();

      const data = await listNotifications(customer.accessToken);
      expect(data.items).toHaveLength(1);
      expect(data.items[0]).toMatchObject({
        type: 'queue_checked_in',
        isRead: false,
        resource: { type: 'booking', id: bookingId },
      });
      expect(data.items[0].title.length).toBeGreaterThan(0);

      const deliveries = await prisma.notificationDelivery.findMany({
        where: { notificationId: data.items[0].id },
      });
      expect(deliveries).toHaveLength(1);
      expect(deliveries[0]).toMatchObject({
        provider: 'onesignal',
        status: 'sent',
        attemptCount: 1,
      });
      expect(deliveries[0].providerMessageId).not.toBeNull();
      expect(deliveries[0].sentAt).not.toBeNull();
    });

    it('call (and recall) create called notifications; no device → no delivery rows', async () => {
      const customer = await registerUser();
      const bookingId = await checkableBooking(customer);
      const entry = await checkIn(customer.accessToken, bookingId).expect(200);
      const entryId = entry.body.data.queue.id as string;
      await drainOutbox();

      await http()
        .post(`/api/v1/businesses/${businessId}/queue/${entryId}/call`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ expectedVersion: 1 })
        .expect(200);
      await drainOutbox();

      const data = await listNotifications(customer.accessToken);
      const types = data.items.map((n: { type: string }) => n.type);
      expect(types).toEqual(['queue_called', 'queue_checked_in']); // newest first
      const called = data.items[0];
      expect(called.resource).toEqual({ type: 'booking', id: bookingId });
      expect(
        await prisma.notificationDelivery.count({ where: { notificationId: called.id } }),
      ).toBe(0);
    });

    it('queue_updates=false suppresses deliveries but keeps in-app history', async () => {
      const customer = await registerUser();
      // Registration seeds the preference row — flip the queue toggle off.
      await prisma.userNotificationPreference.update({
        where: { userId: customer.userId },
        data: { queueUpdates: false },
      });
      await http()
        .put(`/api/v1/me/devices/${newDeviceId()}`)
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .send({ platform: 'android', pushToken: `tok-${randomUUID()}`, pushProvider: 'onesignal' })
        .expect(200);

      const bookingId = await checkableBooking(customer);
      await checkIn(customer.accessToken, bookingId).expect(200);
      await drainOutbox();

      const data = await listNotifications(customer.accessToken);
      expect(data.items).toHaveLength(1);
      expect(
        await prisma.notificationDelivery.count({
          where: { notificationId: data.items[0].id },
        }),
      ).toBe(0);
    });
  });

  describe('notification reads', () => {
    it('marks one and all notifications read; other users see nothing', async () => {
      const customer = await registerUser();
      const bookingId = await checkableBooking(customer);
      await checkIn(customer.accessToken, bookingId).expect(200);
      await drainOutbox();

      const data = await listNotifications(customer.accessToken);
      const id = data.items[0].id as string;

      const one = await http()
        .get(`/api/v1/notifications/${id}`)
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .expect(200);
      expect(one.body.data.id).toBe(id);

      // Knowing the id is never permission.
      const other = await registerUser();
      const stolen = await http()
        .get(`/api/v1/notifications/${id}`)
        .set('Authorization', `Bearer ${other.accessToken}`)
        .expect(404);
      expect(stolen.body.error.code).toBe('NOTIFICATION_NOT_FOUND');

      const read = await http()
        .post(`/api/v1/notifications/${id}/read`)
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .expect(200);
      expect(read.body.data).toMatchObject({ id, isRead: true });
      expect(read.body.data.readAt).toEqual(expect.any(String));

      // Naturally idempotent: readAt does not move on a second call.
      const readAgain = await http()
        .post(`/api/v1/notifications/${id}/read`)
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .expect(200);
      expect(readAgain.body.data.readAt).toBe(read.body.data.readAt);

      const unreadOnly = await http()
        .get('/api/v1/notifications')
        .query({ isRead: 'false' })
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .expect(200);
      expect(unreadOnly.body.data.items).toHaveLength(0);

      const all = await http()
        .post('/api/v1/notifications/read-all')
        .set('Authorization', `Bearer ${customer.accessToken}`)
        .expect(200);
      expect(all.body.data).toEqual({ updatedCount: 0 });
    });
  });
});
