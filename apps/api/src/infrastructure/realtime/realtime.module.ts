import { Module } from '@nestjs/common';
import { AuthModule } from '../../modules/auth/auth.module';
import { MembershipsModule } from '../../modules/memberships/memberships.module';
import { RealtimeGateway } from './realtime.gateway';
import { RealtimePublisherPort } from './realtime-publisher.port';

/**
 * WebSocket transport (realtime-queue §39). Owns the `/realtime` gateway and
 * exposes the {@link RealtimePublisherPort} the bookings outbox dispatcher drains
 * to. PrismaService comes from the global PrismaModule.
 */
@Module({
  imports: [AuthModule, MembershipsModule],
  providers: [RealtimeGateway, { provide: RealtimePublisherPort, useExisting: RealtimeGateway }],
  exports: [RealtimePublisherPort],
})
export class RealtimeModule {}
