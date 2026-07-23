import { normalizeEmail, validatePasswordPolicy } from './auth.policies';

describe('normalizeEmail', () => {
  it('trims and lowercases', () => {
    expect(normalizeEmail('  Oki@Example.COM ')).toBe('oki@example.com');
  });

  it('keeps plus addressing and dots (no destructive normalization)', () => {
    expect(normalizeEmail('o.ki+tag@example.com')).toBe('o.ki+tag@example.com');
  });
});

describe('validatePasswordPolicy (ADR 0034: 8–128 length-only)', () => {
  it('accepts 8 and 128 character passwords, unicode included', () => {
    expect(() => validatePasswordPolicy('12345678')).not.toThrow();
    expect(() => validatePasswordPolicy('a'.repeat(128))).not.toThrow();
    expect(() => validatePasswordPolicy('katasandi-ünïcodé')).not.toThrow();
  });

  it('rejects short, long, and whitespace-padded passwords', () => {
    expect(() => validatePasswordPolicy('1234567')).toThrow(
      expect.objectContaining({ response: expect.objectContaining({ code: 'VALIDATION_FAILED' }) }),
    );
    expect(() => validatePasswordPolicy('a'.repeat(129))).toThrow();
    expect(() => validatePasswordPolicy(' padded-password')).toThrow();
    expect(() => validatePasswordPolicy('padded-password ')).toThrow();
  });

  it('allows interior spaces (passphrases)', () => {
    expect(() => validatePasswordPolicy('correct horse battery staple')).not.toThrow();
  });
});
