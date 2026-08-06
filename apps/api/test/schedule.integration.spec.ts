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
import { DAY_NAMES } from '../src/modules/schedules/dto/schedule.dto';
import { addDays, jakartaDateString, jakartaDayOfWeek } from '../src/modules/schedules/slots';

jest.setTimeout(120_000);

class SilentEmail extends EmailPort {
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(_input: StaffInvitationEmailInput): Promise<void> {}
}

const PASSWORD = 'integration-password-1';

describe('Scheduling endpoints (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;

  const uniqueEmail = (): string => `it-sch-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;

  const today = jakartaDateString(new Date());
  const tomorrow = addDays(today, 1);
  const tomorrowDay = DAY_NAMES[jakartaDayOfWeek(tomorrow)];

  const businessName = `Schedule Barber ${randomUUID().slice(0, 8)}`;
  let ownerToken: string;
  let businessId: string;
  let outletId: string;
  let serviceId: string;
  let staffId: string;
  let staffToken: string;

  const registerUser = async (
    emailAddr = uniqueEmail(),
  ): Promise<{ email: string; userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Schedule User', email: emailAddr, password: PASSWORD })
      .expect(201);
    return {
      email: emailAddr,
      userId: res.body.data.user.id,
      accessToken: res.body.data.session.accessToken,
    };
  };

  const inviteStaff = async (
    eligibleServiceIds: string[] | undefined,
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
        ...(eligibleServiceIds ? { eligibleServiceIds } : {}),
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
    const biz = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name: businessName,
        primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 10' } },
      })
      .expect(201);
    businessId = biz.body.data.id;
    outletId = biz.body.data.primaryOutlet.id;

    const svc = await http()
      .post(`/api/v1/businesses/${businessId}/services`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .set('Idempotency-Key', idem())
      .send({ name: 'Haircut', durationMinutes: 45, price: { amount: 50000, currency: 'IDR' } })
      .expect(201);
    serviceId = svc.body.data.id;

    const staff = await inviteStaff([serviceId]);
    staffId = staff.staffId;
    staffToken = staff.accessToken;
  });

  afterAll(async () => {
    await app.close();
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
  });

  describe('outlet operating hours', () => {
    it('starts fully closed and replaces hours with validation', async () => {
      const initial = await http()
        .get(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);
      expect(initial.body.data.timezone).toBe('Asia/Jakarta');
      expect(initial.body.data.days).toHaveLength(7);
      expect(initial.body.data.days.every((d: { isClosed: boolean }) => d.isClosed)).toBe(true);

      await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .send({ timezone: 'Asia/Jakarta', days: [] })
        .expect(401);

      const outsider = await registerUser();
      await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .send({ timezone: 'Asia/Jakarta', days: [] })
        .expect(403);

      const badTz = await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Makassar',
          days: [
            {
              dayOfWeek: 'monday',
              isClosed: false,
              periods: [{ opensAt: '09:00', closesAt: '12:00' }],
            },
          ],
        })
        .expect(400);
      expect(badTz.body.error.code).toBe('SCHEDULE_INVALID_TIMEZONE');

      const overlap = await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: [
            {
              dayOfWeek: 'monday',
              isClosed: false,
              periods: [
                { opensAt: '09:00', closesAt: '12:00' },
                { opensAt: '11:00', closesAt: '15:00' },
              ],
            },
          ],
        })
        .expect(400);
      expect(overlap.body.error.code).toBe('SCHEDULE_OVERLAPPING_PERIODS');

      const inverted = await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: [
            {
              dayOfWeek: 'monday',
              isClosed: false,
              periods: [{ opensAt: '15:00', closesAt: '09:00' }],
            },
          ],
        })
        .expect(400);
      expect(inverted.body.error.code).toBe('SCHEDULE_INVALID_PERIOD');

      const duplicateDay = await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: [
            { dayOfWeek: 'monday', isClosed: true, periods: [] },
            { dayOfWeek: 'monday', isClosed: true, periods: [] },
          ],
        })
        .expect(400);
      expect(duplicateDay.body.error.code).toBe('VALIDATION_FAILED');

      // Open every day so later availability tests are date-independent.
      const replaced = await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: DAY_NAMES.map((dayOfWeek) => ({
            dayOfWeek,
            isClosed: false,
            periods:
              dayOfWeek === tomorrowDay
                ? [
                    { opensAt: '13:00', closesAt: '15:00' },
                    { opensAt: '09:00', closesAt: '12:00' },
                  ]
                : [{ opensAt: '09:00', closesAt: '12:00' }],
          })),
        })
        .expect(200);
      const replacedDay = replaced.body.data.days.find(
        (d: { dayOfWeek: string }) => d.dayOfWeek === tomorrowDay,
      );
      // Periods come back normalized (sorted by start time).
      expect(replacedDay.periods).toEqual([
        { opensAt: '09:00', closesAt: '12:00' },
        { opensAt: '13:00', closesAt: '15:00' },
      ]);

      const details = await http().get(`/api/v1/businesses/${businessId}`).expect(200);
      const outletHours = details.body.data.outlets[0].operatingHours.find(
        (d: { dayOfWeek: string }) => d.dayOfWeek === tomorrowDay,
      );
      expect(outletHours.isClosed).toBe(false);
      expect(outletHours.periods.length).toBeGreaterThan(0);
    });

    it('reflects open-now state in discovery once hours cover the whole day', async () => {
      await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: DAY_NAMES.map((dayOfWeek) => ({
            dayOfWeek,
            isClosed: false,
            periods: [{ opensAt: '00:00', closesAt: '23:59' }],
          })),
        })
        .expect(200);

      const details = await http().get(`/api/v1/businesses/${businessId}`).expect(200);
      expect(details.body.data.outlets[0].operatingHours).toHaveLength(7);

      // q narrows the list: the shared test DB accumulates businesses across
      // runs, so an unfiltered page can push this one past the 100-row cap.
      const list = await http()
        .get(`/api/v1/businesses?q=${encodeURIComponent(businessName)}&limit=100`)
        .expect(200);
      const summary = list.body.data.items.find((b: { id: string }) => b.id === businessId);
      expect(summary.primaryOutlet.isOpenNow).toBe(true);
    });
  });

  describe('closed dates', () => {
    const closedTarget = addDays(jakartaDateString(new Date()), 3);

    it('creates, rejects duplicates and past dates, lists with filters', async () => {
      const missingKey = await http()
        .post(`/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ date: closedTarget, reason: 'Renovation' })
        .expect(400);
      expect(missingKey.body.error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');

      const created = await http()
        .post(`/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ date: closedTarget, reason: 'Renovation' })
        .expect(201);
      expect(created.body.data.id).toMatch(/^cld_/);
      expect(created.body.data.date).toBe(closedTarget);

      const duplicate = await http()
        .post(`/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ date: closedTarget, reason: 'Again' })
        .expect(409);
      expect(duplicate.body.error.code).toBe('SCHEDULE_CLOSED_DATE_ALREADY_EXISTS');

      const past = await http()
        .post(`/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({ date: addDays(today, -1) })
        .expect(400);
      expect(past.body.error.code).toBe('SCHEDULE_DATE_IN_PAST');

      const listed = await http()
        .get(`/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);
      expect(listed.body.data.items.some((i: { date: string }) => i.date === closedTarget)).toBe(
        true,
      );

      const filtered = await http()
        .get(
          `/api/v1/businesses/${businessId}/outlets/${outletId}/closed-dates?dateFrom=${addDays(
            closedTarget,
            1,
          )}`,
        )
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(200);
      expect(filtered.body.data.items.some((i: { date: string }) => i.date === closedTarget)).toBe(
        false,
      );
    });

    it('returns no availability slots on a closed date', async () => {
      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&staffId=${staffId}&date=${closedTarget}`,
        )
        .expect(200);
      expect(res.body.data.slots).toEqual([]);
    });
  });

  describe('staff schedule', () => {
    it('replaces the weekly schedule with validation and permissions', async () => {
      const forbidden = await http()
        .put(`/api/v1/businesses/${businessId}/staff/${staffId}/schedule`)
        .set('Authorization', `Bearer ${staffToken}`)
        .send({ timezone: 'Asia/Jakarta', days: [] })
        .expect(403);
      expect(forbidden.body.error.code).toBe('PERMISSION_REQUIRED');

      const unknownStaff = await http()
        .put(`/api/v1/businesses/${businessId}/staff/stf_missing/schedule`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ timezone: 'Asia/Jakarta', days: [] })
        .expect(404);
      expect(unknownStaff.body.error.code).toBe('STAFF_NOT_FOUND');

      const strayBreak = await http()
        .put(`/api/v1/businesses/${businessId}/staff/${staffId}/schedule`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: [
            {
              dayOfWeek: tomorrowDay,
              isAvailable: true,
              periods: [{ startsAt: '09:00', endsAt: '12:00' }],
              breaks: [{ startsAt: '11:30', endsAt: '12:30' }],
            },
          ],
        })
        .expect(400);
      expect(strayBreak.body.error.code).toBe('SCHEDULE_INVALID_PERIOD');

      const replaced = await http()
        .put(`/api/v1/businesses/${businessId}/staff/${staffId}/schedule`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: DAY_NAMES.map((dayOfWeek) => ({
            dayOfWeek,
            isAvailable: true,
            periods: [{ startsAt: '09:00', endsAt: '17:00' }],
            breaks: dayOfWeek === tomorrowDay ? [{ startsAt: '10:30', endsAt: '11:15' }] : [],
          })),
        })
        .expect(200);
      expect(replaced.body.data.days).toHaveLength(7);
      const day = replaced.body.data.days.find(
        (d: { dayOfWeek: string }) => d.dayOfWeek === tomorrowDay,
      );
      expect(day.isAvailable).toBe(true);
      expect(day.periods).toEqual([{ startsAt: '09:00', endsAt: '17:00' }]);
      expect(day.breaks).toEqual([{ startsAt: '10:30', endsAt: '11:15' }]);

      // §58 read side — the editor prefills from this, and any member may read
      // it (this token is the one rejected by the PUT above).
      const read = await http()
        .get(`/api/v1/businesses/${businessId}/staff/${staffId}/schedule`)
        .set('Authorization', `Bearer ${staffToken}`)
        .expect(200);
      expect(read.body.data).toEqual(replaced.body.data);

      const missing = await http()
        .get(`/api/v1/businesses/${businessId}/staff/stf_missing/schedule`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .expect(404);
      expect(missing.body.error.code).toBe('STAFF_NOT_FOUND');
    });
  });

  describe('availability', () => {
    it('requires staffId while any_available is out of scope (ADR 0019)', async () => {
      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&date=${tomorrow}`,
        )
        .expect(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    });

    it('validates references and date range', async () => {
      const badOutlet = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=out_missing&serviceId=${serviceId}&staffId=${staffId}&date=${tomorrow}`,
        )
        .expect(404);
      expect(badOutlet.body.error.code).toBe('OUTLET_NOT_FOUND');

      const badService = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=svc_missing&staffId=${staffId}&date=${tomorrow}`,
        )
        .expect(404);
      expect(badService.body.error.code).toBe('SERVICE_NOT_FOUND');

      const badStaff = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&staffId=stf_missing&date=${tomorrow}`,
        )
        .expect(404);
      expect(badStaff.body.error.code).toBe('STAFF_NOT_FOUND');

      const tooFar = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&staffId=${staffId}&date=${addDays(today, 40)}`,
        )
        .expect(400);
      expect(tooFar.body.error.code).toBe('SCHEDULE_DATE_OUT_OF_RANGE');

      const pastDate = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&staffId=${staffId}&date=${addDays(today, -1)}`,
        )
        .expect(400);
      expect(pastDate.body.error.code).toBe('SCHEDULE_DATE_OUT_OF_RANGE');
    });

    it('rejects staff not eligible for the service', async () => {
      const other = await inviteStaff(undefined);
      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&staffId=${other.staffId}&date=${tomorrow}`,
        )
        .expect(400);
      expect(res.body.error.code).toBe('STAFF_NOT_ELIGIBLE_FOR_SERVICE');
    });

    it('builds the public slot grid from outlet hours, staff schedule, and breaks', async () => {
      // Narrow tomorrow's outlet hours to a deterministic 09:00-12:00 window.
      await http()
        .put(`/api/v1/businesses/${businessId}/outlets/${outletId}/operating-hours`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          timezone: 'Asia/Jakarta',
          days: [
            {
              dayOfWeek: tomorrowDay,
              isClosed: false,
              periods: [{ opensAt: '09:00', closesAt: '12:00' }],
            },
          ],
        })
        .expect(200);

      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${serviceId}&staffId=${staffId}&date=${tomorrow}`,
        )
        .expect(200);

      expect(res.body.data).toMatchObject({
        businessId,
        outletId,
        date: tomorrow,
        timezone: 'Asia/Jakarta',
        staffSelection: { mode: 'specific_staff', staffId },
        service: { id: serviceId, durationMinutes: 45 },
      });
      // 45-minute grid inside 09:00-12:00; the 10:30-11:15 break exactly covers
      // the 10:30 slot, while neighbours ending/starting at its edges survive.
      expect(res.body.data.slots).toEqual([
        {
          startsAt: `${tomorrow}T09:00:00+07:00`,
          endsAt: `${tomorrow}T09:45:00+07:00`,
          available: true,
        },
        {
          startsAt: `${tomorrow}T09:45:00+07:00`,
          endsAt: `${tomorrow}T10:30:00+07:00`,
          available: true,
        },
        {
          startsAt: `${tomorrow}T10:30:00+07:00`,
          endsAt: `${tomorrow}T11:15:00+07:00`,
          available: false,
        },
        {
          startsAt: `${tomorrow}T11:15:00+07:00`,
          endsAt: `${tomorrow}T12:00:00+07:00`,
          available: true,
        },
      ]);
    });

    it('lets unscheduled staff follow outlet hours on a service open to all staff', async () => {
      const svc = await http()
        .post(`/api/v1/businesses/${businessId}/services`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: 'Beard Trim',
          durationMinutes: 90,
          price: { amount: 30000, currency: 'IDR' },
        })
        .expect(201);
      const other = await inviteStaff(undefined);

      const res = await http()
        .get(
          `/api/v1/businesses/${businessId}/availability?outletId=${outletId}&serviceId=${svc.body.data.id}&staffId=${other.staffId}&date=${tomorrow}`,
        )
        .expect(200);
      // 90-minute service inside 09:00-12:00 → 09:00 and 10:30 slots, both
      // available because the new staff member has no configured schedule yet.
      expect(res.body.data.slots).toEqual([
        {
          startsAt: `${tomorrow}T09:00:00+07:00`,
          endsAt: `${tomorrow}T10:30:00+07:00`,
          available: true,
        },
        {
          startsAt: `${tomorrow}T10:30:00+07:00`,
          endsAt: `${tomorrow}T12:00:00+07:00`,
          available: true,
        },
      ]);
    });
  });
});
