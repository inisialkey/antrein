import { validateEnv } from './env.validation';

const minimal = { DATABASE_URL: 'postgresql://x:x@localhost:5432/x' };

describe('validateEnv', () => {
  it('accepts minimal config and applies documented defaults', () => {
    const env = validateEnv(minimal);
    expect(env.PORT).toBe(3000);
    expect(env.ACCESS_TOKEN_TTL_MINUTES).toBe(15);
    expect(env.REFRESH_TOKEN_TTL_DAYS).toBe(30);
  });

  it('fails fast when DATABASE_URL is missing', () => {
    expect(() => validateEnv({})).toThrow(/DATABASE_URL/);
  });

  it('rejects non-numeric PORT', () => {
    expect(() => validateEnv({ ...minimal, PORT: 'abc' })).toThrow(/PORT/);
  });
});
