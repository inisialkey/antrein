import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma } from '../../generated/prisma/client';
import { ApiError, validationFailed } from '../auth/auth.errors';
import {
  idempotencyKeyRequired,
  idempotencyKeyReused,
  idempotencyRequestInProgress,
} from './idempotency.errors';

const DEFAULT_RETENTION_HOURS = 24; // ADR 0034; payments pass 24 * 7
const PROCESSING_TAKEOVER_MS = 60_000;

export interface IdempotentExecuteOptions<T> {
  scopeType: 'user';
  scopeId: string;
  action: string;
  /** Raw Idempotency-Key header value; missing → IDEMPOTENCY_KEY_REQUIRED. */
  key: string | undefined;
  /** Request body + route params relevant to the action (contract §23.4). */
  payload: unknown;
  retentionHours?: number;
  /**
   * Error codes that must NOT be replayed from the store (e.g. provider
   * outage): the claim is dropped so the same key can retry the operation.
   * The run() itself must make such a retry safe (ADR 0040).
   */
  transientErrorCodes?: string[];
  run: () => Promise<T>;
  resourceOf?: (result: T) => { type: string; id: string };
}

/** Key-stable JSON so retries fingerprint identically regardless of key order. */
export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== 'object') return JSON.stringify(value) ?? 'undefined';
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, v]) => v !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([k, v]) => `${JSON.stringify(k)}:${stableStringify(v)}`);
  return `{${entries.join(',')}}`;
}

export function fingerprintOf(scopeId: string, action: string, payload: unknown): string {
  return createHash('sha256')
    .update(`${scopeId}\n${action}\n${stableStringify(payload)}`)
    .digest('hex');
}

/**
 * Database-backed idempotency (api-contract §23, database-design §48): the
 * unique (scope_type, scope_id, action, idempotency_key) row decides who runs;
 * losers replay the stored outcome or get a conflict.
 */
@Injectable()
export class IdempotencyService {
  constructor(private readonly prisma: PrismaService) {}

  async execute<T>(opts: IdempotentExecuteOptions<T>): Promise<T> {
    const key = opts.key?.trim();
    if (!key) throw idempotencyKeyRequired();
    if (key.length > 200) throw validationFailed('Idempotency-Key is too long.');

    const fingerprint = fingerprintOf(opts.scopeId, opts.action, opts.payload);
    const expiresAt = new Date(
      Date.now() + (opts.retentionHours ?? DEFAULT_RETENTION_HOURS) * 3_600_000,
    );

    let rowId: string;
    try {
      const row = await this.prisma.idempotencyKey.create({
        data: {
          id: newId('idm'),
          scopeType: opts.scopeType,
          scopeId: opts.scopeId,
          action: opts.action,
          idempotencyKey: key,
          requestFingerprint: fingerprint,
          status: 'processing',
          expiresAt,
        },
      });
      rowId = row.id;
    } catch (error) {
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
        throw error;
      }
      const existing = await this.prisma.idempotencyKey.findUnique({
        where: {
          scopeType_scopeId_action_idempotencyKey: {
            scopeType: opts.scopeType,
            scopeId: opts.scopeId,
            action: opts.action,
            idempotencyKey: key,
          },
        },
      });
      if (!existing) throw idempotencyRequestInProgress();
      if (existing.requestFingerprint !== fingerprint) throw idempotencyKeyReused();
      if (existing.status === 'succeeded') return existing.responseBody as T;
      if (existing.status === 'failed_final') {
        const body = existing.responseBody as { message?: string } | null;
        throw new ApiError(
          existing.responseStatus ?? 500,
          existing.errorCode ?? 'INTERNAL_ERROR',
          body?.message ?? 'The original request failed.',
        );
      }
      // processing: allow takeover only when the previous attempt looks dead.
      const takeover = await this.prisma.idempotencyKey.updateMany({
        where: {
          id: existing.id,
          status: 'processing',
          updatedAt: { lt: new Date(Date.now() - PROCESSING_TAKEOVER_MS) },
        },
        data: { requestFingerprint: fingerprint, expiresAt },
      });
      if (takeover.count !== 1) throw idempotencyRequestInProgress();
      rowId = existing.id;
    }

    try {
      const result = await opts.run();
      const resource = opts.resourceOf?.(result);
      await this.prisma.idempotencyKey.update({
        where: { id: rowId },
        data: {
          status: 'succeeded',
          responseStatus: 200,
          responseBody: result as Prisma.InputJsonValue,
          resourceType: resource?.type,
          resourceId: resource?.id,
        },
      });
      return result;
    } catch (error) {
      if (
        error instanceof ApiError &&
        !opts.transientErrorCodes?.includes((error.getResponse() as { code?: string }).code ?? '')
      ) {
        const response = error.getResponse() as { code?: string; message?: string };
        await this.prisma.idempotencyKey.update({
          where: { id: rowId },
          data: {
            status: 'failed_final',
            responseStatus: error.getStatus(),
            errorCode: response.code,
            responseBody: { message: response.message } as Prisma.InputJsonValue,
          },
        });
      } else {
        // Unknown failure: drop the claim so the client can retry cleanly.
        await this.prisma.idempotencyKey.delete({ where: { id: rowId } }).catch(() => undefined);
      }
      throw error;
    }
  }
}
