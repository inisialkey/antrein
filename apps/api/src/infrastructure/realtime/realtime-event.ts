import { newId } from '../../common/id/id';

/** Common WebSocket event envelope (api-contract §104). */
export interface RealtimeEvent {
  eventId: string;
  type: string;
  occurredAt: string;
  resource: { type: string; id: string };
  version: number;
  data: Record<string, unknown>;
}

/** Build a versioned event envelope. `occurredAt` defaults to now. */
export function buildEvent(
  type: string,
  resource: { type: string; id: string },
  version: number,
  data: Record<string, unknown>,
  at: Date = new Date(),
): RealtimeEvent {
  return {
    eventId: newId('evt'),
    type,
    occurredAt: at.toISOString(),
    resource,
    version,
    data,
  };
}

// Room names are server-generated (realtime-queue §41); clients request semantic
// subscriptions, never raw room strings.
export const userRoom = (userId: string): string => `user:${userId}`;
export const bookingRoom = (bookingId: string): string => `booking:${bookingId}`;
export const outletQueueRoom = (outletId: string, businessDate: string): string =>
  `queue:${outletId}:${businessDate}`;
