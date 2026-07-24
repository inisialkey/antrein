import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * In-memory sliding-window limiter — sufficient for a single instance per
 * ADR 0035 (Redis becomes mandatory only at >1 instance).
 * ponytail: unbounded per-key arrays are pruned on access and the whole map is
 * swept when it exceeds MAX_KEYS; move to Redis when the API scales out.
 */
const MAX_KEYS = 10_000;

@Injectable()
export class RateLimitService {
  private readonly attempts = new Map<string, number[]>();

  constructor(private readonly disabled: boolean) {}

  static fromConfig(config: ConfigService): RateLimitService {
    return new RateLimitService(config.get<string>('AUTH_RATE_LIMIT_DISABLED') === 'true');
  }

  /** Returns true when the attempt is allowed; false when the limit is hit. */
  consume(bucket: string, key: string, limit: number, windowMs: number): boolean {
    if (this.disabled) return true;

    const now = Date.now();
    const mapKey = `${bucket}:${key}`;
    const kept = (this.attempts.get(mapKey) ?? []).filter((t) => now - t < windowMs);

    if (kept.length >= limit) {
      this.attempts.set(mapKey, kept);
      return false;
    }

    kept.push(now);
    if (this.attempts.size >= MAX_KEYS && !this.attempts.has(mapKey)) {
      this.attempts.clear();
    }
    this.attempts.set(mapKey, kept);
    return true;
  }
}
