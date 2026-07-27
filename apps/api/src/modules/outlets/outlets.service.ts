import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { outletNotFound } from '../businesses/business.errors';
import { toOutletResponse } from '../businesses/business.mapper';
import { UpdateOutletDto } from '../businesses/dto/business.dto';

@Injectable()
export class OutletsService {
  constructor(private readonly prisma: PrismaService) {}

  async update(
    businessId: string,
    outletId: string,
    dto: UpdateOutletDto,
  ): Promise<Record<string, unknown>> {
    const outlet = await this.prisma.outlet.findUnique({ where: { id: outletId } });
    // An outlet under another business is a 404, never a hint it exists.
    if (!outlet || outlet.businessId !== businessId) throw outletNotFound();

    const updated = await this.prisma.outlet.update({
      where: { id: outletId },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.phoneNumber !== undefined ? { phoneNumber: dto.phoneNumber } : {}),
        ...(dto.timezone !== undefined ? { timezone: dto.timezone } : {}),
        ...(dto.address !== undefined
          ? {
              addressFormatted: dto.address.formatted,
              latitude: dto.address.latitude ?? null,
              longitude: dto.address.longitude ?? null,
            }
          : {}),
      },
    });
    return toOutletResponse(updated);
  }
}
