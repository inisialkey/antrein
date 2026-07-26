import { Module } from '@nestjs/common';
import { MembershipsModule } from '../memberships/memberships.module';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

@Module({
  imports: [MembershipsModule],
  controllers: [ReportsController],
  providers: [ReportsService],
})
export class ReportsModule {}
