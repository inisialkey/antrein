import { randomUUID } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/database/prisma.service';
import {
  EmailPort,
  PasswordChangedEmailInput,
  PasswordResetEmailInput,
  StaffInvitationEmailInput,
} from '../src/infrastructure/email/email.port';
import { MAX_FILE_BYTES } from '../src/modules/files/files.service';

jest.setTimeout(120_000);

class SilentEmail extends EmailPort {
  async sendPasswordReset(_input: PasswordResetEmailInput): Promise<void> {}
  async sendPasswordChanged(_input: PasswordChangedEmailInput): Promise<void> {}
  async sendStaffInvitation(_input: StaffInvitationEmailInput): Promise<void> {}
}

const PASSWORD = 'integration-password-1';

/** Smallest byte strings that satisfy the magic-byte check for each format. */
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('antrein-test-png'),
]);
const JPEG = Buffer.concat([
  Buffer.from([0xff, 0xd8, 0xff, 0xe0]),
  Buffer.from('antrein-test-jpg'),
]);

describe('Files + profile writes (integration)', () => {
  let app: INestApplication;
  let http: () => request.Agent;
  let prisma: PrismaService;
  let storageRoot: string;

  const uniqueEmail = (): string => `it-file-${randomUUID()}@example.com`;
  const idem = (): string => `idem_${randomUUID()}`;

  const registerUser = async (): Promise<{ userId: string; accessToken: string }> => {
    const res = await http()
      .post('/api/v1/auth/register')
      .send({ name: 'File User', email: uniqueEmail(), password: PASSWORD })
      .expect(201);
    return { userId: res.body.data.user.id, accessToken: res.body.data.session.accessToken };
  };

  const upload = (token: string, body: Buffer, contentType: string, purpose: string) =>
    http()
      .post('/api/v1/files')
      .set('Authorization', `Bearer ${token}`)
      .field('purpose', purpose)
      .attach('file', body, { filename: 'image.bin', contentType });

  let token: string;

  beforeAll(async () => {
    process.env.AUTH_RATE_LIMIT_DISABLED = 'true';
    process.env.PAYMENT_EXPIRATION_JOB_INTERVAL_MS = '0';
    process.env.OUTBOX_DISPATCHER_INTERVAL_MS = '0';
    storageRoot = await mkdtemp(join(tmpdir(), 'antrein-files-'));
    process.env.STORAGE_LOCAL_ROOT = storageRoot;
    process.env.PUBLIC_API_URL = 'https://api.test.example';

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(EmailPort)
      .useValue(new SilentEmail())
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
    http = () => request(app.getHttpServer());
    prisma = app.get(PrismaService);

    token = (await registerUser()).accessToken;
  });

  afterAll(async () => {
    await app?.close();
    await rm(storageRoot, { recursive: true, force: true });
    delete process.env.STORAGE_LOCAL_ROOT;
    delete process.env.PUBLIC_API_URL;
  });

  describe('POST /files (§36)', () => {
    it('stores an image and serves the exact bytes back without auth', async () => {
      const res = await upload(token, PNG, 'image/png', 'customer_avatar').expect(201);

      expect(res.body.data).toMatchObject({
        purpose: 'customer_avatar',
        mimeType: 'image/png',
        size: PNG.length,
        status: 'ready',
      });
      const fileId = res.body.data.id as string;
      expect(fileId).toMatch(/^fil_/);
      expect(res.body.data.url).toBe(`https://api.test.example/api/v1/files/${fileId}/content`);

      const content = await http().get(`/api/v1/files/${fileId}/content`).expect(200);
      expect(content.headers['content-type']).toContain('image/png');
      expect(Buffer.from(content.body)).toEqual(PNG);
    });

    it('accepts the image/jpg spelling and stores the canonical type', async () => {
      const res = await upload(token, JPEG, 'image/jpg', 'service_image').expect(201);
      expect(res.body.data.mimeType).toBe('image/jpeg');
    });

    it('rejects a type outside the allow list', async () => {
      const gif = Buffer.from('GIF89a-not-really');
      const res = await upload(token, gif, 'image/gif', 'customer_avatar').expect(415);
      expect(res.body.error.code).toBe('FILE_TYPE_NOT_ALLOWED');
    });

    it('rejects bytes that disagree with the declared type', async () => {
      const res = await upload(token, JPEG, 'image/png', 'customer_avatar').expect(400);
      expect(res.body.error.code).toBe('FILE_INVALID_CONTENT');
    });

    it('rejects a file over the 5 MB limit with the contract code', async () => {
      const huge = Buffer.concat([PNG, Buffer.alloc(MAX_FILE_BYTES)]);
      const res = await upload(token, huge, 'image/png', 'customer_avatar').expect(413);
      expect(res.body.error.code).toBe('FILE_TOO_LARGE');
    });

    it('rejects an unknown purpose', async () => {
      const res = await upload(token, PNG, 'image/png', 'nonsense').expect(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    });

    it('requires authentication', async () => {
      await http()
        .post('/api/v1/files')
        .field('purpose', 'customer_avatar')
        .attach('file', PNG, { filename: 'x.png', contentType: 'image/png' })
        .expect(401);
    });
  });

  describe('DELETE /files/{fileId} (§37)', () => {
    it('deletes an unattached file and stops serving it', async () => {
      const created = await upload(token, PNG, 'image/png', 'customer_avatar').expect(201);
      const fileId = created.body.data.id as string;

      const res = await http()
        .delete(`/api/v1/files/${fileId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);
      expect(res.body.data).toEqual({ deleted: true });

      await http().get(`/api/v1/files/${fileId}/content`).expect(404);
      await http()
        .delete(`/api/v1/files/${fileId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(404);
    });

    it('refuses to delete another account’s file', async () => {
      const created = await upload(token, PNG, 'image/png', 'customer_avatar').expect(201);
      const stranger = await registerUser();

      const res = await http()
        .delete(`/api/v1/files/${created.body.data.id}`)
        .set('Authorization', `Bearer ${stranger.accessToken}`)
        .expect(403);
      expect(res.body.error.code).toBe('FILE_NOT_OWNED');
    });

    it('refuses to delete a file that is attached to a resource', async () => {
      const created = await upload(token, PNG, 'image/png', 'customer_avatar').expect(201);
      await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${token}`)
        .send({ avatarFileId: created.body.data.id })
        .expect(200);

      const res = await http()
        .delete(`/api/v1/files/${created.body.data.id}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(409);
      expect(res.body.error.code).toBe('FILE_ALREADY_ATTACHED');
    });
  });

  describe('PATCH /me (§32)', () => {
    it('updates name and phone and leaves omitted fields alone', async () => {
      const user = await registerUser();
      const phone = `+62811${Date.now().toString().slice(-8)}`;

      const res = await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Renamed Owner', phoneNumber: phone })
        .expect(200);
      expect(res.body.data).toMatchObject({
        id: user.userId,
        name: 'Renamed Owner',
        phoneNumber: phone,
        avatarUrl: null,
      });

      await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ name: 'Renamed Again' })
        .expect(200);
      const me = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .expect(200);
      expect(me.body.data).toMatchObject({ name: 'Renamed Again', phoneNumber: phone });
    });

    it('attaches an avatar and exposes it on /me', async () => {
      const user = await registerUser();
      const file = await upload(user.accessToken, PNG, 'image/png', 'customer_avatar').expect(201);

      await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ avatarFileId: file.body.data.id })
        .expect(200);

      const me = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .expect(200);
      expect(me.body.data.avatarUrl).toBe(file.body.data.url);
      expect((await prisma.file.findUnique({ where: { id: file.body.data.id } }))?.status).toBe(
        'attached',
      );
    });

    it('releases the replaced avatar so it becomes deletable again', async () => {
      const user = await registerUser();
      const first = await upload(user.accessToken, PNG, 'image/png', 'customer_avatar').expect(201);
      const second = await upload(user.accessToken, JPEG, 'image/jpeg', 'customer_avatar').expect(
        201,
      );

      for (const id of [first.body.data.id, second.body.data.id]) {
        await http()
          .patch('/api/v1/me')
          .set('Authorization', `Bearer ${user.accessToken}`)
          .send({ avatarFileId: id })
          .expect(200);
      }

      await http()
        .delete(`/api/v1/files/${first.body.data.id}`)
        .set('Authorization', `Bearer ${user.accessToken}`)
        .expect(200);
    });

    it('refuses an avatar uploaded by another account', async () => {
      const owner = await registerUser();
      const stranger = await registerUser();
      const file = await upload(owner.accessToken, PNG, 'image/png', 'customer_avatar').expect(201);

      const res = await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${stranger.accessToken}`)
        .send({ avatarFileId: file.body.data.id })
        .expect(403);
      expect(res.body.error.code).toBe('FILE_NOT_OWNED');
    });

    it('reports a missing avatar file id', async () => {
      const user = await registerUser();
      const res = await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ avatarFileId: 'fil_missing' })
        .expect(404);
      expect(res.body.error.code).toBe('FILE_NOT_FOUND');
    });

    it('rejects a phone number already used by another account', async () => {
      const phone = `+62812${Date.now().toString().slice(-8)}`;
      const first = await registerUser();
      const second = await registerUser();

      await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${first.accessToken}`)
        .send({ phoneNumber: phone })
        .expect(200);

      // Same number, different formatting — normalization is what makes the
      // unique index bite.
      const res = await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${second.accessToken}`)
        .send({ phoneNumber: phone.replace('+62', '+62 ').replace(/(\d{4})$/, '-$1') })
        .expect(409);
      expect(res.body.error.code).toBe('USER_PHONE_ALREADY_USED');
    });

    it('clears the phone number when it is sent as null', async () => {
      const user = await registerUser();
      const phone = `+62813${Date.now().toString().slice(-8)}`;
      await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ phoneNumber: phone })
        .expect(200);

      const res = await http()
        .patch('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ phoneNumber: null })
        .expect(200);
      expect(res.body.data.phoneNumber).toBeNull();
    });
  });

  describe('PATCH /me/notification-preferences (§33)', () => {
    it('updates only the flags it is given', async () => {
      const user = await registerUser();

      const res = await http()
        .patch('/api/v1/me/notification-preferences')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ marketing: true })
        .expect(200);
      expect(res.body.data).toMatchObject({
        bookingUpdates: true,
        paymentUpdates: true,
        queueUpdates: true,
        marketing: true,
      });

      await http()
        .patch('/api/v1/me/notification-preferences')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .send({ queueUpdates: false })
        .expect(200);

      const me = await http()
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${user.accessToken}`)
        .expect(200);
      expect(me.body.data.notificationPreferences).toMatchObject({
        queueUpdates: false,
        marketing: true,
      });
    });
  });

  describe('business logo and service image', () => {
    it('attaches a logo on create and returns it as a URL', async () => {
      const owner = await registerUser();
      const logo = await upload(owner.accessToken, PNG, 'image/png', 'business_logo').expect(201);

      const business = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: `Logo Barber ${randomUUID().slice(0, 8)}`,
          logoFileId: logo.body.data.id,
          primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 10' } },
        })
        .expect(201);

      const detail = await http().get(`/api/v1/businesses/${business.body.data.id}`).expect(200);
      expect(detail.body.data.logoUrl).toBe(logo.body.data.url);
    });

    it('attaches an image on service create and swaps it on update', async () => {
      const owner = await registerUser();
      const business = await http()
        .post('/api/v1/businesses')
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: `Image Barber ${randomUUID().slice(0, 8)}`,
          primaryOutlet: { name: 'Main Outlet', address: { formatted: 'Jl. Example No. 10' } },
        })
        .expect(201);
      const businessId = business.body.data.id as string;

      const first = await upload(owner.accessToken, PNG, 'image/png', 'service_image').expect(201);
      const created = await http()
        .post(`/api/v1/businesses/${businessId}/services`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .set('Idempotency-Key', idem())
        .send({
          name: 'Haircut',
          durationMinutes: 45,
          price: { amount: 50000, currency: 'IDR' },
          imageFileId: first.body.data.id,
        })
        .expect(201);
      expect(created.body.data.imageUrl).toBe(first.body.data.url);

      const second = await upload(owner.accessToken, JPEG, 'image/jpeg', 'service_image').expect(
        201,
      );
      const updated = await http()
        .patch(`/api/v1/businesses/${businessId}/services/${created.body.data.id}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .send({ imageFileId: second.body.data.id })
        .expect(200);
      expect(updated.body.data.imageUrl).toBe(second.body.data.url);

      // The replaced image is released, the live one is not.
      await http()
        .delete(`/api/v1/files/${first.body.data.id}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .expect(200);
      await http()
        .delete(`/api/v1/files/${second.body.data.id}`)
        .set('Authorization', `Bearer ${owner.accessToken}`)
        .expect(409);
    });
  });
});
