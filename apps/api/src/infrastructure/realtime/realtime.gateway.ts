import { Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Namespace, Socket } from 'socket.io';
import { newId } from '../../common/id/id';
import { PrismaService } from '../database/prisma.service';
import { MembershipsService } from '../../modules/memberships/memberships.service';
import { TokenService } from '../../modules/auth/token.service';
import { RealtimeEvent, bookingRoom, outletQueueRoom, userRoom } from './realtime-event';
import { RealtimePublisherPort } from './realtime-publisher.port';

interface JoinChannel {
  type: string;
  resourceId: string;
  businessDate?: string;
}
interface JoinPayload {
  requestId?: string;
  channels?: JoinChannel[];
}

/**
 * `/realtime` Socket.IO gateway (api-contract §101–§110). Handshake carries the
 * access token; the connection auto-joins `user:{id}` and further rooms need an
 * authorized `subscription.join.v1`. Doubles as the {@link RealtimePublisherPort}
 * the outbox dispatcher writes to. In-memory adapter only — Redis fan-out for
 * multi-instance is deferred (ADR 0030/0035); a single API instance needs none.
 */
@WebSocketGateway({ namespace: '/realtime' })
export class RealtimeGateway extends RealtimePublisherPort implements OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer() private readonly server!: Namespace;

  constructor(
    private readonly tokens: TokenService,
    private readonly memberships: MembershipsService,
    private readonly prisma: PrismaService,
  ) {
    super();
  }

  async handleConnection(client: Socket): Promise<void> {
    const raw = client.handshake.auth?.accessToken as string | undefined;
    if (!raw) {
      this.reject(client, 'Missing access token.');
      return;
    }
    try {
      const principal = this.tokens.verifyAccessToken(raw);
      client.data.userId = principal.userId;
      await client.join(userRoom(principal.userId));
      const now = new Date().toISOString();
      client.emit('connection.ready.v1', {
        eventId: newId('evt'),
        type: 'connection.ready.v1',
        occurredAt: now,
        data: {
          userId: principal.userId,
          connectionId: client.id,
          serverTime: now,
          heartbeatSeconds: 25,
        },
      });
    } catch {
      this.reject(client, 'Invalid or expired access token.');
    }
  }

  @SubscribeMessage('subscription.join.v1')
  async onSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinPayload,
  ): Promise<void> {
    const userId = client.data.userId as string | undefined;
    if (!userId) {
      client.disconnect(true);
      return;
    }
    const joined: Array<{ type: string; resourceId: string }> = [];
    const rejected: Array<{ type: string; resourceId: string; code: string }> = [];
    for (const channel of payload.channels ?? []) {
      const room = await this.roomFor(userId, channel);
      if (room) {
        await client.join(room);
        joined.push({ type: channel.type, resourceId: channel.resourceId });
      } else {
        rejected.push({
          type: channel.type,
          resourceId: channel.resourceId,
          code: 'FORBIDDEN_QUEUE_RESOURCE',
        });
      }
    }
    client.emit('subscription.joined.v1', { requestId: payload.requestId, joined, rejected });
  }

  // ---- RealtimePublisherPort (called by the outbox dispatcher) -------------

  async publishToUser(userId: string, event: RealtimeEvent): Promise<void> {
    this.server.to(userRoom(userId)).emit(event.type, event);
  }

  async publishToOutletQueue(
    outletId: string,
    businessDate: string,
    event: RealtimeEvent,
  ): Promise<void> {
    this.server.to(outletQueueRoom(outletId, businessDate)).emit(event.type, event);
  }

  // ---- internals ----------------------------------------------------------

  private reject(client: Socket, message: string): void {
    client.emit('server.error.v1', { error: { code: 'UNAUTHENTICATED', message } });
    client.disconnect(true);
  }

  /** Server-authorized room for a requested channel, or null when forbidden. */
  private async roomFor(userId: string, channel: JoinChannel): Promise<string | null> {
    if (channel.type === 'booking') {
      const booking = await this.prisma.booking.findUnique({
        where: { id: channel.resourceId },
        select: { customerUserId: true, businessId: true },
      });
      if (!booking) return null;
      if (booking.customerUserId === userId) return bookingRoom(channel.resourceId);
      return (await this.canReadQueue(userId, booking.businessId))
        ? bookingRoom(channel.resourceId)
        : null;
    }
    if (channel.type === 'outlet_queue') {
      if (!channel.businessDate) return null;
      const outlet = await this.prisma.outlet.findUnique({
        where: { id: channel.resourceId },
        select: { businessId: true },
      });
      if (!outlet) return null;
      return (await this.canReadQueue(userId, outlet.businessId))
        ? outletQueueRoom(channel.resourceId, channel.businessDate)
        : null;
    }
    return null;
  }

  private async canReadQueue(userId: string, businessId: string): Promise<boolean> {
    try {
      await this.memberships.requirePermission(userId, businessId, 'queue.read');
      return true;
    } catch {
      return false;
    }
  }
}
