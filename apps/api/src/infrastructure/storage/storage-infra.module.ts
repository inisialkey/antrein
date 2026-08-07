import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LocalDiskStorageAdapter } from './local-disk.adapter';
import { ObjectStoragePort } from './object-storage.port';

/**
 * Provides ObjectStoragePort per STORAGE_PROVIDER (ADR 0046). Only 'local'
 * exists — a bucket adapter lands here when the deployment grows past one
 * container, and nothing outside this module changes.
 */
@Global()
@Module({
  providers: [
    {
      provide: ObjectStoragePort,
      useFactory: (config: ConfigService): ObjectStoragePort =>
        new LocalDiskStorageAdapter(config.get<string>('STORAGE_LOCAL_ROOT') ?? 'storage'),
      inject: [ConfigService],
    },
  ],
  exports: [ObjectStoragePort],
})
export class StorageInfraModule {}
