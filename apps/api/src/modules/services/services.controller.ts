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
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/current-user.decorator';
import { Public } from '../auth/public.decorator';
import { AccessTokenPrincipal } from '../auth/token.service';
import { BusinessMemberGuard } from '../memberships/business-member.guard';
import { RequireBusinessPermission } from '../memberships/require-permission.decorator';
import { CreateServiceDto, ListServicesQueryDto, UpdateServiceDto } from './dto/service.dto';
import { ServicesService } from './services.service';

@ApiTags('services')
@Controller('businesses/:businessId/services')
@UseGuards(BusinessMemberGuard)
export class ServicesController {
  constructor(private readonly services: ServicesService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'List services of a business' })
  list(
    @Param('businessId') businessId: string,
    @Query() query: ListServicesQueryDto,
  ): ReturnType<ServicesService['listPublic']> {
    return this.services.listPublic(businessId, query);
  }

  @Post()
  @ApiBearerAuth()
  @RequireBusinessPermission('service.manage')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Create a service' })
  create(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Body() dto: CreateServiceDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<ServicesService['create']> {
    return this.services.create(principal.userId, businessId, dto, idempotencyKey);
  }

  @Patch(':serviceId')
  @HttpCode(200)
  @ApiBearerAuth()
  @RequireBusinessPermission('service.manage')
  @ApiOperation({ summary: 'Update a service' })
  update(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Param('serviceId') serviceId: string,
    @Body() dto: UpdateServiceDto,
  ): ReturnType<ServicesService['update']> {
    return this.services.update(businessId, serviceId, dto, principal.userId);
  }

  @Post(':serviceId/deactivate')
  @HttpCode(200)
  @ApiBearerAuth()
  @RequireBusinessPermission('service.manage')
  @ApiOperation({ summary: 'Deactivate a service' })
  deactivate(
    @Param('businessId') businessId: string,
    @Param('serviceId') serviceId: string,
  ): ReturnType<ServicesService['deactivate']> {
    return this.services.deactivate(businessId, serviceId);
  }
}
