import { randomUUID } from 'node:crypto';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { newId } from '../src/common/id/id';
import {
  EmailPort,
  PasswordChangedEmailInput,
  PasswordResetEmailInput,
  StaffInvitationEmailInput,
} from '../src/infrastructure/email/email.port';
import { PrismaService } from '../src/infrastructure/database/prisma.service';
import { PasswordHasher } from '../src/modules/auth/password.hasher';
import { TokenService } from '../src/modules/auth/token.service';

jest.setTimeout(120_000);

class CapturingEmail extends EmailPort {
  resets: PasswordResetEmailInput[] = [];
  changes: PasswordChangedEmailInput[] = [];
  invitations: StaffInvitationEmailInput[] = [];
  async sendPasswordReset(input: PasswordResetEmailInput): Promise<void> {
    this.resets.push(input);
  }
  async sendPasswordChanged(input: PasswordChangedEmailInput): Promise<void> {
    this.changes.push(input);
  }
  async sendStaffInvitation(input: StaffInvitationEmailInput): Promise<void> {
    this.invitations.push(input);
  }
}

const PASSWORD = 'integration-password-1';

describe('Auth endpoints (integration)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let email: CapturingEmail;
  let http: () => request.Agent;

  const uniqueEmail = (): string => `it-${randomUUID()}@example.com`;

  const registerUser = async (
    emailAddr = uniqueEmail(),
  ): Promise<{ email: string; userId: string; accessToken: string; refreshToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'Integration User', email: emailAddr, password: PASSWORD })
      .expect(201);
    return {
      email: emailAddr,
      userId: res.body.data.user.id,
      accessToken: res.body.data.session.accessToken,
      refreshToken: res.body.data.session.refreshToken,
    };
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

  describe('register', () => {
    it('creates a user, preferences, and an initial session', async () => {
      const emailAddr = uniqueEmail();
      const res = await http()
        .post('/api/v1/auth/register')
        .send({ name: 'Oki', email: emailAddr, phoneNumber: '+6281234567890', password: PASSWORD })
        .expect(201);

      expect(res.body.success).toBe(true);
      const { user, session } = res.body.data;
      expect(user.id).toMatch(/^usr_/);
      expect(user.email).toBe(emailAddr);
      expect(user.status).toBe('active');
      expect(user.roles).toEqual(['customer']);
      expect(session.refreshToken).toMatch(/^ses_[0-9A-HJKMNP-TV-Z]{26}\./);

      const prefs = await prisma.userNotificationPreference.findUnique({
        where: { userId: user.id },
      });
      expect(prefs?.marketing).toBe(false);

      const me = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${session.accessToken}`)
        .expect(200);
      expect(me.body.data.id).toBe(user.id);
      expect(me.body.data.notificationPreferences.bookingUpdates).toBe(true);
    });

    it('rejects a duplicate email case-insensitively with 409', async () => {
      const emailAddr = uniqueEmail();
      await registerUser(emailAddr);
      const res = await http()
        .post('/api/v1/auth/register')
        .send({ name: 'Dup', email: emailAddr.toUpperCase(), password: PASSWORD })
        .expect(409);
      expect(res.body.error.code).toBe('AUTH_EMAIL_ALREADY_REGISTERED');
    });

    it('rejects passwords outside the 8–128 policy', async () => {
      const res = await http()
        .post('/api/v1/auth/register')
        .send({ name: 'Weak', email: uniqueEmail(), password: '1234567' })
        .expect(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    });

    it('lets exactly one of two concurrent registrations win the same email', async () => {
      const emailAddr = uniqueEmail();
      const payload = { name: 'Race', email: emailAddr, password: PASSWORD };
      const [a, b] = await Promise.all([
        http().post('/api/v1/auth/register').send(payload),
        http().post('/api/v1/auth/register').send(payload),
      ]);
      expect([a.status, b.status].sort()).toEqual([201, 409]);
      const users = await prisma.user.findMany({ where: { emailNormalized: emailAddr } });
      expect(users).toHaveLength(1);
    });
  });

  describe('login', () => {
    it('returns a session for valid credentials and registers the device', async () => {
      const { email: emailAddr, userId } = await registerUser();
      const deviceId = `device_${randomUUID()}`;
      const res = await http()
        .post('/api/v1/auth/login')
        .send({
          email: emailAddr,
          password: PASSWORD,
          device: { deviceId, platform: 'android', appVersion: '1.0.0', deviceName: 'Pixel 9' },
        })
        .expect(200);
      expect(res.body.data.user.id).toBe(userId);

      const device = await prisma.device.findUnique({ where: { id: deviceId } });
      expect(device?.userId).toBe(userId);
      expect(device?.status).toBe('active');

      const user = await prisma.user.findUnique({ where: { id: userId } });
      expect(user?.lastLoginAt).not.toBeNull();
    });

    it('returns the same 401 for wrong password and unknown email', async () => {
      const { email: emailAddr } = await registerUser();
      const wrongPw = await http()
        .post('/api/v1/auth/login')
        .send({ email: emailAddr, password: 'definitely-wrong-1' })
        .expect(401);
      const unknown = await http()
        .post('/api/v1/auth/login')
        .send({ email: uniqueEmail(), password: PASSWORD })
        .expect(401);
      expect(wrongPw.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
      expect(unknown.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
    });

    it('blocks suspended accounts with 403', async () => {
      const { email: emailAddr, userId } = await registerUser();
      await prisma.user.update({ where: { id: userId }, data: { status: 'suspended' } });
      const res = await http()
        .post('/api/v1/auth/login')
        .send({ email: emailAddr, password: PASSWORD })
        .expect(403);
      expect(res.body.error.code).toBe('AUTH_ACCOUNT_SUSPENDED');
    });
  });

  describe('refresh rotation and reuse detection', () => {
    it('rotates the token, then treats the old token as reuse and kills the family', async () => {
      const { refreshToken: rt0 } = await registerUser();
      const sessionId0 = rt0.split('.')[0];

      const rotated = await http()
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: rt0 })
        .expect(200);
      const rt1 = rotated.body.data.refreshToken as string;
      expect(rt1).not.toBe(rt0);
      expect(rotated.body.data.accessToken).toEqual(expect.any(String));

      // Presenting rt0 again is strict reuse: family compromised (ADR 0039).
      const reused = await http()
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: rt0 })
        .expect(401);
      expect(reused.body.error.code).toBe('AUTH_REFRESH_TOKEN_REUSED');

      const family = await prisma.authSession.findMany({ where: { tokenFamilyId: sessionId0 } });
      expect(family.filter((s) => s.status === 'active')).toHaveLength(0);
      expect(family.some((s) => s.status === 'compromised')).toBe(true);

      // The successor issued before the reuse is dead too.
      const successorRefresh = await http()
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: rt1 })
        .expect(401);
      expect(successorRefresh.body.error.code).toBe('AUTH_SESSION_REVOKED');
    });

    it('lets exactly one of two concurrent refreshes win (§65)', async () => {
      const { refreshToken } = await registerUser();
      const sessionId = refreshToken.split('.')[0];

      const [a, b] = await Promise.all([
        http().post('/api/v1/auth/refresh').send({ refreshToken }),
        http().post('/api/v1/auth/refresh').send({ refreshToken }),
      ]);
      expect([a.status, b.status].sort()).toEqual([200, 401]);
      const loser = a.status === 401 ? a : b;
      expect(loser.body.error.code).toBe('AUTH_REFRESH_TOKEN_REUSED');

      // Strict policy: the race compromises the whole family — no active successor.
      const family = await prisma.authSession.findMany({ where: { tokenFamilyId: sessionId } });
      expect(family.filter((s) => s.status === 'active')).toHaveLength(0);
    });

    it('rejects malformed and unknown refresh tokens', async () => {
      await http().post('/api/v1/auth/refresh').send({ refreshToken: 'garbage' }).expect(401);
      const unknown = await http()
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: 'ses_01ARZ3NDEKTSV4RRFFQ69G5FAV.secret' })
        .expect(401);
      expect(unknown.body.error.code).toBe('AUTH_REFRESH_TOKEN_INVALID');
    });

    it('rejects an expired session with AUTH_REFRESH_TOKEN_EXPIRED', async () => {
      const { refreshToken } = await registerUser();
      const sessionId = refreshToken.split('.')[0];
      await prisma.authSession.update({
        where: { id: sessionId },
        data: {
          issuedAt: new Date(Date.now() - 2 * 3600_000),
          expiresAt: new Date(Date.now() - 3600_000),
        },
      });
      const res = await http().post('/api/v1/auth/refresh').send({ refreshToken }).expect(401);
      expect(res.body.error.code).toBe('AUTH_REFRESH_TOKEN_EXPIRED');
      const session = await prisma.authSession.findUnique({ where: { id: sessionId } });
      expect(session?.status).toBe('expired');
    });
  });

  describe('logout', () => {
    it('revokes the session, rejects further refresh, and stays idempotent', async () => {
      const emailAddr = uniqueEmail();
      await registerUser(emailAddr);
      const deviceId = `device_${randomUUID()}`;
      const login = await http()
        .post('/api/v1/auth/login')
        .send({
          email: emailAddr,
          password: PASSWORD,
          device: { deviceId, platform: 'ios' },
        })
        .expect(200);
      const { accessToken, refreshToken } = login.body.data.session;

      const out = await http()
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({})
        .expect(200);
      expect(out.body.data.loggedOut).toBe(true);

      const refreshAfter = await http()
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(401);
      expect(refreshAfter.body.error.code).toBe('AUTH_SESSION_REVOKED');

      // Push deactivated for the signed-out device (ADR 0039).
      const device = await prisma.device.findUnique({ where: { id: deviceId } });
      expect(device?.status).toBe('inactive');

      await http()
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({})
        .expect(200);
    });

    it('requires a bearer token', async () => {
      const res = await http().post('/api/v1/auth/logout').send({}).expect(401);
      expect(res.body.error.code).toBe('AUTH_ACCESS_TOKEN_INVALID');
    });
  });

  describe('access token validation', () => {
    it('rejects expired access tokens with AUTH_ACCESS_TOKEN_EXPIRED', async () => {
      const { userId, refreshToken } = await registerUser();
      const expiredSigner = new TokenService({
        accessSecret: process.env.JWT_ACCESS_SECRET as string,
        accessTtlMinutes: -1,
        refreshTtlDays: 30,
        issuer: process.env.JWT_ISSUER ?? 'antrein-api',
        audience: process.env.JWT_AUDIENCE ?? 'antrein-mobile',
      });
      const { token } = expiredSigner.signAccessToken(userId, refreshToken.split('.')[0]);
      const res = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(401);
      expect(res.body.error.code).toBe('AUTH_ACCESS_TOKEN_EXPIRED');
    });

    it('rejects tampered and missing bearer tokens', async () => {
      const missing = await http().get('/api/v1/me').expect(401);
      expect(missing.body.error.code).toBe('AUTH_ACCESS_TOKEN_INVALID');
      const tampered = await http()
        .get('/api/v1/me')
        .set('Authorization', 'Bearer not-a-jwt')
        .expect(401);
      expect(tampered.body.error.code).toBe('AUTH_ACCESS_TOKEN_INVALID');
    });
  });

  describe('password reset', () => {
    it('accepts forgot requests for known and unknown emails identically', async () => {
      const { email: emailAddr } = await registerUser();
      const known = await http()
        .post('/api/v1/auth/password/forgot')
        .send({ email: emailAddr })
        .expect(200);
      const unknown = await http()
        .post('/api/v1/auth/password/forgot')
        .send({ email: uniqueEmail() })
        .expect(200);
      expect(known.body.data).toEqual({ accepted: true });
      expect(unknown.body.data).toEqual({ accepted: true });
      expect(email.resets.some((r) => r.to === emailAddr)).toBe(true);
    });

    it('completes the reset: new password works, all sessions die, token is single-use', async () => {
      const { email: emailAddr, refreshToken } = await registerUser();
      await http().post('/api/v1/auth/password/forgot').send({ email: emailAddr }).expect(200);
      const token = email.resets.find((r) => r.to === emailAddr)!.token;

      const newPassword = 'brand-new-password-9';
      const res = await http()
        .post('/api/v1/auth/password/reset')
        .send({ token, newPassword })
        .expect(200);
      expect(res.body.data).toEqual({ passwordReset: true, allSessionsRevoked: true });

      await http()
        .post('/api/v1/auth/login')
        .send({ email: emailAddr, password: PASSWORD })
        .expect(401);
      await http()
        .post('/api/v1/auth/login')
        .send({ email: emailAddr, password: newPassword })
        .expect(200);

      const oldSession = await http()
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(401);
      expect(oldSession.body.error.code).toBe('AUTH_SESSION_REVOKED');

      const replay = await http()
        .post('/api/v1/auth/password/reset')
        .send({ token, newPassword: 'yet-another-password-3' })
        .expect(400);
      expect(replay.body.error.code).toBe('AUTH_RESET_TOKEN_INVALID');
      expect(email.changes.some((c) => c.to === emailAddr)).toBe(true);
    });

    it('rejects reusing the current password', async () => {
      const { email: emailAddr } = await registerUser();
      await http().post('/api/v1/auth/password/forgot').send({ email: emailAddr }).expect(200);
      const token = email.resets.find((r) => r.to === emailAddr)!.token;
      const res = await http()
        .post('/api/v1/auth/password/reset')
        .send({ token, newPassword: PASSWORD })
        .expect(400);
      expect(res.body.error.code).toBe('AUTH_PASSWORD_REUSE_NOT_ALLOWED');
    });

    it('rejects invalid and expired tokens with distinct codes', async () => {
      const invalid = await http()
        .post('/api/v1/auth/password/reset')
        .send({ token: 'nonsense-token', newPassword: 'whatever-password-1' })
        .expect(400);
      expect(invalid.body.error.code).toBe('AUTH_RESET_TOKEN_INVALID');

      const { email: emailAddr, userId } = await registerUser();
      await http().post('/api/v1/auth/password/forgot').send({ email: emailAddr }).expect(200);
      const token = email.resets.find((r) => r.to === emailAddr)!.token;
      await prisma.passwordResetToken.updateMany({
        where: { userId },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });
      const expired = await http()
        .post('/api/v1/auth/password/reset')
        .send({ token, newPassword: 'whatever-password-1' })
        .expect(410);
      expect(expired.body.error.code).toBe('AUTH_RESET_TOKEN_EXPIRED');
    });

    it('invalidates the previous token when a new one is requested', async () => {
      const { email: emailAddr } = await registerUser();
      await http().post('/api/v1/auth/password/forgot').send({ email: emailAddr }).expect(200);
      const first = email.resets.find((r) => r.to === emailAddr)!.token;
      await http().post('/api/v1/auth/password/forgot').send({ email: emailAddr }).expect(200);

      const res = await http()
        .post('/api/v1/auth/password/reset')
        .send({ token: first, newPassword: 'whatever-password-2' })
        .expect(400);
      expect(res.body.error.code).toBe('AUTH_RESET_TOKEN_INVALID');
    });

    it('lets exactly one of two concurrent resets win the same token (§65)', async () => {
      const { email: emailAddr } = await registerUser();
      await http().post('/api/v1/auth/password/forgot').send({ email: emailAddr }).expect(200);
      const token = email.resets.find((r) => r.to === emailAddr)!.token;

      const [a, b] = await Promise.all([
        http()
          .post('/api/v1/auth/password/reset')
          .send({ token, newPassword: 'race-password-aaa-1' }),
        http()
          .post('/api/v1/auth/password/reset')
          .send({ token, newPassword: 'race-password-bbb-2' }),
      ]);
      expect([a.status, b.status].sort()).toEqual([200, 400]);

      const winner = a.status === 200 ? 'race-password-aaa-1' : 'race-password-bbb-2';
      await http()
        .post('/api/v1/auth/login')
        .send({ email: emailAddr, password: winner })
        .expect(200);
    });
  });
});

describe('Auth rate limiting (integration, limits active)', () => {
  let app: INestApplication;
  let http: () => request.Agent;

  beforeAll(async () => {
    delete process.env.AUTH_RATE_LIMIT_DISABLED;
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(new CapturingEmail())
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    http = () => request(app.getHttpServer());
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns 429 RATE_LIMIT_EXCEEDED after 5 login attempts per IP+email', async () => {
    const prisma = app.get(PrismaService);
    const hasher = app.get(PasswordHasher);
    const emailAddr = `rate-${randomUUID()}@example.com`;
    await prisma.user.create({
      data: {
        id: newId('usr'),
        email: emailAddr,
        emailNormalized: emailAddr,
        name: 'Rate Limited',
        passwordHash: await hasher.hash(PASSWORD),
      },
    });

    for (let i = 0; i < 5; i++) {
      await http()
        .post('/api/v1/auth/login')
        .send({ email: emailAddr, password: 'wrong-password-1' })
        .expect(401);
    }
    const blocked = await http()
      .post('/api/v1/auth/login')
      .send({ email: emailAddr, password: 'wrong-password-1' })
      .expect(429);
    expect(blocked.body.error.code).toBe('RATE_LIMIT_EXCEEDED');
  });
});
