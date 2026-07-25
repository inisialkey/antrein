import { Injectable } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import {
  Outlet,
  OutletOperatingHour,
  Prisma,
  StaffSchedule,
  StaffScheduleBreak,
} from '../../generated/prisma/client';
import { validationFailed } from '../auth/auth.errors';
import { businessNotActive, outletNotFound } from '../businesses/business.errors';
import { IdempotencyService } from '../idempotency/idempotency.service';
import { businessNotFound } from '../memberships/membership.errors';
import { serviceNotFound } from '../services/service.errors';
import { staffNotFound } from '../staff/staff.errors';
import {
  AvailabilityQueryDto,
  CreateClosedDateDto,
  DAY_NAMES,
  DayName,
  ListClosedDatesQueryDto,
  OperatingDayDto,
  ReplaceOperatingHoursDto,
  ReplaceStaffScheduleDto,
  StaffDayDto,
} from './dto/schedule.dto';
import {
  scheduleClosedDateAlreadyExists,
  scheduleDateInPast,
  scheduleDateOutOfRange,
  scheduleInvalidPeriod,
  scheduleInvalidTimezone,
  staffNotEligibleForService,
} from './schedule.errors';
import {
  MinuteRange,
  addDays,
  buildSlots,
  dbTimeToString,
  jakartaDateString,
  jakartaDayOfWeek,
  subtractRanges,
  timeToDb,
  toMinutes,
  toTimeString,
  validatePeriods,
} from './slots';

/** Response order: monday first, sunday last (contract §54 example). */
const DAY_ORDER: number[] = [1, 2, 3, 4, 5, 6, 0];

const dayNumberOf = (name: DayName): number => DAY_NAMES.indexOf(name);

const uniqueDays = (days: Array<{ dayOfWeek: DayName }>): void => {
  if (new Set(days.map((d) => d.dayOfWeek)).size !== days.length) {
    throw validationFailed('Each dayOfWeek may appear at most once.');
  }
};

const dateToDb = (date: string): Date => new Date(`${date}T00:00:00Z`);

export function operatingDaysOf(rows: OutletOperatingHour[]): Record<string, unknown>[] {
  return DAY_ORDER.map((day) => {
    const periods = rows
      .filter((r) => r.dayOfWeek === day && !r.isClosed && r.opensAt && r.closesAt)
      .sort((a, b) => a.periodOrder - b.periodOrder)
      .map((r) => ({
        opensAt: dbTimeToString(r.opensAt as Date),
        closesAt: dbTimeToString(r.closesAt as Date),
      }));
    return { dayOfWeek: DAY_NAMES[day], isClosed: periods.length === 0, periods };
  });
}

export function staffDaysOf(
  rows: Array<StaffSchedule & { breaks: StaffScheduleBreak[] }>,
): Record<string, unknown>[] {
  return DAY_ORDER.map((day) => {
    const dayRows = rows
      .filter((r) => r.dayOfWeek === day && r.isAvailable && r.startsAt && r.endsAt)
      .sort((a, b) => a.periodOrder - b.periodOrder);
    return {
      dayOfWeek: DAY_NAMES[day],
      isAvailable: dayRows.length > 0,
      periods: dayRows.map((r) => ({
        startsAt: dbTimeToString(r.startsAt as Date),
        endsAt: dbTimeToString(r.endsAt as Date),
      })),
      breaks: dayRows
        .flatMap((r) => r.breaks)
        .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime())
        .map((b) => ({ startsAt: dbTimeToString(b.startsAt), endsAt: dbTimeToString(b.endsAt) })),
    };
  });
}

