import { createHmac, timingSafeEqual } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import {
  CreateProviderPaymentInput,
  CreateProviderPaymentResult,
  ParsedProviderEvent,
  PaymentProviderPort,
  ProviderPaymentStatus,
  ProviderPaymentStatusValue,
  ProviderUnavailableError,
  RequestProviderRefundInput,
  RequestProviderRefundResult,
} from './payment-provider.port';

export class ProviderWebhookError extends Error {
  constructor(
    readonly code: 'SIGNATURE_INVALID' | 'PAYLOAD_INVALID',
    message: string,
  ) {
    super(message);
  }
}

/** HMAC-SHA256 hex over the raw body — also used by tests to fabricate webhooks. */
export function signSandboxWebhook(rawBody: Buffer, secret: string): string {
  return createHmac('sha256', secret).update(rawBody).digest('hex');
}

const PROVIDER_STATUSES: ProviderPaymentStatusValue[] = [
  'pending',
  'paid',
  'failed',
  'expired',
  'cancelled',
];

/**
 * Deterministic in-process provider (booking-payment §96): enables the full
 * online-payment flow locally and in CI before a real gateway lands. Webhooks
 * are simulated by POSTing signed payloads to the webhook endpoint; status is
 * simulated via simulateStatus().
 */
@Injectable()
export class SandboxPaymentAdapter extends PaymentProviderPort {
  readonly provider = 'sandbox';

  private readonly sessions = new Map<
    string,
    { paymentId: string; amount: number; currency: string; status: ProviderPaymentStatusValue }
  >();
  private failCreates = 0;
  private failRefunds = 0;

  constructor(private readonly webhookSecret: string) {
    super();
  }

  /** Test/dev hook: the next createPayment call fails like a provider outage. */
  failNextCreate(times = 1): void {
    this.failCreates = times;
  }

  /** Test/dev hook: the next requestRefund call fails like a provider outage. */
  failNextRefund(times = 1): void {
    this.failRefunds = times;
  }

  /** Test/dev hook: set the provider-side status returned by getPaymentStatus. */
  simulateStatus(providerReference: string, status: ProviderPaymentStatusValue): void {
    const session = this.sessions.get(providerReference);
    if (session) session.status = status;
    else {
      this.sessions.set(providerReference, {
        paymentId: providerReference.replace(/^sbx_/, ''),
        amount: 0,
        currency: 'IDR',
        status,
      });
    }
  }

  async createPayment(input: CreateProviderPaymentInput): Promise<CreateProviderPaymentResult> {
    if (this.failCreates > 0) {
      this.failCreates -= 1;
      throw new ProviderUnavailableError('Sandbox provider is unavailable (simulated).');
    }
    if (input.currency !== 'IDR') {
      throw new Error(`Unsupported currency: ${input.currency}`);
    }
    const providerReference = `sbx_${input.paymentId}`;
    this.sessions.set(providerReference, {
      paymentId: input.paymentId,
      amount: input.amount,
      currency: input.currency,
      status: 'pending',
    });
    return {
      providerReference,
      checkout: {
        type: 'redirect_url',
        url: `https://sandbox.payments.antrein.local/checkout/${providerReference}`,
      },
    };
  }

  async getPaymentStatus(providerReference: string): Promise<ProviderPaymentStatus> {
    const session = this.sessions.get(providerReference);
    if (!session) {
      throw new ProviderUnavailableError(`Unknown sandbox reference: ${providerReference}`);
    }
    return {
      providerReference,
      status: session.status,
      // Deterministic per (reference, status): repeated refreshes dedupe as one event.
      eventId: `sbx_evt_${providerReference}_${session.status}`,
      amount: session.amount,
      currency: session.currency,
      occurredAt: new Date(),
    };
  }

  async requestRefund(input: RequestProviderRefundInput): Promise<RequestProviderRefundResult> {
    if (this.failRefunds > 0) {
      this.failRefunds -= 1;
      throw new ProviderUnavailableError('Sandbox refund is unavailable (simulated).');
    }
    // Sandbox refunds settle instantly; async provider refunds arrive with a
    // real gateway adapter. Idempotent by refundId — reconciliation re-requests.
    return { providerReference: `sbx_rf_${input.refundId}`, status: 'refunded' };
  }

  verifyAndParseWebhook(rawBody: Buffer, signature: string | undefined): ParsedProviderEvent {
    const expected = Buffer.from(signSandboxWebhook(rawBody, this.webhookSecret));
    const received = Buffer.from(signature ?? '');
    if (received.length !== expected.length || !timingSafeEqual(received, expected)) {
      throw new ProviderWebhookError('SIGNATURE_INVALID', 'Webhook signature is invalid.');
    }

    let payload: Record<string, unknown>;
    try {
      payload = JSON.parse(rawBody.toString('utf8')) as Record<string, unknown>;
    } catch {
      throw new ProviderWebhookError('PAYLOAD_INVALID', 'Webhook payload is not valid JSON.');
    }
    const status = payload.status as ProviderPaymentStatusValue;
    if (
      typeof payload.eventId !== 'string' ||
      typeof payload.providerReference !== 'string' ||
      !PROVIDER_STATUSES.includes(status) ||
      typeof payload.amount !== 'number' ||
      typeof payload.currency !== 'string'
    ) {
      throw new ProviderWebhookError('PAYLOAD_INVALID', 'Webhook payload is missing fields.');
    }
    return {
      eventId: payload.eventId,
      type: typeof payload.type === 'string' ? payload.type : `payment.${status}`,
      providerReference: payload.providerReference,
      status,
      amount: payload.amount,
      currency: payload.currency,
      occurredAt:
        typeof payload.occurredAt === 'string' && !Number.isNaN(Date.parse(payload.occurredAt))
          ? new Date(payload.occurredAt)
          : new Date(),
    };
  }
}
