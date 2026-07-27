import { Controller, Get, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { RefundsService } from './refunds.service';

@ApiTags('payments')
@ApiBearerAuth()
@Controller('refunds')
export class RefundsController {
  constructor(private readonly refunds: RefundsService) {}

  @Get(':refundId')
  @ApiOperation({ summary: 'Get refund (contract §75)' })
  get(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('refundId') refundId: string,
  ): ReturnType<RefundsService['getRefund']> {
    return this.refunds.getRefund(principal.userId, refundId);
  }
}
