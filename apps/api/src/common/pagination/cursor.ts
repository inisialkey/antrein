import { validationFailed } from '../../modules/auth/auth.errors';

export const DEFAULT_PAGE_LIMIT = 20;
export const MAX_PAGE_LIMIT = 100;

export interface PageMeta {
  nextCursor: string | null;
  hasMore: boolean;
  limit: number;
}

/**
 * Opaque keyset cursor (api-contract §20): base64url JSON of the last row's
 * sort key(s). Clients must treat it as a black box.
 */
export function encodeCursor(payload: Record<string, string>): string {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

export function decodeCursor(cursor: string): Record<string, string> {
  try {
    const parsed: unknown = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error();
    for (const value of Object.values(parsed)) {
      if (typeof value !== 'string') throw new Error();
    }
    return parsed as Record<string, string>;
  } catch {
    throw validationFailed('Cursor is invalid.');
  }
}

export function clampLimit(limit?: number): number {
  if (limit === undefined) return DEFAULT_PAGE_LIMIT;
  return Math.min(Math.max(limit, 1), MAX_PAGE_LIMIT);
}

/**
 * Keyset-paginate an already-fetched rows array that was queried with
 * `take: limit + 1`: slices the page and derives { nextCursor, hasMore }.
 */
export function pageOf<T>(
  rows: T[],
  limit: number,
  cursorOf: (row: T) => Record<string, string>,
): { items: T[]; pagination: PageMeta } {
  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;
  const last = items[items.length - 1];
  return {
    items,
    pagination: {
      nextCursor: hasMore && last !== undefined ? encodeCursor(cursorOf(last)) : null,
      hasMore,
      limit,
    },
  };
}
