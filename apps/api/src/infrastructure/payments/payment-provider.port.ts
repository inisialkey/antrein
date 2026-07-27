/**
 * Payment provider boundary (booking-payment §69–§72). Adapters map provider
 * statuses to AntreIn payment statuses and never touch bookings, policy or
 * notifications.
 */

export interface ProviderCheckout {
  type: 'redirect_url';
  url: string;
}

export interface CreateProviderPaymentInput {
  /** Local payment id — doubles as the provider merchant reference (§25). */
  paymentId: string;
  amount: number;
  currency: string;
  expiresAt: Date;
}

export interface CreateProviderPaymentResult {
  providerReference: string;
  checkout: ProviderCheckout;
}

export type ProviderPaymentStatusValue = 'pending' | 'paid' | 'failed' | 'expired' | 'cancelled';

export interface ProviderPaymentStatus {
  providerReference: string;
  status: ProviderPaymentStatusValue;
  /** Deterministic id so refresh reuses the webhook dedupe path (ADR 0029). */
  eventId: string;
  amount: number;
  currency: string;
  occurredAt: Date;
}

export interface RequestProviderRefundInput {
  refundId: string;
  providerReference: string;
  amount: number;
  currency: string;
}

export interface RequestProviderRefundResult {
  providerReference: string;
  status: 'refunded' | 'refund_pending';
}

export interface ParsedProviderEvent {
  eventId: string;
  type: string;
  providerReference: string;
  status: ProviderPaymentStatusValue;
  amount: number;
  currency: string;
  occurredAt: Date;
}

/** Thrown by adapters when a provider call fails transiently (§27 temporary). */
export class ProviderUnavailableError extends Error {}

export abstract class PaymentProviderPort {
  abstract readonly provider: string;

  abstract createPayment(input: CreateProviderPaymentInput): Promise<CreateProviderPaymentResult>;

  abstract getPaymentStatus(providerReference: string): Promise<ProviderPaymentStatus>;

  abstract requestRefund(input: RequestProviderRefundInput): Promise<RequestProviderRefundResult>;

  /** Verifies the raw-body signature and parses the event; throws ProviderWebhookError. */
  abstract verifyAndParseWebhook(
    rawBody: Buffer,
    signature: string | undefined,
  ): ParsedProviderEvent;
}
