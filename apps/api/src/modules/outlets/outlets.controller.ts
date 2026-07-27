import { Body, Controller, HttpCode, Param, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UpdateOutletDto } from '../businesses/dto/business.dto';
import { BusinessMemberGuard } from '../memberships/business-member.guard';
import { RequireBusinessPermission } from '../memberships/require-permission.decorator';
import { OutletsService } from './outlets.service';

@ApiTags('outlets')
@Controller('businesses/:businessId/outlets')
@UseGuards(BusinessMemberGuard)
export class OutletsController {
  constructor(private readonly outlets: OutletsService) {}

  @Patch(':outletId')
  @HttpCode(200)
  @ApiBearerAuth()
  @RequireBusinessPermission('business.manage')
  @ApiOperation({ summary: 'Update an outlet' })
  update(
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
    @Body() dto: UpdateOutletDto,
  ): ReturnType<OutletsService['update']> {
    return this.outlets.update(businessId, outletId, dto);
  }
}
