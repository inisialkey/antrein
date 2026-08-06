import { Module } from '@nestjs/common';
import { FilesModule } from '../files/files.module';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { MembershipsModule } from '../memberships/memberships.module';
import { ServicesController } from './services.controller';
import { ServicesService } from './services.service';

@Module({
  imports: [MembershipsModule, IdempotencyModule, FilesModule],
  controllers: [ServicesController],
  providers: [ServicesService],
  exports: [ServicesService],
})
export class ServicesModule {}
