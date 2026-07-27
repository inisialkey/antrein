import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { accessTokenInvalid } from '../auth/auth.errors';
import { MembershipsService } from '../memberships/memberships.service';
import { toMeResponse } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly memberships: MembershipsService,
  ) {}

  async getMe(userId: string): Promise<ReturnType<typeof toMeResponse>> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { notificationPreference: true },
    });
    if (!user || user.status === 'deleted') throw accessTokenInvalid();
    const memberships = await this.memberships.listForUser(userId);
    return toMeResponse(user, user.notificationPreference, memberships);
  }
}
