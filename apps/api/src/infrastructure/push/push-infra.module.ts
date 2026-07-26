import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LogPushAdapter } from './log.adapter';
import { PushNotificationPort } from './push-notification.port';

/**
 * Provides PushNotificationPort per PUSH_PROVIDER env (ADR 0044): 'log'
 * (default) or 'none' (port resolves to null → deliveries recorded as failed
 * with PUSH_PROVIDER_UNAVAILABLE). A real 'onesignal' adapter slots in here.
 */
@Global()
@Module({
  providers: [
    {
      provide: PushNotificationPort,
      useFactory: (config: ConfigService): PushNotificationPort | null => {
        const provider = config.get<string>('PUSH_PROVIDER') ?? 'log';
        if (provider === 'none') return null;
        return new LogPushAdapter();
      },
      inject: [ConfigService],
    },
  ],
  exports: [PushNotificationPort],
})
export class PushInfraModule {}
