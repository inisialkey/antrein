import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma } from '../../generated/prisma/client';

/**
 * ADR 0033/0040: every-minute worker that expires overdue pending online
 * payments — payment → expired, pending_payment booking → expired, reservation
 * released. Runs inline (ADR 0035); interval 0 disables the timer so tests
 * drive runOnce() directly.
 */
@Injectable()
export class PaymentExpirationJob implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PaymentExpirationJob.name);
  private timer: NodeJS.Timeout | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit(): void {
    const intervalMs = this.config.get<number>('PAYMENT_EXPIRATION_JOB_INTERVAL_MS') ?? 60_000;
    if (intervalMs <= 0) return;
    this.timer = setInterval(() => {
      this.runOnce().catch((error: Error) =>
        this.logger.error(`Payment expiration sweep failed: ${error.message}`),
      );
    }, intervalMs);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** Expires due payments one by one; returns how many were expired. */
  async runOnce(now = new Date()): Promise<number> {
    const due = await this.prisma.payment.findMany({
      where: {
        status: 'pending',
        provider: { not: 'pay_at_location' },
        expiresAt: { lte: now },
      },
      select: { id: true },
      take: 100,
    });
    let expired = 0;
    for (const { id } of due) {
      try {
        if (await this.expireOne(id, now)) expired += 1;
      } catch (error) {
        this.logger.error(`Failed to expire payment ${id}: ${(error as Error).message}`);
      }
    }
    return expired;
  }

  private async expireOne(paymentId: string, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM payments WHERE id = ${paymentId} FOR UPDATE`;
      const payment = await tx.payment.findUnique({ where: { id: paymentId } });
      // Recheck under lock — a webhook may have settled it meanwhile (§29).
      if (
        !payment ||
        payment.status !== 'pending' ||
        !payment.expiresAt ||
        payment.expiresAt > now
      ) {
        return false;
      }
      await tx.payment.update({
        where: { id: paymentId },
        data: { status: 'expired', version: { increment: 1 } },
      });
      const booking = await tx.booking.findUnique({ where: { id: payment.bookingId } });
      if (booking && booking.status === 'pending_payment') {
        await tx.booking.update({
          where: { id: booking.id },
          data: { status: 'expired', version: { increment: 1 } },
        });
        await tx.bookingReservation.deleteMany({ where: { bookingId: booking.id } });
        await tx.bookingStatusHistory.create({
          data: {
            id: newId('bsh'),
            bookingId: booking.id,
            fromStatus: 'pending_payment',
            toStatus: 'expired',
            actorType: 'system',
            reasonCode: 'payment_expired',
            metadata: { paymentId } as Prisma.InputJsonValue,
          },
        });
      }
      return true;
    });
  }
}
