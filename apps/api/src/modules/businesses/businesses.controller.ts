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
import { BusinessesService } from './businesses.service';
import { CreateBusinessDto, ListBusinessesQueryDto, UpdateBusinessDto } from './dto/business.dto';

@ApiTags('businesses')
@Controller('businesses')
@UseGuards(BusinessMemberGuard)
export class BusinessesController {
  constructor(private readonly businesses: BusinessesService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'List active businesses for discovery' })
  list(@Query() query: ListBusinessesQueryDto): ReturnType<BusinessesService['listPublic']> {
    return this.businesses.listPublic(query);
  }

  @Post()
  @ApiBearerAuth()
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiOperation({ summary: 'Create a business with its primary outlet' })
  create(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Body() dto: CreateBusinessDto,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ): ReturnType<BusinessesService['create']> {
    return this.businesses.create(principal.userId, dto, idempotencyKey);
  }

  @Public()
  @Get(':businessId')
  @ApiOperation({ summary: 'Get public business details' })
  details(
    @Param('businessId') businessId: string,
  ): ReturnType<BusinessesService['getPublicDetails']> {
    return this.businesses.getPublicDetails(businessId);
  }

  @Get(':businessId/management')
  @ApiBearerAuth()
  @RequireBusinessPermission(null)
  @ApiOperation({ summary: 'Get the managed business representation' })
  management(
    @Param('businessId') businessId: string,
  ): ReturnType<BusinessesService['getManagement']> {
    return this.businesses.getManagement(businessId);
  }

  @Patch(':businessId')
  @HttpCode(200)
  @ApiBearerAuth()
  @RequireBusinessPermission('business.manage')
  @ApiOperation({ summary: 'Update business profile and policies' })
  update(
    @CurrentUser() principal: AccessTokenPrincipal,
    @Param('businessId') businessId: string,
    @Body() dto: UpdateBusinessDto,
  ): ReturnType<BusinessesService['update']> {
    return this.businesses.update(businessId, dto, principal.userId);
  }
}
