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

  @IsOptional()
  @IsString()
  SMTP_HOST?: string;

  @IsInt()
  @Min(1)
  SMTP_PORT = 1025;

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
  return validated;
}
