import { PasswordHasher } from './password.hasher';

describe('PasswordHasher', () => {
  const hasher = new PasswordHasher();

  it('hashes and verifies a password', async () => {
    const hash = await hasher.hash('correct horse battery');
    expect(hash).toMatch(/^\$argon2id\$/);
    await expect(hasher.verify(hash, 'correct horse battery')).resolves.toBe(true);
    await expect(hasher.verify(hash, 'wrong password')).resolves.toBe(false);
  });

  it('embeds the pinned ADR 0039 parameters', async () => {
    const hash = await hasher.hash('parameter check pw');
    expect(hash).toContain('m=65536');
    expect(hash).toContain('t=3');
    expect(hash).toContain('p=4');
    expect(hasher.needsRehash(hash)).toBe(false);
  });

  it('flags hashes with outdated parameters for rehash', () => {
    // Argon2id hash of "x" produced with m=19456,t=2,p=1 (previous OWASP profile).
    const oldHash = '$argon2id$v=19$m=19456,t=2,p=1$K5ZGlmZ2ZzZmRzYWZk$Vm8xY2Rrc2Rmc2Rmc2Rmcw';
    expect(hasher.needsRehash(oldHash)).toBe(true);
  });

  it('provides a dummy verification for unknown users (timing shield)', async () => {
    await expect(hasher.verifyAgainstDummy('any password')).resolves.toBe(false);
  });
});
