import { Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { PaymentsService } from './payments.service';

@ApiTags('payments')
@ApiBearerAuth()
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get(':paymentId')
  @ApiOperation({ summary: 'Get payment (contract §71)' })
  get(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('paymentId') paymentId: string,
  ): ReturnType<PaymentsService['getPayment']> {
    return this.payments.getPayment(principal.userId, paymentId);
  }

  @Post(':paymentId/refresh')
  @HttpCode(200)
  @ApiOperation({ summary: 'Refresh payment status from provider (contract §72)' })
  refresh(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('paymentId') paymentId: string,
  ): ReturnType<PaymentsService['refreshPayment']> {
    return this.payments.refreshPayment(principal.userId, paymentId);
  }
}
