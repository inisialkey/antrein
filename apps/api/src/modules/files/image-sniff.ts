/** Image types accepted by POST /files (api-contract §36, ADR 0034). */
export const ALLOWED_IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;

export type AllowedImageMimeType = (typeof ALLOWED_IMAGE_MIME_TYPES)[number];

/** Clients send both spellings for JPEG; the row stores the canonical one. */
export function normalizeImageMimeType(declared: string): string {
  const value = declared.trim().toLowerCase();
  return value === 'image/jpg' ? 'image/jpeg' : value;
}

/**
 * Identifies an image by its magic bytes. A declared Content-Type is client
 * input — the bytes are what a browser will actually render, so the two must
 * agree before anything is stored (FILE_INVALID_CONTENT).
 */
export function sniffImageMimeType(body: Buffer): AllowedImageMimeType | null {
  if (body.length >= 3 && body[0] === 0xff && body[1] === 0xd8 && body[2] === 0xff) {
    return 'image/jpeg';
  }
  if (body.length >= 8 && body.subarray(0, 8).equals(PNG_SIGNATURE)) {
    return 'image/png';
  }
  if (
    body.length >= 12 &&
    body.subarray(0, 4).toString('latin1') === 'RIFF' &&
    body.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/** Extension used in the storage key; keeps files readable on disk. */
export function extensionFor(mimeType: AllowedImageMimeType): string {
  return mimeType === 'image/jpeg' ? 'jpg' : mimeType === 'image/png' ? 'png' : 'webp';
}
