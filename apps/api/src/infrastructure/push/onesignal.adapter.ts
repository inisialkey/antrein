import { PushNotificationPort, PushSendInput, PushSendResult } from './push-notification.port';

const ONESIGNAL_API_URL = 'https://api.onesignal.com/notifications';

/**
 * Real OneSignal adapter (ADR 0022/0044): REST v2 send keyed by the device's
 * push subscription id — which is exactly what mobile registers as the device
 * pushToken. A thrown error lands on the notification_deliveries row upstream;
 * it never fails the queue mutation or the outbox dispatch.
 */
export class OneSignalPushAdapter extends PushNotificationPort {
  constructor(
    private readonly appId: string,
    private readonly apiKey: string,
  ) {
    super();
  }

  async send(input: PushSendInput): Promise<PushSendResult> {
    const response = await fetch(ONESIGNAL_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Key ${this.apiKey}`,
      },
      body: JSON.stringify({
        app_id: this.appId,
        include_subscription_ids: [input.pushToken],
        // Copy is already Bahasa (push-copy.ts); `en` is OneSignal's default-language bucket.
        headings: { en: input.title },
        contents: { en: input.body },
        data: input.data,
      }),
      signal: AbortSignal.timeout(10_000),
    });

    const body = (await response.json().catch(() => ({}))) as {
      id?: string;
      errors?: unknown[];
    };
    if (!response.ok || (body.errors?.length ?? 0) > 0) {
      throw new Error(
        `OneSignal send failed (${response.status}): ${JSON.stringify(body.errors ?? body)}`,
      );
    }
    // An empty id means OneSignal accepted the call but reached no device.
    return { providerMessageId: body.id ? body.id : null };
  }
}
