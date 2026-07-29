import { validateEnv } from './env.validation';

const minimal = {
  DATABASE_URL: 'postgresql://x:x@localhost:5432/x',
  JWT_ACCESS_SECRET: 'unit-test-secret-at-least-32-characters!!',
};

describe('validateEnv', () => {
  it('accepts minimal config and applies documented defaults', () => {
    const env = validateEnv(minimal);
    expect(env.PORT).toBe(3000);
    expect(env.ACCESS_TOKEN_TTL_MINUTES).toBe(15);
    expect(env.REFRESH_TOKEN_TTL_DAYS).toBe(30);
    expect(env.RESET_TOKEN_TTL_MINUTES).toBe(30);
    expect(env.SMTP_PORT).toBe(1025);
  });

  it('fails fast when DATABASE_URL is missing', () => {
    expect(() => validateEnv({ JWT_ACCESS_SECRET: minimal.JWT_ACCESS_SECRET })).toThrow(
      /DATABASE_URL/,
    );
  });

  it('fails fast when JWT_ACCESS_SECRET is missing or too short', () => {
    expect(() => validateEnv({ DATABASE_URL: minimal.DATABASE_URL })).toThrow(/JWT_ACCESS_SECRET/);
    expect(() => validateEnv({ ...minimal, JWT_ACCESS_SECRET: 'short-secret' })).toThrow(
      /JWT_ACCESS_SECRET/,
    );
  });

  it('rejects non-numeric PORT', () => {
    expect(() => validateEnv({ ...minimal, PORT: 'abc' })).toThrow(/PORT/);
  });

  describe('production guards', () => {
    const production = {
      ...minimal,
      NODE_ENV: 'production',
      PAYMENT_WEBHOOK_SECRET: 'a-real-webhook-secret',
      SMTP_HOST: 'smtp.example.com',
    };

    it('accepts a fully configured production environment', () => {
      expect(() => validateEnv(production)).not.toThrow();
    });

    it('rejects the committed example secrets', () => {
      expect(() =>
        validateEnv({
          ...production,
          JWT_ACCESS_SECRET: 'dev-only-jwt-secret-3f5553520b7c6462608089304169bd8944827c11d597b16b',
        }),
      ).toThrow(/JWT_ACCESS_SECRET/);
      expect(() =>
        validateEnv({ ...production, PAYMENT_WEBHOOK_SECRET: 'sandbox-webhook-secret' }),
      ).toThrow(/PAYMENT_WEBHOOK_SECRET/);
    });

    it('requires SMTP_HOST, a metrics token when metrics are on, and live rate limits', () => {
      expect(() => validateEnv({ ...production, SMTP_HOST: undefined })).toThrow(/SMTP_HOST/);
      expect(() => validateEnv({ ...production, METRICS_ENABLED: 'true' })).toThrow(
        /METRICS_TOKEN/,
      );
      expect(() => validateEnv({ ...production, AUTH_RATE_LIMIT_DISABLED: 'true' })).toThrow(
        /AUTH_RATE_LIMIT_DISABLED/,
      );
    });

    it('leaves non-production environments alone', () => {
      expect(() =>
        validateEnv({ ...minimal, NODE_ENV: 'development', AUTH_RATE_LIMIT_DISABLED: 'true' }),
      ).not.toThrow();
    });
  });
});
