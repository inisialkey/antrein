import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { outletNotFound } from '../businesses/business.errors';
import { ACTIVE_QUEUE_STATUSES } from '../bookings/queue/queue-support';
import { jakartaDateString } from '../schedules/slots';
import { DailySummaryQueryDto } from './dto/report.dto';

const idr = (amount: number): { amount: number; currency: string } => ({
  amount,
  currency: 'IDR',
});

/** Read-only daily operational summary (§98). Never mutates transactional state. */
@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async dailySummary(
    businessId: string,
    query: DailySummaryQueryDto,
  ): Promise<Record<string, unknown>> {
    const outlet = await this.prisma.outlet.findFirst({
      where: { id: query.outletId, businessId },
      select: { id: true },
    });
    if (!outlet) throw outletNotFound();

    const dateStr = query.date ?? jakartaDateString(new Date());
    const businessDate = new Date(`${dateStr}T00:00:00Z`);
    const day = { outletId: outlet.id, businessDate };

    const grouped = await this.prisma.booking.groupBy({
      by: ['status'],
      where: day,
      _count: true,
    });
    const byStatus: Record<string, number> = {};
    let total = 0;
    for (const g of grouped) {
      byStatus[g.status] = g._count;
      total += g._count;
    }

    const activeQueue = await this.prisma.queueEntry.count({
      where: { ...day, status: { in: ACTIVE_QUEUE_STATUSES } },
    });
    const [wait] = await this.prisma.$queryRaw<Array<{ avg: number }>>`
      SELECT COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (called_at - checked_in_at)) / 60)), 0)::int AS avg
      FROM queue_entries
      WHERE outlet_id = ${outlet.id} AND business_date = ${dateStr}::date
        AND called_at IS NOT NULL`;

    const bookingDay = { booking: { is: day } };
    const [gross, pending, refunded] = await Promise.all([
      this.prisma.payment.aggregate({
        _sum: { amount: true },
        where: { ...bookingDay, paidAt: { not: null } },
      }),
      this.prisma.payment.aggregate({
        _sum: { amount: true },
        where: { ...bookingDay, status: 'pending' },
      }),
      this.prisma.refund.aggregate({
        _sum: { amount: true },
        where: { ...bookingDay, status: 'refunded' },
      }),
    ]);

    return {
      businessId,
      outletId: outlet.id,
      date: dateStr,
      timezone: 'Asia/Jakarta',
      bookings: {
        total,
        confirmed: byStatus.confirmed ?? 0,
        waiting: byStatus.waiting ?? 0,
        inService: byStatus.in_service ?? 0,
        completed: byStatus.completed ?? 0,
        cancelled: byStatus.cancelled ?? 0,
        noShow: byStatus.no_show ?? 0,
      },
      queue: {
        active: activeQueue,
        averageWaitMinutes: wait.avg,
      },
      payments: {
        grossPaid: idr(gross._sum.amount ?? 0),
        pending: idr(pending._sum.amount ?? 0),
        refunded: idr(refunded._sum.amount ?? 0),
      },
    };
  }
}
