import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { BusinessMemberGuard } from '../memberships/business-member.guard';
import { RequireBusinessPermission } from '../memberships/require-permission.decorator';
import { DailySummaryQueryDto } from './dto/report.dto';
import { ReportsService } from './reports.service';

@ApiTags('reports')
@ApiBearerAuth()
@UseGuards(BusinessMemberGuard)
@Controller('businesses/:businessId/reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('daily-summary')
  @RequireBusinessPermission('reports.read')
  @ApiOperation({ summary: 'Daily operational summary for one outlet (contract §98)' })
  dailySummary(
    @Param('businessId') businessId: string,
    @Query() query: DailySummaryQueryDto,
  ): ReturnType<ReportsService['dailySummary']> {
    return this.reports.dailySummary(businessId, query);
  }
}
