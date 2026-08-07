import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, resolve, sep } from 'node:path';
import { ObjectStoragePort } from './object-storage.port';

/**
 * Files on a mounted volume (ADR 0046). The demo VPS runs one API container,
 * so a bind-mounted directory is the whole of "object storage" — an S3 adapter
 * is a drop-in replacement behind the port on the day a second instance exists.
 */
export class LocalDiskStorageAdapter extends ObjectStoragePort {
  readonly provider = 'local';

  private readonly root: string;

  constructor(root: string) {
    super();
    this.root = isAbsolute(root) ? root : resolve(process.cwd(), root);
  }

  async put(key: string, body: Buffer): Promise<void> {
    const path = this.pathFor(key);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, body);
  }

  get(key: string): Promise<Buffer> {
    return readFile(this.pathFor(key));
  }

  async delete(key: string): Promise<void> {
    await rm(this.pathFor(key), { force: true });
  }

  /**
   * Keys are server-generated today, but a traversal here would hand out any
   * file the process can read — cheap enough to verify every time.
   */
  private pathFor(key: string): string {
    const path = resolve(join(this.root, key));
    if (path !== this.root && !path.startsWith(this.root + sep)) {
      throw new Error(`Storage key escapes the storage root: ${key}`);
    }
    return path;
  }
}
