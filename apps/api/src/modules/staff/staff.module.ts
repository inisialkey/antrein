import { Module } from '@nestjs/common';
import { EmailModule } from '../../infrastructure/email/email.module';
import { AuditModule } from '../audit/audit.module';
import { IdempotencyModule } from '../idempotency/idempotency.module';
import { MembershipsModule } from '../memberships/memberships.module';
import { InvitationAcceptController, StaffController } from './staff.controller';
import { InvitationsService } from './invitations.service';
import { StaffService } from './staff.service';

@Module({
  imports: [MembershipsModule, IdempotencyModule, AuditModule, EmailModule],
  controllers: [StaffController, InvitationAcceptController],
  providers: [StaffService, InvitationsService],
  exports: [StaffService],
})
export class StaffModule {}
