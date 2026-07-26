export interface PushSendInput {
  pushProvider: string;
  pushToken: string;
  title: string;
  body: string;
  /** Flat string map — ends up as the platform notification data payload. */
  data: Record<string, string>;
}

export interface PushSendResult {
  providerMessageId: string | null;
}

/**
 * Outbound push provider boundary (ADR 0044). A thrown error means the send
 * failed; callers record it on the notification_deliveries row and never fail
 * the queue mutation or outbox dispatch (backend-brief §110).
 */
export abstract class PushNotificationPort {
  abstract send(input: PushSendInput): Promise<PushSendResult>;
}
