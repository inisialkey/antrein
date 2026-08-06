import { Prisma } from '../../generated/prisma/client';

interface DriverAdapterCause {
  originalMessage?: string;
  constraint?: { fields?: string[]; index?: string };
}

/**
 * Which unique constraint a P2002 violated, as one searchable string.
 *
 * Needed only where a single write can trip more than one index (registration
 * touches both the email and the phone one). Under the pg driver adapter
 * Prisma leaves `meta.target` unset and reports the constraint through
 * `meta.driverAdapterError` instead, so both shapes are read here — a wrong
 * guess would report a taken phone number as a taken email.
 *
 * Returns '' for anything that is not a P2002, so callers can test membership
 * without a type guard first.
 */
export function uniqueViolationTarget(error: unknown): string {
  if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
    return '';
  }
  const meta = error.meta as
    { target?: unknown; driverAdapterError?: { cause?: DriverAdapterCause } } | undefined;
  const cause = meta?.driverAdapterError?.cause;
  return [meta?.target, cause?.constraint?.fields, cause?.constraint?.index, cause?.originalMessage]
    .filter((part) => part !== undefined && part !== null)
    .map((part) => (Array.isArray(part) ? part.join(' ') : String(part)))
    .join(' ');
}
