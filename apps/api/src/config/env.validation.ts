import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Min,
  MinLength,
  validateSync,
} from 'class-validator';

export enum NodeEnv {
  Development = 'development',
  Test = 'test',
  Staging = 'staging',
  Production = 'production',
}

export class EnvironmentVariables {
  @IsEnum(NodeEnv)
  NODE_ENV: NodeEnv = NodeEnv.Development;

  @IsInt()
  @Min(1)
  PORT = 3000;

  @IsString()
  DATABASE_URL!: string;

  @IsOptional()
  @IsUrl({ require_tld: false, protocols: ['redis', 'rediss'] })
  REDIS_URL?: string;

  @IsInt()
  @Min(1)
  ACCESS_TOKEN_TTL_MINUTES = 15;

  @IsInt()
  @Min(1)
  REFRESH_TOKEN_TTL_DAYS = 30;

  @IsString()
  @MinLength(32)
  JWT_ACCESS_SECRET!: string;

  @IsOptional()
  @IsString()
  JWT_ISSUER?: string;

  @IsOptional()
  @IsString()
  JWT_AUDIENCE?: string;

  @IsInt()
  @Min(5)
  RESET_TOKEN_TTL_MINUTES = 30;

  /**
   * 'true' when the API sits behind exactly one TLS reverse proxy (ADR 0045).
   * Without it Express reports the proxy's IP for every request, which would
   * collapse the per-IP auth rate-limit buckets into one shared bucket.
   */
  @IsOptional()
  @IsString()
  TRUST_PROXY?: string;

  @IsOptional()
  @IsString()
  SMTP_HOST?: string;

  @IsInt()
  @Min(1)
  SMTP_PORT = 1025;

  /** ESP relay credentials (ADR 0045); unset locally so Mailpit needs no auth. */
  @IsOptional()
  @IsString()
  SMTP_USER?: string;

  @IsOptional()
  @IsString()
  SMTP_PASSWORD?: string;

  /** 'true' for implicit TLS (port 465); STARTTLS on 587 needs no flag. */
  @IsOptional()
  @IsString()
  SMTP_SECURE?: string;

  @IsOptional()
  @IsString()
  EMAIL_FROM?: string;

  /** 'true' disables in-memory auth rate limits — integration tests only. */
  @IsOptional()
  @IsString()
  AUTH_RATE_LIMIT_DISABLED?: string;

  /** Payment provider adapter: 'sandbox' (deterministic local provider) or 'none'. */
  @IsIn(['sandbox', 'none'])
  PAYMENT_PROVIDER = 'sandbox';

  @IsString()
  @MinLength(8)
  PAYMENT_WEBHOOK_SECRET = 'sandbox-webhook-secret';

  /** ADR 0033: server-side online payment expiry. */
  @IsInt()
  @Min(1)
  PAYMENT_EXPIRATION_MINUTES = 30;

  /** ADR 0040: expiration job cadence; 0 disables the timer (tests drive runOnce). */
  @IsInt()
  @Min(0)
  PAYMENT_EXPIRATION_JOB_INTERVAL_MS = 60_000;

  /** Outbox dispatcher cadence (realtime-queue §49); 0 disables the timer (tests drive runOnce). */
  @IsInt()
  @Min(0)
  OUTBOX_DISPATCHER_INTERVAL_MS = 2_000;

  /** ADR 0040: provider/refund reconciliation cadence; 0 disables the timer. */
  @IsInt()
  @Min(0)
  PAYMENT_RECONCILIATION_INTERVAL_MS = 300_000;

  /** Booking-payment §82 + realtime-queue §63 detector cadence; 0 disables the timer. */
  @IsInt()
  @Min(0)
  CONSISTENCY_CHECK_INTERVAL_MS = 86_400_000;

  /** 'true' exposes GET /metrics (Prometheus text). */
  @IsOptional()
  @IsString()
  METRICS_ENABLED?: string;

  /** When set, /metrics requires `Authorization: Bearer <token>`. */
  @IsOptional()
  @IsString()
  METRICS_TOKEN?: string;

  /** Push adapter (ADR 0044): 'log' (observable local default), 'onesignal' or 'none'. */
  @IsIn(['log', 'none', 'onesignal'])
  PUSH_PROVIDER = 'log';

