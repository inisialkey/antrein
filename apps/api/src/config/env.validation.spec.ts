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
});
