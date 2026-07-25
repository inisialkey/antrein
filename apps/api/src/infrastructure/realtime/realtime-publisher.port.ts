import { RealtimeEvent } from './realtime-event';

/**
 * Realtime fan-out port (realtime-queue §75). The outbox dispatcher writes to
 * this; queue mutations never call it directly (they enqueue outbox rows). The
 * gateway is the concrete adapter — an abstract class so it doubles as the DI token.
 */
export abstract class RealtimePublisherPort {
  abstract publishToUser(userId: string, event: RealtimeEvent): Promise<void>;
  abstract publishToOutletQueue(
    outletId: string,
    businessDate: string,
    event: RealtimeEvent,
  ): Promise<void>;
}
