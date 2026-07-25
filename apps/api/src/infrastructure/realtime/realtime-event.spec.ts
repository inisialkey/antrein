import { buildEvent, bookingRoom, outletQueueRoom, userRoom } from './realtime-event';

describe('realtime event envelope', () => {
  it('builds a versioned envelope (api-contract §104)', () => {
    const at = new Date('2026-07-22T09:55:00Z');
    const event = buildEvent(
      'queue.entry.updated.v1',
      { type: 'queue_entry', id: 'que_1' },
      5,
      { status: 'called' },
      at,
    );

    expect(event.type).toBe('queue.entry.updated.v1');
    expect(event.resource).toEqual({ type: 'queue_entry', id: 'que_1' });
    expect(event.version).toBe(5);
    expect(event.data).toEqual({ status: 'called' });
    expect(event.occurredAt).toBe('2026-07-22T09:55:00.000Z');
    expect(event.eventId).toMatch(/^evt_/);
  });

  it('gives each event a distinct id', () => {
    const a = buildEvent('x', { type: 't', id: '1' }, 1, {});
    const b = buildEvent('x', { type: 't', id: '1' }, 1, {});
    expect(a.eventId).not.toBe(b.eventId);
  });
});

describe('room names (server-generated, realtime-queue §41)', () => {
  it('scopes rooms by identity', () => {
    expect(userRoom('usr_1')).toBe('user:usr_1');
    expect(bookingRoom('bkg_1')).toBe('booking:bkg_1');
    expect(outletQueueRoom('out_1', '2026-07-22')).toBe('queue:out_1:2026-07-22');
  });
});
