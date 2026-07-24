/**
 * URL slug from a business name: lowercase ASCII, hyphen-separated.
 * Uniqueness is owned by the DB (businesses_slug_uq); callers append a
 * numeric suffix on collision.
 */
export function slugify(name: string): string {
  const base = name
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return base || 'business';
}

export function withSuffix(slug: string, attempt: number): string {
  return attempt === 0 ? slug : `${slug}-${attempt + 1}`;
}
