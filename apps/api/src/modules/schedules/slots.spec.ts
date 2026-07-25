import { ApiError } from '../auth/auth.errors';
import {
  buildSlots,
  dbTimeToString,
  jakartaDateString,
  jakartaDateTime,
  jakartaDayOfWeek,
  subtractRanges,
  timeToDb,
  toMinutes,
  toTimeString,
  validatePeriods,
} from './slots';

const codeOf = (fn: () => unknown): string => {
  try {
    fn();
  } catch (error) {
    if (error instanceof ApiError) return (error.getResponse() as { code: string }).code;
    throw error;
  }
  throw new Error('expected throw');
};

describe('time helpers', () => {
  it('converts HH:MM to minutes and back', () => {
    expect(toMinutes('00:00')).toBe(0);
    expect(toMinutes('09:00')).toBe(540);
    expect(toMinutes('23:59')).toBe(1439);
    expect(toTimeString(540)).toBe('09:00');
    expect(toTimeString(1439)).toBe('23:59');
  });

  it('round-trips HH:MM through db time values', () => {
    const db = timeToDb('09:30');
    expect(db.getUTCHours()).toBe(9);
    expect(db.getUTCMinutes()).toBe(30);
    expect(dbTimeToString(db)).toBe('09:30');
  });

  it('computes Jakarta business date and weekday', () => {
    // 18:00 UTC = 01:00 next day in Jakarta (UTC+7).
    expect(jakartaDateString(new Date('2026-07-24T18:00:00Z'))).toBe('2026-07-25');
    expect(jakartaDateString(new Date('2026-07-24T10:00:00Z'))).toBe('2026-07-24');
    // 2026-07-24 is a Friday.
    expect(jakartaDayOfWeek('2026-07-24')).toBe(5);
    expect(jakartaDayOfWeek('2026-07-26')).toBe(0);
  });

  it('builds absolute instants from Jakarta wall time', () => {
    expect(jakartaDateTime('2026-07-24', toMinutes('09:00')).toISOString()).toBe(
      '2026-07-24T02:00:00.000Z',
    );
  });
});

describe('validatePeriods', () => {
  it('accepts periods and returns sorted minute ranges', () => {
    expect(
      validatePeriods([
        { start: '13:00', end: '21:00' },
        { start: '09:00', end: '12:00' },
      ]),
    ).toEqual([
      { start: 540, end: 720 },
      { start: 780, end: 1260 },
    ]);
  });

  it('rejects malformed times as SCHEDULE_INVALID_PERIOD', () => {
    expect(codeOf(() => validatePeriods([{ start: '9:00', end: '12:00' }]))).toBe(
      'SCHEDULE_INVALID_PERIOD',
    );
    expect(codeOf(() => validatePeriods([{ start: '09:00', end: '24:00' }]))).toBe(
      'SCHEDULE_INVALID_PERIOD',
    );
  });

  it('rejects empty and inverted periods as SCHEDULE_INVALID_PERIOD', () => {
    expect(codeOf(() => validatePeriods([{ start: '12:00', end: '12:00' }]))).toBe(
      'SCHEDULE_INVALID_PERIOD',
    );
    expect(codeOf(() => validatePeriods([{ start: '13:00', end: '12:00' }]))).toBe(
      'SCHEDULE_INVALID_PERIOD',
    );
  });

  it('rejects overlapping periods as SCHEDULE_OVERLAPPING_PERIODS', () => {
    expect(
      codeOf(() =>
        validatePeriods([
          { start: '09:00', end: '12:00' },
          { start: '11:00', end: '13:00' },
        ]),
      ),
    ).toBe('SCHEDULE_OVERLAPPING_PERIODS');
  });

  it('allows back-to-back periods', () => {
    expect(
      validatePeriods([
        { start: '09:00', end: '12:00' },
        { start: '12:00', end: '15:00' },
      ]),
    ).toHaveLength(2);
  });
});

describe('subtractRanges', () => {
  const r = (start: number, end: number) => ({ start, end });

  it('splits a range around a cut', () => {
    expect(subtractRanges([r(540, 1020)], [r(720, 780)])).toEqual([r(540, 720), r(780, 1020)]);
  });

  it('returns base unchanged for disjoint cuts', () => {
    expect(subtractRanges([r(540, 720)], [r(720, 780)])).toEqual([r(540, 720)]);
  });

  it('clamps cuts overlapping an edge', () => {
    expect(subtractRanges([r(540, 720)], [r(500, 600)])).toEqual([r(600, 720)]);
  });

  it('removes fully covered ranges', () => {
    expect(subtractRanges([r(540, 720)], [r(500, 800)])).toEqual([]);
  });
});

describe('buildSlots', () => {
  const base = {
    date: '2026-07-25',
    durationMinutes: 45,
    outletPeriods: [{ start: toMinutes('09:00'), end: toMinutes('12:00') }],
    staffAvailability: [{ start: toMinutes('09:00'), end: toMinutes('12:00') }],
    leadCutoff: null,
  };

  it('steps the outlet period by service duration', () => {
    const slots = buildSlots(base);
    expect(slots.map((s) => s.startsAt)).toEqual([
      '2026-07-25T09:00:00+07:00',
      '2026-07-25T09:45:00+07:00',
      '2026-07-25T10:30:00+07:00',
      '2026-07-25T11:15:00+07:00',
    ]);
    expect(slots[0].endsAt).toBe('2026-07-25T09:45:00+07:00');
    expect(slots.every((s) => s.available)).toBe(true);
  });

  it('marks slots unavailable when staff does not cover them fully', () => {
    const slots = buildSlots({
      ...base,
      staffAvailability: [{ start: toMinutes('09:00'), end: toMinutes('11:00') }],
    });
    expect(slots.map((s) => s.available)).toEqual([true, true, false, false]);
  });

  it('marks slots before the lead cutoff unavailable', () => {
    const slots = buildSlots({
      ...base,
      leadCutoff: new Date('2026-07-25T09:50:00+07:00'),
    });
    expect(slots.map((s) => s.available)).toEqual([false, false, true, true]);
  });

  it('returns no slots when the outlet is closed', () => {
    expect(buildSlots({ ...base, outletPeriods: [] })).toEqual([]);
  });

  it('drops slots that would run past closing', () => {
    const slots = buildSlots({
      ...base,
      outletPeriods: [{ start: toMinutes('09:00'), end: toMinutes('10:00') }],
    });
    expect(slots).toHaveLength(1);
  });
});
