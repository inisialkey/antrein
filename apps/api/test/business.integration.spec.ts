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

jest.setTimeout(120_000);

class CapturingEmail extends EmailPort {
  invitations: StaffInvitationEmailInput[] = [];
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(input: StaffInvitationEmailInput): Promise<void> {
    this.invitations.push(input);
  }
}

const PASSWORD = 'integration-password-1';

describe('Business, service, and staff endpoints (integration)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let email: CapturingEmail;
  let http: () => request.Agent;

  const uniqueEmail = (): string => `it-biz-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;

  const registerUser = async (
    emailAddr = uniqueEmail(),
  ): Promise<{ email: string; userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Biz User', email: emailAddr, password: PASSWORD })
      .expect(201);
    return {
      email: emailAddr,
      userId: res.body.data.user.id,
      accessToken: res.body.data.session.accessToken,
    };
  };

  const createBusiness = async (
    accessToken: string,
    name = `Barber ${randomUUID().slice(0, 8)}`,
  ): Promise<{ businessId: string; outletId: string; name: string }> => {
    const res = await http()
      .post('/api/v1/businesses')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name,
        description: 'Test barbershop',
        primaryOutlet: {
          name: 'Main Outlet',
          phoneNumber: '+622112345678',
          address: { formatted: 'Jl. Example No. 10, Jakarta', latitude: -6.2, longitude: 106.8 },
        },
      })
      .expect(201);
    return {
      businessId: res.body.data.id,
      outletId: res.body.data.primaryOutlet.id,
      name,
    };
  };

  const createService = async (
    accessToken: string,
    businessId: string,
    name = 'Haircut',
    price = 50000,
  ): Promise<string> => {
    const res = await http()
      .post(`/api/v1/businesses/${businessId}/services`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('Idempotency-Key', idem())
      .send({
        name,
        durationMinutes: 45,
        price: { amount: price, currency: 'IDR' },
        deposit: { type: 'fixed', value: 10000 },
      })
      .expect(201);
    return res.body.data.id;
  };

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    email = new CapturingEmail();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(email)
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    prisma = app.get(PrismaService);
    http = () => request(app.getHttpServer());
  });

  afterAll(async () => {
    await app.close();
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
  });

  describe('create business', () => {
    it('creates business + policy + outlet + owner membership and reflects in /me', async () => {
      const owner = await registerUser();
      const res = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: 'AntreIn Barbershop',
          primaryOutlet: {
            name: 'Main Outlet',
            address: { formatted: 'Jl. Example No. 10, Jakarta' },
          },
        })
        .expect(201);

      expect(res.body.data.id).toMatch(/^biz_/);
      expect(res.body.data.status).toBe('active');
      expect(res.body.data.primaryOutlet.id).toMatch(/^out_/);

      const me = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .expect(200);
      expect(me.body.data.roles).toEqual(['customer', 'business_owner']);
      const membership = me.body.data.businessMemberships[0];
      expect(membership.businessId).toBe(res.body.data.id);
      expect(membership.role).toBe('owner');
      expect(membership.permissions).toContain('business.manage');
      expect(membership.outletIds).toEqual([res.body.data.primaryOutlet.id]);

      const policy = await prisma.businessPolicy.findUnique({
        where: { businessId: res.body.data.id },
      });
      expect(policy?.allowPayAtLocation).toBe(true);
    });

    it('requires an Idempotency-Key', async () => {
      const owner = await registerUser();
      const res = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({
          name: 'No Key Barber',
          primaryOutlet: { name: 'Outlet', address: { formatted: 'Jl. A No. 1, Jakarta' } },
        })
        .expect(400);
      expect(res.body.error.code).toBe('IDEMPOTENCY_KEY_REQUIRED');
    });

    it('replays the original result for the same key and rejects payload drift', async () => {
      const owner = await registerUser();
      const key = idem();
      const payload = {
        name: 'Replay Barber',
        primaryOutlet: { name: 'Outlet', address: { formatted: 'Jl. A No. 1, Jakarta' } },
      };
      const first = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', key)
        .send(payload)
        .expect(201);
      const replay = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', key)
        .send(payload)
        .expect(201);
      expect(replay.body.data.id).toBe(first.body.data.id);

      const drift = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', key)
        .send({ ...payload, name: 'Different Name' })
        .expect(409);
      expect(drift.body.error.code).toBe('IDEMPOTENCY_KEY_REUSED');
    });

    it('enforces one owned business per user (ADR 0026)', async () => {
      const owner = await registerUser();
      await createBusiness(owner.accessToken);
      const res = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: 'Second Barber',
          primaryOutlet: { name: 'Outlet', address: { formatted: 'Jl. B No. 2, Jakarta' } },
        })
        .expect(409);
      expect(res.body.error.code).toBe('BUSINESS_LIMIT_REACHED');
    });

    it('creates exactly one business for concurrent submissions with the same key', async () => {
      const owner = await registerUser();
      const key = idem();
      const payload = {
        name: 'Concurrent Barber',
        primaryOutlet: { name: 'Outlet', address: { formatted: 'Jl. C No. 3, Jakarta' } },
      };
      const send = (): Promise<request.Response> =>
        http()
          .post('/api/v1/businesses')
          .set('Authorization', `Bearer ${owner.accessToken}`)
          .set('Idempotency-Key', key)
          .send(payload)
          .then((r) => r);
      const results = await Promise.all([send(), send(), send()]);

      const created = results.filter((r) => r.status === 201);
      expect(created.length).toBeGreaterThanOrEqual(1);
      for (const r of results) {
        expect([201, 409]).toContain(r.status);
        if (r.status === 409) {
          expect(r.body.error.code).toBe('IDEMPOTENCY_REQUEST_IN_PROGRESS');
        }
      }
      const count = await prisma.business.count({ where: { ownerUserId: owner.userId } });
      expect(count).toBe(1);
    });
  });

  describe('discovery', () => {
    it('lists active businesses publicly with price range and pagination meta', async () => {
      const owner = await registerUser();
      const { businessId, name } = await createBusiness(owner.accessToken);
      await createService(owner.accessToken, businessId, 'Haircut', 50000);
      await createService(owner.accessToken, businessId, 'Shave', 30000);

      const res = await http()
        .get(`/api/v1/businesses?q=${encodeURIComponent(name)}`)
        .expect(200);
      expect(res.body.meta.pagination).toMatchObject({ hasMore: false, nextCursor: null });
      const item = res.body.data.items.find((i: { id: string }) => i.id === businessId) as Record<
        string,
        unknown
      >;
      expect(item).toBeDefined();
      expect(item.priceRange).toEqual({
        minimum: { amount: 30000, currency: 'IDR' },
        maximum: { amount: 50000, currency: 'IDR' },
      });
      expect(item.supportedPaymentOptions).toEqual(['pay_at_location']);
      expect((item.primaryOutlet as Record<string, unknown>).id).toBeDefined();
    });

    it('serves public business details with policy summaries', async () => {
      const owner = await registerUser();
      const { businessId } = await createBusiness(owner.accessToken);
      const res = await http().get(`/api/v1/businesses/${businessId}`).expect(200);
      expect(res.body.data.bookingPolicy).toEqual({
        minimumLeadMinutes: 60,
        maximumAdvanceDays: 30,
        automaticConfirmation: true,
      });
      expect(res.body.data.cancellationPolicy.summary).toContain('6 hours');
      expect(res.body.data.outlets).toHaveLength(1);
      expect(res.body.data.outlets[0].operatingHours).toEqual([]);
    });

    it('404s unknown businesses', async () => {
      const res = await http().get('/api/v1/businesses/biz_missing').expect(404);
      expect(res.body.error.code).toBe('BUSINESS_NOT_FOUND');
    });
  });

  describe('business management', () => {
    it('blocks non-members from management and update', async () => {
      const owner = await registerUser();
      const outsider = await registerUser();
      const { businessId } = await createBusiness(owner.accessToken);

      const read = await http()
        .get(`/api/v1/businesses/${businessId}/management`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .expect(403);
      expect(read.body.error.code).toBe('FORBIDDEN_BUSINESS_RESOURCE');

      await http()
        .patch(`/api/v1/businesses/${businessId}`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .send({ name: 'Hijacked' })
        .expect(403);
    });

    it('updates policies and validates payment option labels', async () => {
      const owner = await registerUser();
      const { businessId } = await createBusiness(owner.accessToken);

      const bad = await http()
        .patch(`/api/v1/businesses/${businessId}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ supportedPaymentOptions: ['crypto'] })
        .expect(400);
      expect(bad.body.error.code).toBe('PAYMENT_OPTION_NOT_SUPPORTED');

      const res = await http()
        .patch(`/api/v1/businesses/${businessId}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({
          supportedPaymentOptions: ['pay_at_location', 'deposit'],
          depositPolicy: { enabled: true, defaultType: 'fixed', defaultValue: 15000 },
          bookingPolicy: { minimumLeadMinutes: 120 },
          cancellationPolicy: { fullRefundBeforeMinutes: 240 },
        })
        .expect(200);
      expect(res.body.data.supportedPaymentOptions).toEqual(['pay_at_location', 'deposit']);
      expect(res.body.data.depositPolicy).toEqual({
        enabled: true,
        defaultType: 'fixed',
        defaultValue: 15000,
      });
      expect(res.body.data.bookingPolicy.minimumLeadMinutes).toBe(120);
      expect(res.body.data.cancellationPolicy.fullRefundBeforeMinutes).toBe(240);
    });

    it('updates an outlet and 404s outlets of other businesses', async () => {
      const owner = await registerUser();
      const other = await registerUser();
      const { businessId, outletId } = await createBusiness(owner.accessToken);
      const foreign = await createBusiness(other.accessToken);

      const res = await http()
        .patch(`/api/v1/businesses/${businessId}/outlets/${outletId}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Renamed Outlet', address: { formatted: 'Jl. Updated No. 20, Jakarta' } })
        .expect(200);
      expect(res.body.data.name).toBe('Renamed Outlet');
      expect(res.body.data.address.formatted).toBe('Jl. Updated No. 20, Jakarta');

      const cross = await http()
        .patch(`/api/v1/businesses/${businessId}/outlets/${foreign.outletId}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ name: 'Cross Outlet' })
        .expect(404);
      expect(cross.body.error.code).toBe('OUTLET_NOT_FOUND');
    });
  });

  describe('services', () => {
    it('creates, lists, updates, and deactivates services', async () => {
      const owner = await registerUser();
      const { businessId } = await createBusiness(owner.accessToken);
      const serviceId = await createService(owner.accessToken, businessId);

      const list = await http().get(`/api/v1/businesses/${businessId}/services`).expect(200);
      const item = list.body.data.items[0];
      expect(item.id).toBe(serviceId);
      expect(item.price).toEqual({ amount: 50000, currency: 'IDR' });
      expect(item.deposit).toEqual({
        type: 'fixed',
        value: 10000,
        requiredAmount: { amount: 10000, currency: 'IDR' },
      });

      await http()
        .patch(`/api/v1/businesses/${businessId}/services/${serviceId}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ price: { amount: 60000, currency: 'IDR' } })
        .expect(200);

      const deactivated = await http()
        .post(`/api/v1/businesses/${businessId}/services/${serviceId}/deactivate`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .expect(200);
      expect(deactivated.body.data.isActive).toBe(false);

      const activeList = await http().get(`/api/v1/businesses/${businessId}/services`).expect(200);
      expect(activeList.body.data.items).toHaveLength(0);
      const allList = await http()
        .get(`/api/v1/businesses/${businessId}/services?activeOnly=false`)
        .expect(200);
      expect(allList.body.data.items).toHaveLength(1);
    });

    it('rejects duplicate names, bad durations, and percentage deposits', async () => {
      const owner = await registerUser();
      const { businessId } = await createBusiness(owner.accessToken);
      await createService(owner.accessToken, businessId, 'Haircut');

      const dup = await http()
        .post(`/api/v1/businesses/${businessId}/services`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({ name: '  haircut ', durationMinutes: 30, price: { amount: 1, currency: 'IDR' } })
        .expect(409);
      expect(dup.body.error.code).toBe('SERVICE_NAME_ALREADY_EXISTS');

      const duration = await http()
        .post(`/api/v1/businesses/${businessId}/services`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({ name: 'Zero', durationMinutes: 0, price: { amount: 1, currency: 'IDR' } })
        .expect(400);
      expect(duration.body.error.code).toBe('SERVICE_INVALID_DURATION');

      const deposit = await http()
        .post(`/api/v1/businesses/${businessId}/services`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: 'Percent',
          durationMinutes: 30,
          price: { amount: 10000, currency: 'IDR' },
          deposit: { type: 'percentage', value: 20 },
        })
        .expect(400);
      expect(deposit.body.error.code).toBe('SERVICE_INVALID_DEPOSIT');
    });
  });

  describe('staff invitations', () => {
    it('runs the invite → accept → manage lifecycle', async () => {
      const owner = await registerUser();
      const { businessId, outletId } = await createBusiness(owner.accessToken);
      const serviceId = await createService(owner.accessToken, businessId);
      const inviteeEmail = uniqueEmail();

      const invite = await http()
        .post(`/api/v1/businesses/${businessId}/staff/invitations`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          email: inviteeEmail,
          displayName: 'Andi',
          role: 'barber',
          outletIds: [outletId],
          eligibleServiceIds: [serviceId],
        })
        .expect(201);
      const invitationId = invite.body.data.invitationId as string;
      expect(invitationId).toMatch(/^inv_/);
      expect(email.invitations.at(-1)?.invitationId).toBe(invitationId);

      const dup = await http()
        .post(`/api/v1/businesses/${businessId}/staff/invitations`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({ email: inviteeEmail, displayName: 'Andi', role: 'barber' })
        .expect(409);
      expect(dup.body.error.code).toBe('STAFF_INVITATION_ALREADY_PENDING');

      // Wrong account cannot see someone else's invitation.
      const outsider = await registerUser();
      const stolen = await http()
        .post(`/api/v1/staff/invitations/${invitationId}/accept`)
        .set('Authorization', `Bearer ${outsider.accessToken}`)
        .set('Idempotency-Key', idem())
        .expect(404);
      expect(stolen.body.error.code).toBe('STAFF_INVITATION_NOT_FOUND');

      const invitee = await registerUser(inviteeEmail);
      const accept = await http()
        .post(`/api/v1/staff/invitations/${invitationId}/accept`)
        .set('Authorization', `Bearer ${invitee.accessToken}`)
        .set('Idempotency-Key', idem())
        .expect(200);
      const staffId = accept.body.data.staffId as string;
      expect(staffId).toMatch(/^stf_/);
      expect(accept.body.data).toMatchObject({ businessId, role: 'barber', status: 'active' });

      const me = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${invitee.accessToken}`)
        .expect(200);
      expect(me.body.data.roles).toEqual(['customer', 'staff']);
      expect(me.body.data.businessMemberships[0]).toMatchObject({
        businessId,
        role: 'barber',
        outletIds: [outletId],
      });
      expect(me.body.data.businessMemberships[0].permissions).toContain('queue.manage');

      const publicList = await http().get(`/api/v1/businesses/${businessId}/staff`).expect(200);
      const staffItem = publicList.body.data.items.find(
        (i: { id: string }) => i.id === staffId,
      ) as Record<string, unknown>;
      expect(staffItem).toMatchObject({ name: 'Andi', role: 'barber', isActive: true });
      expect(staffItem.eligibleServiceIds).toEqual([serviceId]);
      expect(staffItem.permissions).toBeUndefined();

      // Re-inviting an active member conflicts.
      const again = await http()
        .post(`/api/v1/businesses/${businessId}/staff/invitations`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({ email: inviteeEmail, displayName: 'Andi', role: 'barber' })
        .expect(409);
      expect(again.body.error.code).toBe('STAFF_ALREADY_MEMBER');

      // Permission change audits.
      const patched = await http()
        .patch(`/api/v1/businesses/${businessId}/staff/${staffId}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ role: 'front_desk', permissions: ['booking.read', 'payment.confirm'] })
        .expect(200);
      expect(patched.body.data.role).toBe('front_desk');
      expect(patched.body.data.permissions).toEqual(['booking.read', 'payment.confirm']);
      const audit = await prisma.auditLog.findFirst({
        where: { resourceType: 'staff_profile', resourceId: staffId },
      });
      expect(audit?.action).toBe('staff.permissions_changed');

      // Staff member without staff.manage cannot manage staff.
      const denied = await http()
        .patch(`/api/v1/businesses/${businessId}/staff/${staffId}`)
        .set('Authorization', `Bearer ${invitee.accessToken}`)
        .send({ displayName: 'Nope' })
        .expect(403);
      expect(denied.body.error.code).toBe('PERMISSION_REQUIRED');

      const off = await http()
        .post(`/api/v1/businesses/${businessId}/staff/${staffId}/deactivate`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .expect(200);
      expect(off.body.data.status).toBe('inactive');
      const membership = await prisma.businessMembership.findUnique({
        where: { businessId_userId: { businessId, userId: invitee.userId } },
      });
      expect(membership?.status).toBe('inactive');
    });

    it('rejects invitations referencing foreign outlets or services', async () => {
      const owner = await registerUser();
      const other = await registerUser();
      const { businessId } = await createBusiness(owner.accessToken);
      const foreign = await createBusiness(other.accessToken);

      const res = await http()
        .post(`/api/v1/businesses/${businessId}/staff/invitations`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          email: uniqueEmail(),
          displayName: 'Andi',
          role: 'barber',
          outletIds: [foreign.outletId],
        })
        .expect(400);
      expect(res.body.error.code).toBe('OUTLET_NOT_IN_BUSINESS');
    });
  });
});
