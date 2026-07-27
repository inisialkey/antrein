import { scheduleInvalidPeriod, scheduleOverlappingPeriods } from './schedule.errors';

/**
 * Pure scheduling math. Minutes since midnight, ranges half-open [start, end).
 * ponytail: Asia/Jakarta is fixed UTC+7 with no DST, so offset arithmetic replaces
 * a timezone library; revisit only if multi-timezone outlets ever land.
 */

export interface MinuteRange {
  start: number;
  end: number;
}

export const JAKARTA_UTC_OFFSET_MINUTES = 7 * 60;

const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

export function toMinutes(time: string): number {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
}

export function toTimeString(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

/** Postgres `time` columns travel through Prisma as Date; keep them on the UTC clock. */
export function timeToDb(time: string): Date {
  return new Date(Date.UTC(1970, 0, 1, ...(time.split(':').map(Number) as [number, number])));
}

export function dbTimeToString(value: Date): string {
  return toTimeString(value.getUTCHours() * 60 + value.getUTCMinutes());
}

/** Business date (YYYY-MM-DD) as seen on a Jakarta wall clock. */
export function jakartaDateString(now: Date): string {
  return new Date(now.getTime() + JAKARTA_UTC_OFFSET_MINUTES * 60_000).toISOString().slice(0, 10);
}

/** 0 = Sunday … 6 = Saturday, matching database-design §22. */
export function jakartaDayOfWeek(date: string): number {
  return new Date(`${date}T00:00:00Z`).getUTCDay();
}

/** Absolute instant for a Jakarta wall time on the given date. */
export function jakartaDateTime(date: string, minutes: number): Date {
  return new Date(Date.parse(`${date}T00:00:00+07:00`) + minutes * 60_000);
}

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/**
 * Validate HH:MM periods: format, start < end, no overlap. Returns sorted ranges.
 * Back-to-back periods (12:00/12:00) are allowed.
 */
export function validatePeriods(periods: Array<{ start: string; end: string }>): MinuteRange[] {
  const ranges = periods.map(({ start, end }) => {
    if (!TIME_RE.test(start) || !TIME_RE.test(end)) throw scheduleInvalidPeriod();
    const range = { start: toMinutes(start), end: toMinutes(end) };
    if (range.start >= range.end) throw scheduleInvalidPeriod();
    return range;
  });
  ranges.sort((a, b) => a.start - b.start);
  for (let i = 1; i < ranges.length; i += 1) {
    if (ranges[i].start < ranges[i - 1].end) throw scheduleOverlappingPeriods();
  }
  return ranges;
}

/** base minus cuts, both sorted or not; result sorted. */
export function subtractRanges(base: MinuteRange[], cuts: MinuteRange[]): MinuteRange[] {
  let result = [...base].sort((a, b) => a.start - b.start);
  for (const cut of cuts) {
    result = result.flatMap((range) => {
      if (cut.end <= range.start || cut.start >= range.end) return [range];
      const kept: MinuteRange[] = [];
      if (cut.start > range.start) kept.push({ start: range.start, end: cut.start });
      if (cut.end < range.end) kept.push({ start: cut.end, end: range.end });
      return kept;
    });
  }
  return result;
}

const covers = (ranges: MinuteRange[], start: number, end: number): boolean =>
  ranges.some((r) => r.start <= start && r.end >= end);

export interface SlotInput {
  date: string;
  durationMinutes: number;
  outletPeriods: MinuteRange[];
  staffAvailability: MinuteRange[];
  /** Slots starting before this instant are unavailable (booking lead time). */
  leadCutoff: Date | null;
}

export interface Slot {
  startsAt: string;
  endsAt: string;
  available: boolean;
}

/**
 * Slot grid steps by service duration inside outlet operating periods (matches
 * contract §42 example). A slot is available when the staff availability covers
 * it fully and it starts at or after the lead cutoff.
 */
export function buildSlots(input: SlotInput): Slot[] {
  const { date, durationMinutes, outletPeriods, staffAvailability, leadCutoff } = input;
  const iso = (minutes: number) => `${date}T${toTimeString(minutes)}:00+07:00`;
  const slots: Slot[] = [];
  for (const period of [...outletPeriods].sort((a, b) => a.start - b.start)) {
    for (
      let start = period.start;
      start + durationMinutes <= period.end;
      start += durationMinutes
    ) {
      const end = start + durationMinutes;
      const leadOk = leadCutoff === null || jakartaDateTime(date, start) >= leadCutoff;
      slots.push({
        startsAt: iso(start),
        endsAt: iso(end),
        available: leadOk && covers(staffAvailability, start, end),
      });
    }
  }
  return slots;
}
