/**
 * Binary object boundary (architecture §14). Keys are server-generated and
 * opaque to callers; the adapter owns how they map onto disk/bucket paths.
 * A thrown error means the operation failed — the files module turns that into
 * FILE_UPLOAD_FAILED rather than leaking a provider message.
 */
export abstract class ObjectStoragePort {
  /** Recorded on `files.storage_provider` so a later migration can find rows. */
  abstract readonly provider: string;

  /** `mimeType` is stored by providers that serve bytes directly (S3, GCS). */
  abstract put(key: string, body: Buffer, mimeType: string): Promise<void>;

  abstract get(key: string): Promise<Buffer>;

  abstract delete(key: string): Promise<void>;
}
