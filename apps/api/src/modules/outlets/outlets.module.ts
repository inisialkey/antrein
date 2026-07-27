import { Module } from '@nestjs/common';
import { MembershipsModule } from '../memberships/memberships.module';
import { OutletsController } from './outlets.controller';
import { OutletsService } from './outlets.service';

@Module({
  imports: [MembershipsModule],
  controllers: [OutletsController],
  providers: [OutletsService],
  exports: [OutletsService],
})
export class OutletsModule {}
