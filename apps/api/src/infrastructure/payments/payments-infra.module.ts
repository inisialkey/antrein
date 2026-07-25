import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProviderPort } from './payment-provider.port';
import { SandboxPaymentAdapter } from './sandbox.adapter';

/**
 * Provides PaymentProviderPort per PAYMENT_PROVIDER env: 'sandbox' (default)
 * or 'none' (port resolves to null → online options answer
 * PAYMENT_PROVIDER_UNAVAILABLE). Real gateway adapters slot in here.
 */
@Global()
@Module({
  providers: [
    {
      provide: PaymentProviderPort,
      useFactory: (config: ConfigService): PaymentProviderPort | null => {
        const provider = config.get<string>('PAYMENT_PROVIDER') ?? 'sandbox';
        if (provider === 'none') return null;
        return new SandboxPaymentAdapter(
          config.get<string>('PAYMENT_WEBHOOK_SECRET') ?? 'sandbox-webhook-secret',
        );
      },
      inject: [ConfigService],
    },
  ],
  exports: [PaymentProviderPort],
})
export class PaymentsInfraModule {}
