import { clampLimit, decodeCursor, encodeCursor, pageOf } from './cursor';
import { ApiError } from '../../modules/auth/auth.errors';

describe('cursor', () => {
  it('round-trips a payload opaquely', () => {
    const cursor = encodeCursor({ name: 'Barber Bros', id: 'biz_01' });
    expect(cursor).not.toContain('Barber');
    expect(decodeCursor(cursor)).toEqual({ name: 'Barber Bros', id: 'biz_01' });
  });

  it('rejects malformed cursors with VALIDATION_FAILED', () => {
    for (const bad of ['not-base64!!', Buffer.from('[1,2]').toString('base64url')]) {
      try {
        decodeCursor(bad);
        fail('expected throw');
      } catch (error) {
        expect(error).toBeInstanceOf(ApiError);
        expect((error as ApiError).getResponse()).toMatchObject({ code: 'VALIDATION_FAILED' });
      }
    }
  });

  it('clamps limits to contract bounds (default 20, max 100)', () => {
    expect(clampLimit(undefined)).toBe(20);
    expect(clampLimit(0)).toBe(1);
    expect(clampLimit(50)).toBe(50);
    expect(clampLimit(500)).toBe(100);
  });

  describe('pageOf', () => {
    const rows = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];

    it('slices the extra row and emits a next cursor', () => {
      const page = pageOf(rows, 2, (r) => ({ id: r.id }));
      expect(page.items.map((r) => r.id)).toEqual(['a', 'b']);
      expect(page.pagination.hasMore).toBe(true);
      expect(decodeCursor(page.pagination.nextCursor as string)).toEqual({ id: 'b' });
    });

    it('reports the final page without a cursor', () => {
      const page = pageOf(rows, 3, (r) => ({ id: r.id }));
      expect(page.items).toHaveLength(3);
      expect(page.pagination).toEqual({ nextCursor: null, hasMore: false, limit: 3 });
    });
  });
});
