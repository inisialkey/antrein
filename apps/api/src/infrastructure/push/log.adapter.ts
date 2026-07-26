import { Logger } from '@nestjs/common';
import { PushNotificationPort, PushSendInput, PushSendResult } from './push-notification.port';

/**
 * Default push adapter (ADR 0044): logs the send and returns a deterministic
 * message id so local/demo runs have a fully observable pipeline without a
 * provider account. OneSignal (ADR 0022) slots in when credentials exist.
 */
export class LogPushAdapter extends PushNotificationPort {
  private readonly logger = new Logger(LogPushAdapter.name);
  private counter = 0;

  send(input: PushSendInput): Promise<PushSendResult> {
    this.counter += 1;
    const providerMessageId = `log-${this.counter}`;
    this.logger.log(
      `push ${providerMessageId} → ${input.pushProvider}:${input.pushToken.slice(0, 8)}… "${input.title}"`,
    );
    return Promise.resolve({ providerMessageId });
  }
}
