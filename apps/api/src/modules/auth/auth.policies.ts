import { validationFailed } from './auth.errors';

/** Trim + lowercase only — no destructive normalization (auth doc §8). */
export function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
}

/**
 * Digits (and a leading +) only, so "+62 812-3456" and "+62812 3456" collide on
 * `users_phone_normalized_uq`. Returns null for an absent or empty number —
 * the unique index ignores nulls, so unset phones never conflict.
 */
export function normalizePhoneNumber(raw: string | null | undefined): string | null {
  if (raw === null || raw === undefined) return null;
  const digits = raw.replace(/[^\d+]/g, '').replace(/(?!^)\+/g, '');
  return digits === '' || digits === '+' ? null : digits;
}

/** ADR 0034: 8–128 characters, length-only; leading/trailing whitespace rejected. */
export function validatePasswordPolicy(password: string): void {
  if (password !== password.trim()) {
    throw validationFailed('Password must not start or end with whitespace.');
  }
  if (password.length < 8 || password.length > 128) {
    throw validationFailed('Password must be between 8 and 128 characters.');
  }
}
