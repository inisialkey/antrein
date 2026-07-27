import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LogPushAdapter } from './log.adapter';
import { OneSignalPushAdapter } from './onesignal.adapter';
import { PushNotificationPort } from './push-notification.port';

/**
 * Provides PushNotificationPort per PUSH_PROVIDER env (ADR 0044): 'log'
 * (default), 'onesignal' (real provider, needs credentials) or 'none' (port
 * resolves to null → deliveries recorded as failed PUSH_PROVIDER_UNAVAILABLE).
 */
@Global()
@Module({
  providers: [
    {
      provide: PushNotificationPort,
      useFactory: (config: ConfigService): PushNotificationPort | null => {
        const provider = config.get<string>('PUSH_PROVIDER') ?? 'log';
        if (provider === 'none') return null;
        if (provider === 'onesignal') {
          const appId = config.get<string>('ONESIGNAL_APP_ID');
          const apiKey = config.get<string>('ONESIGNAL_API_KEY');
          if (!appId || !apiKey) {
            // Fail boot loudly — a half-configured real provider silently
            // dropping pushes is worse than a crash.
            throw new Error(
              'PUSH_PROVIDER=onesignal requires ONESIGNAL_APP_ID and ONESIGNAL_API_KEY.',
            );
          }
          return new OneSignalPushAdapter(appId, apiKey);
        }
        return new LogPushAdapter();
      },
      inject: [ConfigService],
    },
  ],
  exports: [PushNotificationPort],
})
export class PushInfraModule {}