@Injectable()
export class SchedulesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async getOperatingHours(businessId: string, outletId: string): Promise<Record<string, unknown>> {
    const outlet = await this.outletOf(businessId, outletId);
    const rows = await this.prisma.outletOperatingHour.findMany({ where: { outletId } });
    return { timezone: outlet.timezone, days: operatingDaysOf(rows) };
  }

  async replaceOperatingHours(
    businessId: string,
    outletId: string,
    dto: ReplaceOperatingHoursDto,
  ): Promise<Record<string, unknown>> {
    const outlet = await this.outletOf(businessId, outletId);
    if (dto.timezone !== outlet.timezone) throw scheduleInvalidTimezone();
    uniqueDays(dto.days);

    const rows = dto.days.flatMap((day) => this.operatingRowsOf(outletId, day));
    await this.prisma.$transaction([
      this.prisma.outletOperatingHour.deleteMany({ where: { outletId } }),
      this.prisma.outletOperatingHour.createMany({ data: rows }),
    ]);
    return this.getOperatingHours(businessId, outletId);
  }

  async listClosedDates(
    businessId: string,
    outletId: string,
    query: ListClosedDatesQueryDto,
  ): Promise<{ items: unknown[] }> {
    await this.outletOf(businessId, outletId);
    const closedDate: Prisma.DateTimeFilter = {};
    if (query.dateFrom) closedDate.gte = dateToDb(query.dateFrom);
    if (query.dateTo) closedDate.lte = dateToDb(query.dateTo);
    const rows = await this.prisma.closedDate.findMany({
      where: { outletId, ...(query.dateFrom || query.dateTo ? { closedDate } : {}) },
      orderBy: { closedDate: 'asc' },
    });
    return {
      items: rows.map((r) => ({
        id: r.id,
        date: r.closedDate.toISOString().slice(0, 10),
        reason: r.reason,
      })),
    };
  }

  async createClosedDate(
    userId: string,
    businessId: string,
    outletId: string,
    dto: CreateClosedDateDto,
    idempotencyKey: string | undefined,
  ): Promise<Record<string, unknown>> {
    return this.idempotency.execute({
      scopeType: 'user',
      scopeId: userId,
      action: `closed_date.create:${outletId}`,
      key: idempotencyKey,
      payload: dto,
      resourceOf: (result) => ({ type: 'closed_date', id: result.id as string }),
      run: async () => {
        await this.outletOf(businessId, outletId);
        if (dto.date < jakartaDateString(new Date())) throw scheduleDateInPast();
        // ponytail: SCHEDULE_AFFECTS_EXISTING_BOOKINGS lands with the bookings
        // module (M6) — there is no bookings table to consult yet.
        try {
          const row = await this.prisma.closedDate.create({
            data: {
              id: newId('cld'),
              outletId,
              closedDate: dateToDb(dto.date),
              reason: dto.reason ?? null,
              createdByUserId: userId,
            },
          });
          return {
            id: row.id,
            date: dto.date,
            reason: row.reason,
            createdAt: row.createdAt.toISOString(),
          };
        } catch (error) {
          if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
            throw scheduleClosedDateAlreadyExists();
          }
          throw error;
        }
      },
    });
  }

  async replaceStaffSchedule(
    businessId: string,
    staffId: string,
    dto: ReplaceStaffScheduleDto,
  ): Promise<Record<string, unknown>> {
    const staff = await this.prisma.staffProfile.findUnique({
      where: { id: staffId },
      include: { business: { select: { timezone: true } } },
    });
    if (!staff || staff.businessId !== businessId) throw staffNotFound();
    if (dto.timezone !== staff.business.timezone) throw scheduleInvalidTimezone();
    uniqueDays(dto.days);

    const schedules: Prisma.StaffScheduleCreateManyInput[] = [];
    const breaks: Prisma.StaffScheduleBreakCreateManyInput[] = [];
    const listedDays = new Set<number>();
    for (const day of dto.days) {
      listedDays.add(dayNumberOf(day.dayOfWeek));
      this.staffRowsOf(staffId, day, schedules, breaks);
    }
    // Full replace: unlisted days become explicit unavailable rows so a configured
    // staff schedule is distinguishable from a never-configured one.
    for (const day of DAY_ORDER.filter((d) => !listedDays.has(d))) {
      schedules.push(this.unavailableRow(staffId, day));
    }

    await this.prisma.$transaction([
      this.prisma.staffSchedule.deleteMany({ where: { staffId } }),
      this.prisma.staffSchedule.createMany({ data: schedules }),
      this.prisma.staffScheduleBreak.createMany({ data: breaks }),
    ]);

    const rows = await this.prisma.staffSchedule.findMany({
      where: { staffId },
      include: { breaks: true },
    });
    return { staffId, timezone: staff.business.timezone, days: staffDaysOf(rows) };
  }

  async getAvailability(
    businessId: string,
    query: AvailabilityQueryDto,
    now = new Date(),
  ): Promise<Record<string, unknown>> {
    const business = await this.prisma.business.findUnique({
      where: { id: businessId },
      include: { policy: true },
    });
    if (!business) throw businessNotFound();
    if (business.status !== 'active') throw businessNotActive();

    const outlet = await this.outletOf(businessId, query.outletId);

    const service = await this.prisma.service.findUnique({
      where: { id: query.serviceId },
      include: { staffLinks: { select: { staffId: true } } },
    });
    if (!service || service.businessId !== businessId || service.status !== 'active') {
      throw serviceNotFound();
    }

    // ADR 0019: any_available staff selection is out of MVP scope.
    if (!query.staffId) {
      throw validationFailed('staffId is required; any_available selection is not supported yet.');
    }
    const staff = await this.prisma.staffProfile.findUnique({
      where: { id: query.staffId },
      include: {
        outletAssignments: { select: { outletId: true } },
        schedules: { include: { breaks: true } },
      },
    });
    if (!staff || staff.businessId !== businessId || staff.status !== 'active') {
      throw staffNotFound();
    }
    // ponytail: a service with zero staff_services rows means every staff member
    // is eligible (mirrors M4 service creation allowing an empty staff list).
    if (
      service.staffLinks.length > 0 &&
      !service.staffLinks.some((l) => l.staffId === query.staffId)
    ) {
      throw staffNotEligibleForService();
    }

    const policy = business.policy;
    const today = jakartaDateString(now);
    const maxAdvanceDays = policy?.maximumAdvanceDays ?? 30;
    if (query.date < today || query.date > addDays(today, maxAdvanceDays)) {
      throw scheduleDateOutOfRange(maxAdvanceDays);
    }

    const day = jakartaDayOfWeek(query.date);
    const closed = await this.prisma.closedDate.findUnique({
      where: {
        outletId_closedDate: { outletId: outlet.id, closedDate: dateToDb(query.date) },
      },
    });

    let slots: ReturnType<typeof buildSlots> = [];
    if (!closed) {
      const hourRows = await this.prisma.outletOperatingHour.findMany({
        where: { outletId: outlet.id, dayOfWeek: day },
      });
      const outletPeriods: MinuteRange[] = hourRows
        .filter((r) => !r.isClosed && r.opensAt && r.closesAt)
        .map((r) => ({
          start: toMinutes(dbTimeToString(r.opensAt as Date)),
          end: toMinutes(dbTimeToString(r.closesAt as Date)),
        }));
      slots = buildSlots({
        date: query.date,
        durationMinutes: service.durationMinutes,
        outletPeriods,
        staffAvailability: this.staffAvailabilityOf(staff, outlet.id, day, outletPeriods),
        leadCutoff:
          query.date === today
            ? new Date(now.getTime() + (policy?.minimumLeadMinutes ?? 60) * 60_000)
            : null,
      });
    }

    return {
      businessId,
      outletId: outlet.id,
      service: { id: service.id, name: service.name, durationMinutes: service.durationMinutes },
      staffSelection: { mode: 'specific_staff', staffId: staff.id },
      date: query.date,
      timezone: outlet.timezone,
      slots,
      generatedAt: now.toISOString(),
    };
  }

  private staffAvailabilityOf(
    staff: {
      outletAssignments: Array<{ outletId: string }>;
      schedules: Array<StaffSchedule & { breaks: StaffScheduleBreak[] }>;
    },
    outletId: string,
    day: number,
    outletPeriods: MinuteRange[],
  ): MinuteRange[] {
    // Staff restricted to other outlets never covers slots here (informational —
    // the booking transaction re-enforces this in M6).
    const assignments = staff.outletAssignments.map((a) => a.outletId);
    if (assignments.length > 0 && !assignments.includes(outletId)) return [];
    // ponytail: staff with no schedule rows at all follows outlet hours, so
    // availability works right after staff onboarding; configured schedules are strict.
    if (staff.schedules.length === 0) return outletPeriods;
    const dayRows = staff.schedules.filter((r) => r.dayOfWeek === day && r.isAvailable);
    const periods = dayRows
      .filter((r) => r.startsAt && r.endsAt)
      .map((r) => ({
        start: toMinutes(dbTimeToString(r.startsAt as Date)),
        end: toMinutes(dbTimeToString(r.endsAt as Date)),
      }));
    const cuts = dayRows
      .flatMap((r) => r.breaks)
      .map((b) => ({
        start: toMinutes(dbTimeToString(b.startsAt)),
        end: toMinutes(dbTimeToString(b.endsAt)),
      }));
    return subtractRanges(periods, cuts);
  }

  private operatingRowsOf(
    outletId: string,
    day: OperatingDayDto,
  ): Prisma.OutletOperatingHourCreateManyInput[] {
    if (day.isClosed || day.periods.length === 0) {
      if (day.periods.length > 0) throw scheduleInvalidPeriod();
      return [];
    }
    const ranges = validatePeriods(day.periods.map((p) => ({ start: p.opensAt, end: p.closesAt })));
    return ranges.map((range, index) => ({
      id: newId('sch'),
      outletId,
      dayOfWeek: dayNumberOf(day.dayOfWeek),
      periodOrder: index,
      opensAt: timeToDb(toTimeString(range.start)),
      closesAt: timeToDb(toTimeString(range.end)),
      isClosed: false,
    }));
  }

  private staffRowsOf(
    staffId: string,
    day: StaffDayDto,
    schedules: Prisma.StaffScheduleCreateManyInput[],
    breaks: Prisma.StaffScheduleBreakCreateManyInput[],
  ): void {
    const dayNumber = dayNumberOf(day.dayOfWeek);
    if (!day.isAvailable || day.periods.length === 0) {
      if (day.periods.length > 0 || (day.breaks ?? []).length > 0) throw scheduleInvalidPeriod();
      schedules.push(this.unavailableRow(staffId, dayNumber));
      return;
    }
    const ranges = validatePeriods(day.periods.map((p) => ({ start: p.startsAt, end: p.endsAt })));
    const breakRanges = validatePeriods(
      (day.breaks ?? []).map((b) => ({ start: b.startsAt, end: b.endsAt })),
    );
    const rows = ranges.map((range, index) => ({
      id: newId('sch'),
      staffId,
      dayOfWeek: dayNumber,
      periodOrder: index,
      startsAt: timeToDb(toTimeString(range.start)),
      endsAt: timeToDb(toTimeString(range.end)),
      isAvailable: true,
    }));
    schedules.push(...rows);
    for (const breakRange of breakRanges) {
      const parentIndex = ranges.findIndex(
        (r) => r.start <= breakRange.start && r.end >= breakRange.end,
      );
      // database-design §24: breaks must remain inside their parent period.
      if (parentIndex === -1) throw scheduleInvalidPeriod();
      breaks.push({
        id: newId('sch'),
        staffScheduleId: rows[parentIndex].id,
        startsAt: timeToDb(toTimeString(breakRange.start)),
        endsAt: timeToDb(toTimeString(breakRange.end)),
      });
    }
  }

  private unavailableRow(staffId: string, dayOfWeek: number): Prisma.StaffScheduleCreateManyInput {
    return {
      id: newId('sch'),
      staffId,
      dayOfWeek,
      periodOrder: 0,
      startsAt: null,
      endsAt: null,
      isAvailable: false,
    };
  }

  private async outletOf(businessId: string, outletId: string): Promise<Outlet> {
    const outlet = await this.prisma.outlet.findUnique({ where: { id: outletId } });
    if (!outlet || outlet.businessId !== businessId || outlet.status !== 'active') {
      throw outletNotFound();
    }
    return outlet;
  }
}
