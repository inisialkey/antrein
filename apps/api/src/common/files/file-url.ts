/**
 * Public URL of an uploaded file (api-contract §37.1).
 *
 * The id is the whole address, so any mapper resolves a URL from the
 * `*_file_id` column it already selected — no join, no config threaded through
 * pure mappers. `PUBLIC_API_URL` is read per call so tests can set it.
 */
export function fileUrl(fileId: string | null | undefined): string | null {
  if (!fileId) return null;
  const base = (process.env.PUBLIC_API_URL ?? 'http://localhost:3000').replace(/\/+$/, '');
  return `${base}/api/v1/files/${fileId}/content`;
}
