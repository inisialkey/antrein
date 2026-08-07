import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { fileUrl } from '../../common/files/file-url';
import { newId } from '../../common/id/id';
import { Prisma, PrismaClient } from '../../generated/prisma/client';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { ObjectStoragePort } from '../../infrastructure/storage/object-storage.port';
import { FilePurpose } from './dto/file.dto';
import {
  fileAlreadyAttached,
  fileInvalidContent,
  fileNotFound,
  fileNotOwned,
  fileTooLarge,
  fileTypeNotAllowed,
  fileUploadFailed,
} from './file.errors';
import {
  ALLOWED_IMAGE_MIME_TYPES,
  extensionFor,
  normalizeImageMimeType,
  sniffImageMimeType,
} from './image-sniff';

/** ADR 0034: 5 MB per file across every purpose. */
export const MAX_FILE_BYTES = 5 * 1024 * 1024;

export type FilesDb = PrismaClient | Prisma.TransactionClient;

export interface UploadedFile {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname?: string;
}

@Injectable()
export class FilesService {
  private readonly logger = new Logger(FilesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: ObjectStoragePort,
  ) {}

  /** api-contract §36. */
  async upload(
    userId: string,
    purpose: FilePurpose,
    file: UploadedFile | undefined,
  ): Promise<Record<string, unknown>> {
    if (!file) throw fileInvalidContent();
    if (file.size > MAX_FILE_BYTES) throw fileTooLarge(MAX_FILE_BYTES);

    const declared = normalizeImageMimeType(file.mimetype ?? '');
    if (!(ALLOWED_IMAGE_MIME_TYPES as readonly string[]).includes(declared)) {
      throw fileTypeNotAllowed([...ALLOWED_IMAGE_MIME_TYPES]);
    }
    // The bytes decide, not the header: a renamed .exe declared as image/png
    // would otherwise be served back to browsers under a trusted URL.
    const sniffed = sniffImageMimeType(file.buffer);
    if (sniffed === null || sniffed !== declared) throw fileInvalidContent();

    const id = newId('fil');
    const storageKey = `${purpose}/${id}.${extensionFor(sniffed)}`;
    try {
      await this.storage.put(storageKey, file.buffer, sniffed);
    } catch (error) {
      this.logger.error(`Storage put failed for ${storageKey}: ${(error as Error).message}`);
      throw fileUploadFailed();
    }

    const created = await this.prisma.file.create({
      data: {
        id,
        ownerUserId: userId,
        purpose,
        storageProvider: this.storage.provider,
        storageKey,
        mimeType: sniffed,
        sizeBytes: BigInt(file.size),
        checksum: createHash('sha256').update(file.buffer).digest('hex'),
        // Every MVP purpose is displayed publicly; the id is the only secret.
        visibility: 'public',
        status: 'ready',
        originalFilename: file.originalname ?? null,
      },
    });

    return {
      id: created.id,
      purpose: created.purpose,
      mimeType: created.mimeType,
      size: Number(created.sizeBytes),
      status: created.status,
      url: fileUrl(created.id),
      createdAt: created.createdAt.toISOString(),
    };
  }

  /** api-contract §37.1 — public read; the opaque id is the access control. */
  async readContent(fileId: string): Promise<{ body: Buffer; mimeType: string }> {
    const file = await this.prisma.file.findUnique({ where: { id: fileId } });
    if (!file || file.deletedAt !== null || file.status === 'deleted') throw fileNotFound();
    try {
      return { body: await this.storage.get(file.storageKey), mimeType: file.mimeType };
    } catch (error) {
      this.logger.error(`Storage get failed for ${file.storageKey}: ${(error as Error).message}`);
      throw fileNotFound();
    }
  }

  /** api-contract §37. Attached files are removed by detaching them first. */
  async deleteFile(userId: string, fileId: string): Promise<{ deleted: true }> {
    const file = await this.prisma.file.findUnique({ where: { id: fileId } });
    if (!file || file.deletedAt !== null || file.status === 'deleted') throw fileNotFound();
    if (file.ownerUserId !== userId) throw fileNotOwned();
    if (file.status === 'attached') throw fileAlreadyAttached();

    await this.prisma.file.update({
      where: { id: fileId },
      data: { status: 'deleted', deletedAt: new Date() },
    });
    // Bytes are best-effort: the row is authoritative and a stray object costs
    // disk, whereas a failed delete must not leave the row claiming it exists.
    try {
      await this.storage.delete(file.storageKey);
    } catch (error) {
      this.logger.warn(`Storage delete failed for ${file.storageKey}: ${(error as Error).message}`);
    }
    return { deleted: true };
  }

  /**
   * Marks an uploaded file as attached to a resource, and releases the one it
   * replaces so that orphan stays deletable. Called by the owning module inside
   * its own transaction — files are never written from another module directly.
   */
  async attach(
    input: { fileId: string; actorUserId: string; previousFileId?: string | null },
    db: FilesDb = this.prisma,
  ): Promise<void> {
    const { fileId, actorUserId, previousFileId } = input;
    const file = await db.file.findUnique({ where: { id: fileId } });
    if (!file || file.deletedAt !== null || file.status === 'deleted') throw fileNotFound();
    if (file.ownerUserId !== actorUserId) throw fileNotOwned();

    // Release only after the replacement is known good, or a rejected update
    // would leave the resource pointing at a file nothing can attach again.
    if (previousFileId && previousFileId !== fileId) {
      await db.file.updateMany({
        where: { id: previousFileId, status: 'attached' },
        data: { status: 'ready' },
      });
    }
    if (file.status !== 'attached') {
      await db.file.update({ where: { id: fileId }, data: { status: 'attached' } });
    }
  }
}
