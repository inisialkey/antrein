import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { Public } from '../auth/public.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { BusinessMemberGuard } from '../memberships/business-member.guard';
import { RequireBusinessPermission } from '../memberships/require-permission.decorator';
import {
  AvailabilityQueryDto,
  CreateClosedDateDto,
  ListClosedDatesQueryDto,
  ReplaceOperatingHoursDto,
  ReplaceStaffScheduleDto,
} from './dto/schedule.dto';
import { SchedulesService } from './schedules.service';

@ApiTags('schedules')
@Controller('businesses')
@UseGuards(BusinessMemberGuard)
export class SchedulesController {
  constructor(private readonly schedules: SchedulesService) {}

  @Public()
  @Get(':businessId/availability')
  @ApiOperation({ summary: 'Get available booking slots (contract §42)' })
  availability(
    @Param('businessId') businessId: string,
    @Query() query: AvailabilityQueryDto,
  ): ReturnType<SchedulesService['getAvailability']> {
    return this.schedules.getAvailability(businessId, query);
  }

  @Get(':businessId/outlets/:outletId/operating-hours')
  @ApiBearerAuth()
  @RequireBusinessPermission(null)
  @ApiOperation({ summary: 'Get outlet operating hours' })
  getOperatingHours(
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
  ): ReturnType<SchedulesService['getOperatingHours']> {
    return this.schedules.getOperatingHours(businessId, outletId);
  }

  @Put(':businessId/outlets/:outletId/operating-hours')
  @ApiBearerAuth()
  @RequireBusinessPermission('business.manage')
  @ApiOperation({ summary: 'Replace outlet operating hours' })
  replaceOperatingHours(
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
    @Body() dto: ReplaceOperatingHoursDto,
  ): ReturnType<SchedulesService['replaceOperatingHours']> {
    return this.schedules.replaceOperatingHours(businessId, outletId, dto);
  }

  @Get(':businessId/outlets/:outletId/closed-dates')
  @ApiBearerAuth()
  @RequireBusinessPermission(null)
  @ApiOperation({ summary: 'List closed dates' })
  listClosedDates(
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
    @Query() query: ListClosedDatesQueryDto,
  ): ReturnType<SchedulesService['listClosedDates']> {
    return this.schedules.listClosedDates(businessId, outletId, query);
  }

  @Post(':businessId/outlets/:outletId/closed-dates')
  @HttpCode(201)
  @ApiBearerAuth()
  @RequireBusinessPermission('business.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Create a closed date' })
  createClosedDate(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('outletId') outletId: string,
    @Body() dto: CreateClosedDateDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<SchedulesService['createClosedDate']> {
    return this.schedules.createClosedDate(
      principal.userId,
      businessId,
      outletId,
      dto,
      idempotencyKey,
    );
  }

  @Put(':businessId/staff/:staffId/schedule')
  @ApiBearerAuth()
  @RequireBusinessPermission('staff.manage')
  @ApiOperation({ summary: 'Replace a staff weekly schedule' })
  replaceStaffSchedule(
    @Param('businessId') businessId: string,
    @Param('staffId') staffId: string,
    @Body() dto: ReplaceStaffScheduleDto,
  ): ReturnType<SchedulesService['replaceStaffSchedule']> {
    return this.schedules.replaceStaffSchedule(businessId, staffId, dto);
  }
}