  @IsOptional()
  @IsString()
  ONESIGNAL_APP_ID?: string;

  @IsOptional()
  @IsString()
  ONESIGNAL_API_KEY?: string;

  /** Object storage adapter (ADR 0046). Only 'local' exists in the MVP. */
  @IsIn(['local'])
  STORAGE_PROVIDER = 'local';

  /** Directory the local adapter writes to; relative paths resolve from cwd. */
  @IsString()
  STORAGE_LOCAL_ROOT = 'storage';

  /** Origin used to build public file URLs (§37.1); must match the deployed host. */
  @IsString()
  PUBLIC_API_URL = 'http://localhost:3000';
}

const NUMERIC_KEYS = [
  'PORT',
  'ACCESS_TOKEN_TTL_MINUTES',
  'REFRESH_TOKEN_TTL_DAYS',
  'RESET_TOKEN_TTL_MINUTES',
  'SMTP_PORT',
  'PAYMENT_EXPIRATION_MINUTES',
  'PAYMENT_EXPIRATION_JOB_INTERVAL_MS',
  'OUTBOX_DISPATCHER_INTERVAL_MS',
  'PAYMENT_RECONCILIATION_INTERVAL_MS',
  'CONSISTENCY_CHECK_INTERVAL_MS',
] as const;

/** Committed placeholders (.env.example, class defaults) — fatal in production. */
const PLACEHOLDER_SECRETS = new Set([
  'dev-only-jwt-secret-3f5553520b7c6462608089304169bd8944827c11d597b16b',
  'sandbox-webhook-secret',
]);

/**
 * Backend-brief §94 "strong secrets": a committed placeholder that boots fine
 * locally must never reach production. Checked after class-validator so the
 * message lists every problem at once.
 */
function assertProductionConfig(env: EnvironmentVariables): void {
  const problems: string[] = [];

  if (PLACEHOLDER_SECRETS.has(env.JWT_ACCESS_SECRET)) {
    problems.push('JWT_ACCESS_SECRET is the committed example secret');
  }
  if (PLACEHOLDER_SECRETS.has(env.PAYMENT_WEBHOOK_SECRET)) {
    problems.push('PAYMENT_WEBHOOK_SECRET is the default sandbox secret');
  }
  if (!env.SMTP_HOST) {
    problems.push('SMTP_HOST is required (password reset is delivered over SMTP)');
  }
  if (env.METRICS_ENABLED === 'true' && !env.METRICS_TOKEN) {
    problems.push('METRICS_TOKEN is required whenever METRICS_ENABLED=true');
  }
  if (env.AUTH_RATE_LIMIT_DISABLED === 'true') {
    problems.push('AUTH_RATE_LIMIT_DISABLED is a test-only escape hatch');
  }
  // PUBLIC_API_URL is baked into every file URL handed to a client (§37.1), so
  // the localhost default would ship images nobody can load.
  if (!/^https:\/\//.test(env.PUBLIC_API_URL)) {
    problems.push('PUBLIC_API_URL must be the public https origin of this API');
  }

  if (problems.length > 0) {
    throw new Error(`Invalid production configuration — ${problems.join('; ')}`);
  }
}

export function validateEnv(config: Record<string, unknown>): EnvironmentVariables {
  // Env values arrive as strings; coerce numerics explicitly instead of relying
  // on class-transformer implicit conversion (breaks under ts-jest metadata).
  const coerced: Record<string, unknown> = { ...config };
  for (const key of NUMERIC_KEYS) {
    const value = coerced[key];
    if (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) {
      coerced[key] = Number(value);
    }
  }
  const validated = plainToInstance(EnvironmentVariables, coerced, {
    exposeDefaultValues: true,
  });
  const errors = validateSync(validated, { whitelist: true });
  if (errors.length > 0) {
    const details = errors
      .map((e) => `${e.property}: ${Object.values(e.constraints ?? {}).join(', ')}`)
      .join('; ');
    throw new Error(`Invalid environment configuration — ${details}`);
  }
  if (validated.NODE_ENV === NodeEnv.Production) {
    assertProductionConfig(validated);
  }
  return validated;
}
