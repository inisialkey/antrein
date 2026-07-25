import { Controller, Get, Param } from '@nestjs/common';
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
}
