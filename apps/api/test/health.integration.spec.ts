import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Health endpoints (integration)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1', { exclude: ['health/live', 'health/ready'] });
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health/live returns ok without envelope', async () => {
    const res = await request(app.getHttpServer()).get('/health/live').expect(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toEqual(expect.any(String));
    expect(res.body.success).toBeUndefined();
  });

  it('GET /health/ready reports database and migrations up', async () => {
    const res = await request(app.getHttpServer()).get('/health/ready').expect(200);
    expect(res.body.status).toBe('ready');
    expect(res.body.checks).toEqual({ database: 'up', migrations: 'up' });
  });

  it('unknown route returns the contract error envelope with request id', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/nope')
      .set('X-Request-Id', 'req_test_123')
      .expect(404);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('NOT_FOUND');
    expect(res.body.meta.requestId).toBe('req_test_123');
    expect(res.headers['x-request-id']).toBe('req_test_123');
  });
});
