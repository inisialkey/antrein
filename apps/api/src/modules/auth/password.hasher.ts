import { Injectable } from '@nestjs/common';
import * as argon2 from 'argon2';

/** Argon2id parameters pinned by ADR 0039 (OWASP-aligned). */
const ARGON2_OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 65536, // 64 MiB
  timeCost: 3,
  parallelism: 4,
} as const;

@Injectable()
export class PasswordHasher {
  /** Constant hash verified for unknown users so login timing stays uniform (§36). */
  private readonly dummyHashPromise = argon2.hash('antrein-dummy-timing-shield', ARGON2_OPTIONS);

  hash(password: string): Promise<string> {
    return argon2.hash(password, ARGON2_OPTIONS);
  }

  async verify(hash: string, password: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, password);
    } catch {
      // Malformed/legacy digest — treat as non-matching, never throw at login.
      return false;
    }
  }

  needsRehash(hash: string): boolean {
    return argon2.needsRehash(hash, ARGON2_OPTIONS);
  }

  async verifyAgainstDummy(password: string): Promise<false> {
    await argon2.verify(await this.dummyHashPromise, password).catch(() => false);
    return false;
  }
}
