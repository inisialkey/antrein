import { Module } from '@nestjs/common';
import { FilesController } from './files.controller';
import { FilesService } from './files.service';

/**
 * Uploads (§36–§37.1). Owning modules call FilesService.attach inside their own
 * transaction rather than writing the `files` table themselves.
 */
@Module({
  controllers: [FilesController],
  providers: [FilesService],
  exports: [FilesService],
})
export class FilesModule {}
