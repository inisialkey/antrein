import { plainToInstance } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, IsString, IsUrl, Min, validateSync } from 'class-validator';

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
}

const NUMERIC_KEYS = ['PORT', 'ACCESS_TOKEN_TTL_MINUTES', 'REFRESH_TOKEN_TTL_DAYS'] as const;

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
