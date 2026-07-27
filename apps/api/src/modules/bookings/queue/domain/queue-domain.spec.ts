import {
  checkInWindowState,
  estimatedWaitMinutes,
  formatDisplayNumber,
  peopleAheadOf,
} from './queue-math';
import { bookingStatusForQueue, canTransitionQueue, QueueStatus } from './queue-status.policy';

describe('queue-status.policy', () => {
  it('allows the spec §8.2 transitions', () => {
    expect(canTransitionQueue('waiting', 'called')).toBe(true);
    expect(canTransitionQueue('called', 'in_service')).toBe(true);
    expect(canTransitionQueue('called', 'skipped')).toBe(true);
    expect(canTransitionQueue('called', 'no_show')).toBe(true);
    expect(canTransitionQueue('skipped', 'waiting')).toBe(true);
    expect(canTransitionQueue('in_service', 'completed')).toBe(true);
  });

  it('rejects illegal transitions', () => {
    expect(canTransitionQueue('waiting', 'in_service')).toBe(false);
    expect(canTransitionQueue('waiting', 'completed')).toBe(false);
    expect(canTransitionQueue('completed', 'waiting')).toBe(false);
    expect(canTransitionQueue('skipped', 'in_service')).toBe(false);
  });

  it('maps queue status to booking status (§9); skipped keeps booking waiting', () => {
    const cases: Array<[QueueStatus, string]> = [
      ['waiting', 'waiting'],
      ['called', 'called'],
      ['skipped', 'waiting'],
      ['in_service', 'in_service'],
      ['completed', 'completed'],
      ['cancelled', 'cancelled'],
      ['no_show', 'no_show'],
    ];
    for (const [queue, booking] of cases) {
      expect(bookingStatusForQueue(queue)).toBe(booking);
    }
  });
});

describe('formatDisplayNumber', () => {
  it('prefixes and zero-pads to three digits (§15)', () => {
    expect(formatDisplayNumber('A', 12)).toBe('A012');
    expect(formatDisplayNumber('A', 1)).toBe('A001');
    expect(formatDisplayNumber('B', 9)).toBe('B009');
  });

  it('does not truncate numbers past three digits', () => {
    expect(formatDisplayNumber('A', 1234)).toBe('A1234');
  });
});

describe('checkInWindowState', () => {
  const scheduled = new Date('2026-07-22T10:00:00Z');

  it('is too_early before the window opens', () => {
    expect(checkInWindowState(scheduled, new Date('2026-07-22T09:29:00Z'), 30, 15)).toBe(
      'too_early',
    );
  });

  it('is open within the window (bounds inclusive)', () => {
    expect(checkInWindowState(scheduled, new Date('2026-07-22T09:30:00Z'), 30, 15)).toBe('open');
    expect(checkInWindowState(scheduled, new Date('2026-07-22T10:00:00Z'), 30, 15)).toBe('open');
    expect(checkInWindowState(scheduled, new Date('2026-07-22T10:15:00Z'), 30, 15)).toBe('open');
  });

  it('is too_late after the window closes', () => {
    expect(checkInWindowState(scheduled, new Date('2026-07-22T10:16:00Z'), 30, 15)).toBe(
      'too_late',
    );
  });
});

describe('peopleAheadOf', () => {
  const entries: Array<{ id: string; status: QueueStatus }> = [
    { id: 'a', status: 'in_service' },
    { id: 'b', status: 'skipped' },
    { id: 'c', status: 'waiting' },
    { id: 'd', status: 'called' },
    { id: 'e', status: 'waiting' },
  ];

  it('counts active entries before the target, excluding skipped (§35)', () => {
    // ahead of e: a(in_service), c(waiting), d(called) = 3; b(skipped) excluded
    expect(peopleAheadOf(entries, 'e')).toBe(3);
  });

  it('is zero for the first active entry', () => {
    expect(peopleAheadOf(entries, 'a')).toBe(0);
  });

  it('returns 0 when the target is absent', () => {
    expect(peopleAheadOf(entries, 'zzz')).toBe(0);
  });
});

describe('estimatedWaitMinutes', () => {
  it('is people ahead × average service minutes (§36)', () => {
    expect(estimatedWaitMinutes(3, 15)).toBe(45);
  });

  it('never goes negative', () => {
    expect(estimatedWaitMinutes(0, 30)).toBe(0);
    expect(estimatedWaitMinutes(-1, 30)).toBe(0);
  });
});
