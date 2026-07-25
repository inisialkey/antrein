import {
  Controller,
  Inject,
  Optional,
  Param,
  Post,
  RawBodyRequest,
  Req,
  Res,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { Public } from '../auth/public.decorator';
import { PaymentProviderPort } from '../../infrastructure/payments/payment-provider.port';
import { ProviderWebhookError } from '../../infrastructure/payments/sandbox.adapter';
import { PaymentTransitionService } from './payment-transition.service';
import { RefundsService } from './refunds.service';

/**
 * §76–§78: provider-facing endpoint — signature auth, raw body, plain
 * provider-compatible responses (@Res bypasses the envelope interceptor).
 */
@Public()
@ApiExcludeController()
@Controller('webhooks/payments')
export class WebhooksController {
  constructor(
    private readonly transitions: PaymentTransitionService,
    private readonly refunds: RefundsService,
    @Optional()
    @Inject(PaymentProviderPort)
    private readonly provider: PaymentProviderPort | null,
  ) {}

  @Post(':provider')
  async receive(
    @Param('provider') provider: string,
    @Req() req: RawBodyRequest<Request>,
    @Res() res: Response,
  ): Promise<void> {
    if (!this.provider || provider !== this.provider.provider) {
      res.status(404).json({ received: false });
      return;
    }
    const rawBody = req.rawBody ?? Buffer.from(JSON.stringify(req.body ?? {}));
    const signature = req.header('x-sandbox-signature');

    let event;
    try {
      event = this.provider.verifyAndParseWebhook(rawBody, signature);
    } catch (error) {
      if (error instanceof ProviderWebhookError) {
        res
          .status(error.code === 'SIGNATURE_INVALID' ? 401 : 400)
          .json({ received: false, error: error.code });
        return;
      }
      throw error;
    }

    const applied = await this.transitions.applyProviderEvent(event, { signatureValid: true });
    if (applied.lateRefund) {
      // ADR 0040: refund a verified success that arrived after the slot was
      // released — runs outside the transition transaction (provider call).
      await this.refunds.refundLatePayment(applied.lateRefund);
    }
    res.status(200).json({ received: true });
  }
}
