import { Module } from '@nestjs/common';
import { FilesModule } from '../files/files.module';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { MembershipsModule } from '../memberships/memberships.module';
import { BusinessesController } from './businesses.controller';
import { BusinessesService } from './businesses.service';

@Module({
  imports: [MembershipsModule, IdempotencyModule, FilesModule],
  controllers: [BusinessesController],
  providers: [BusinessesService],
  exports: [BusinessesService],
})
export class BusinessesModule {}
