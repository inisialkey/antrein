import { Module } from '@nestjs/common';
import { BusinessMemberGuard } from './business-member.guard';
import { MembershipsService } from './memberships.service';

// BusinessMemberGuard is applied per-route with @UseGuards (never APP_GUARD):
// route guards always run after the global AuthGuard, so req.principal is set.
@Module({
  providers: [MembershipsService, BusinessMemberGuard],
  exports: [MembershipsService, BusinessMemberGuard],
})
export class MembershipsModule {}
