import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { clampLimit, decodeCursor, pageOf } from '../../common/pagination/cursor';
import { Notification, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { PushNotificationPort } from '../../infrastructure/push/push-notification.port';
import { validationFailed } from '../auth/auth.errors';
import { ListNotificationsQueryDto, RegisterDeviceDto } from './dto/notifications.dto';
import { deviceNotFound, notificationNotFound } from './notifications.errors';
import { QueuePushKind, queuePushCopy } from './push-copy';

export interface QueuePushInput {
  userId: string;
  kind: QueuePushKind;
  bookingId: string;
  displayNumber: string;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    // Union types erase DI metadata — the explicit token is required here.
    @Optional() @Inject(PushNotificationPort) private readonly push: PushNotificationPort | null,
  ) {}

  // ---------------------------------------------------------------------------
  // Devices (api-contract §34/§35)
  // ---------------------------------------------------------------------------

  async registerDevice(
    userId: string,
    deviceId: string,
    dto: RegisterDeviceDto,
  ): Promise<Record<string, unknown>> {
    if (deviceId.length > 100) throw validationFailed('deviceId is too long.');
    const data = {
      userId,
      platform: dto.platform,
      appVersion: dto.appVersion ?? null,
      deviceName: dto.deviceName ?? null,
      pushProvider: dto.pushProvider ?? null,
      pushToken: dto.pushToken ?? null,
      locale: dto.locale ?? null,
      timezone: dto.timezone ?? null,
      status: 'active',
      lastSeenAt: new Date(),
    };
    const device = await this.prisma.$transaction(async (tx) => {
      // A reinstall gets a new deviceId but keeps the physical push token —
      // free the token from any other row first (devices_provider_token_uq).
      if (dto.pushToken && dto.pushProvider) {
        await tx.device.updateMany({
          where: {
            pushProvider: dto.pushProvider,
            pushToken: dto.pushToken,
            NOT: { id: deviceId },
          },
          data: { pushToken: null, status: 'inactive' },
        });
      }
      // Same physical device logging into another account moves the row.
      return tx.device.upsert({
        where: { id: deviceId },
        create: { id: deviceId, ...data },
        update: data,
      });
    });
    return {
      deviceId: device.id,
      registered: true,
      updatedAt: device.updatedAt.toISOString(),
    };
  }

  async removeDevice(userId: string, deviceId: string): Promise<Record<string, unknown>> {
    const removed = await this.prisma.device.deleteMany({ where: { id: deviceId, userId } });
    if (removed.count === 0) throw deviceNotFound();
    return { removed: true };
  }

  // ---------------------------------------------------------------------------
  // In-app notification reads (api-contract §92–§95)
  // ---------------------------------------------------------------------------

  async list(userId: string, query: ListNotificationsQueryDto): Promise<Record<string, unknown>> {
    const limit = clampLimit(query.limit);
    const where: Prisma.NotificationWhereInput = { userId };
    if (query.isRead !== undefined) where.isRead = query.isRead === 'true';
    if (query.type) where.notificationType = query.type;
    if (query.cursor) {
      const c = decodeCursor(query.cursor);
      const createdAt = new Date(c.createdAt ?? '');
      if (Number.isNaN(createdAt.getTime())) throw validationFailed('Cursor is invalid.');
      where.OR = [{ createdAt: { lt: createdAt } }, { createdAt, id: { lt: c.id ?? '' } }];
    }
    const rows = await this.prisma.notification.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const page = pageOf(rows, limit, (row) => ({
      createdAt: row.createdAt.toISOString(),
      id: row.id,
    }));
    return { items: page.items.map(toNotificationResource), pagination: page.pagination };
  }

  async get(userId: string, notificationId: string): Promise<Record<string, unknown>> {
    const row = await this.prisma.notification.findUnique({ where: { id: notificationId } });
    if (!row || row.userId !== userId) throw notificationNotFound();
    return toNotificationResource(row);
  }

  async markRead(userId: string, notificationId: string): Promise<Record<string, unknown>> {
    const row = await this.prisma.notification.findUnique({ where: { id: notificationId } });
    if (!row || row.userId !== userId) throw notificationNotFound();
    if (row.isRead) {
      return { id: row.id, isRead: true, readAt: row.readAt?.toISOString() ?? null };
    }
    const readAt = new Date();
    await this.prisma.notification.update({
      where: { id: row.id },
      data: { isRead: true, readAt },
    });
    return { id: row.id, isRead: true, readAt: readAt.toISOString() };
  }

  async markAllRead(userId: string): Promise<Record<string, unknown>> {
    const updated = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
    return { updatedCount: updated.count };
  }

  // ---------------------------------------------------------------------------
  // Queue push pipeline (realtime-queue §52–§54, ADR 0044)
  // ---------------------------------------------------------------------------

  /**
   * Create the in-app notification + one delivery per pushable device, called
   * from the outbox dispatcher. Wholly best-effort — it NEVER throws, so the
   * outbox row is never retried for a push failure and can't duplicate the
   * notification (push must not fail the dispatch, backend-brief §110).
   *
   * ponytail: a DB failure here loses the in-app row for good (history is not
   * source of truth, database-design §42). If that ever matters, dedupe on a
   * stored outbox event id instead of swallowing.
   */
  async notifyQueuePush(input: QueuePushInput): Promise<void> {
    try {
      await this.createNotificationWithDeliveries(input);
    } catch (error) {
      this.logger.warn(
        `notifyQueuePush failed user=${input.userId} booking=${input.bookingId}: ${(error as Error).message}`,
      );
    }
  }

  private async createNotificationWithDeliveries(input: QueuePushInput): Promise<void> {
    const copy = queuePushCopy(input.kind, input.displayNumber);
    const notification = await this.prisma.notification.create({
      data: {
        id: newId('ntf'),
        userId: input.userId,
        notificationType: copy.notificationType,
        title: copy.title,
        body: copy.body,
        resourceType: 'booking',
        resourceId: input.bookingId,
      },
    });

    // Preference gate (ADR 0044): in-app history stays, deliveries are skipped.
    const pref = await this.prisma.userNotificationPreference.findUnique({
      where: { userId: input.userId },
    });
    if (pref && !pref.queueUpdates) return;

    const devices = await this.prisma.device.findMany({
      where: { userId: input.userId, status: 'active', pushToken: { not: null } },
    });
    for (const device of devices) {
      const base = {
        id: newId('ntd'),
        notificationId: notification.id,
        deviceId: device.id,
        provider: device.pushProvider ?? 'unknown',
      };
      if (!this.push) {
        await this.prisma.notificationDelivery.create({
          data: {
            ...base,
            status: 'failed',
            attemptCount: 0,
            lastErrorCode: 'PUSH_PROVIDER_UNAVAILABLE',
            failedAt: new Date(),
          },
        });
        continue;
      }
      try {
        const result = await this.push.send({
          pushProvider: device.pushProvider ?? 'unknown',
          pushToken: device.pushToken as string,
          title: copy.title,
          body: copy.body,
          data: {
            notificationId: notification.id,
            type: copy.notificationType,
            bookingId: input.bookingId,
          },
        });
        await this.prisma.notificationDelivery.create({
          data: {
            ...base,
            status: 'sent',
            attemptCount: 1,
            providerMessageId: result.providerMessageId,
            sentAt: new Date(),
          },
        });
      } catch (error) {
        this.logger.warn(`push send failed device=${device.id}: ${(error as Error).message}`);
        await this.prisma.notificationDelivery.create({
          data: {
            ...base,
            status: 'failed',
            attemptCount: 1,
            lastErrorCode: 'PUSH_SEND_FAILED',
            failedAt: new Date(),
          },
        });
      }
    }
  }
}

function toNotificationResource(row: Notification): Record<string, unknown> {
  return {
    id: row.id,
    type: row.notificationType,
    title: row.title,
    body: row.body,
    resource:
      row.resourceType && row.resourceId ? { type: row.resourceType, id: row.resourceId } : null,
    isRead: row.isRead,
    createdAt: row.createdAt.toISOString(),
    readAt: row.readAt?.toISOString() ?? null,
  };
}
