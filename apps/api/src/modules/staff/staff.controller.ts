import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import { Public } from '../auth/public.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { BusinessMemberGuard } from '../memberships/business-member.guard';
import { RequireBusinessPermission } from '../memberships/require-permission.decorator';
import { InviteStaffDto, ListStaffQueryDto, UpdateStaffDto } from './dto/staff.dto';
import { InvitationsService } from './invitations.service';
import { StaffService } from './staff.service';

@ApiTags('staff')
@Controller('businesses/:businessId/staff')
@UseGuards(BusinessMemberGuard)
export class StaffController {
  constructor(
    private readonly staff: StaffService,
    private readonly invitations: InvitationsService,
  ) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'List staff of a business' })
  list(
    @Param('businessId') businessId: string,
    @Query() query: ListStaffQueryDto,
  ): ReturnType<StaffService['listPublic']> {
    return this.staff.listPublic(businessId, query);
  }

  @Post('invitations')
  @ApiBearerAuth()
  @RequireBusinessPermission('staff.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Invite a staff member by email' })
  invite(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Body() dto: InviteStaffDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<InvitationsService['invite']> {
    return this.invitations.invite(principal.userId, businessId, dto, idempotencyKey);
  }

  @Patch(':staffId')
  @HttpCode(200)
  @ApiBearerAuth()
  @RequireBusinessPermission('staff.manage')
  @ApiOperation({ summary: 'Update a staff member' })
  update(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('staffId') staffId: string,
    @Body() dto: UpdateStaffDto,
    @Req() req: Request,
  ): ReturnType<StaffService['update']> {
    return this.staff.update(principal.userId, businessId, staffId, dto, req.requestId);
  }

  @Post(':staffId/deactivate')
  @HttpCode(200)
  @ApiBearerAuth()
  @RequireBusinessPermission('staff.manage')
  @ApiOperation({ summary: 'Deactivate a staff member' })
  deactivate(
    @Param('businessId') businessId: string,
    @Param('staffId') staffId: string,
  ): ReturnType<StaffService['deactivate']> {
    return this.staff.deactivate(businessId, staffId);
  }
}

@ApiTags('staff')
@Controller('staff/invitations')
export class InvitationAcceptController {
  constructor(private readonly invitations: InvitationsService) {}

  @Post(':invitationId/accept')
  @HttpCode(200)
  @ApiBearerAuth()
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Accept a staff invitation addressed to your email' })
  accept(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('invitationId') invitationId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<InvitationsService['accept']> {
    return this.invitations.accept(principal, invitationId, idempotencyKey);
  }
}
