import { QueueEntry } from '../../../generated/prisma/client';

const iso = (d: Date | null): string | null => d?.toISOString() ?? null;
const dateOnly = (d: Date): string => d.toISOString().slice(0, 10);

export interface CustomerQueueView {
  peopleAhead: number;
  currentServingNumber: string | null;
  estimatedWaitMinutes: number;
}

/** Customer queue resource (api-contract §80). No other customer is exposed. */
export function toCustomerQueueResource(
  entry: QueueEntry,
  view: CustomerQueueView,
): Record<string, unknown> {
  return {
    id: entry.id,
    bookingId: entry.bookingId,
    businessId: entry.businessId,
    outletId: entry.outletId,
    businessDate: dateOnly(entry.businessDate),
    queueNumber: entry.queueNumber,
    displayNumber: entry.displayNumber,
    status: entry.status,
    peopleAhead: view.peopleAhead,
    currentServingNumber: view.currentServingNumber,
    estimatedWaitMinutes: view.estimatedWaitMinutes,
    calledAt: iso(entry.calledAt),
    serviceStartedAt: iso(entry.serviceStartedAt),
    completedAt: iso(entry.completedAt),
    version: entry.version,
    updatedAt: iso(entry.updatedAt),
  };
}

/** Check-in response queue block (api-contract §64). */
export function toCheckInQueueBlock(
  entry: QueueEntry,
  view: CustomerQueueView,
): Record<string, unknown> {
  return {
    id: entry.id,
    queueNumber: entry.queueNumber,
    displayNumber: entry.displayNumber,
    status: entry.status,
    peopleAhead: view.peopleAhead,
    currentServingNumber: view.currentServingNumber,
    estimatedWaitMinutes: view.estimatedWaitMinutes,
    businessDate: dateOnly(entry.businessDate),
  };
}
