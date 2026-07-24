import { fingerprintOf, stableStringify } from './idempotency.service';

describe('stableStringify', () => {
  it('is insensitive to key order', () => {
    expect(stableStringify({ a: 1, b: { d: 2, c: [3, 'x'] } })).toBe(
      stableStringify({ b: { c: [3, 'x'], d: 2 }, a: 1 }),
    );
  });

  it('drops undefined values like JSON does', () => {
    expect(stableStringify({ a: 1, gone: undefined })).toBe(stableStringify({ a: 1 }));
  });

  it('keeps array order significant', () => {
    expect(stableStringify([1, 2])).not.toBe(stableStringify([2, 1]));
  });
});

describe('fingerprintOf', () => {
  it('matches for identical logical requests', () => {
    expect(fingerprintOf('usr_1', 'business.create', { name: 'A', x: 1 })).toBe(
      fingerprintOf('usr_1', 'business.create', { x: 1, name: 'A' }),
    );
  });

  it('differs per principal, action, and payload', () => {
    const base = fingerprintOf('usr_1', 'business.create', { name: 'A' });
    expect(fingerprintOf('usr_2', 'business.create', { name: 'A' })).not.toBe(base);
    expect(fingerprintOf('usr_1', 'service.create', { name: 'A' })).not.toBe(base);
    expect(fingerprintOf('usr_1', 'business.create', { name: 'B' })).not.toBe(base);
  });
});
