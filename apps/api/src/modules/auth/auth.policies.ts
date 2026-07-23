import { validationFailed } from './auth.errors';

/** Trim + lowercase only — no destructive normalization (auth doc §8). */
export function normalizeEmail(raw: string): string {
  return raw.trim().toLowerCase();
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
