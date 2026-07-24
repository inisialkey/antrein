import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { accessTokenInvalid } from '../auth/auth.errors';
import { toMeResponse } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string): Promise<ReturnType<typeof toMeResponse>> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { notificationPreference: true },
    });
    if (!user || user.status === 'deleted') throw accessTokenInvalid();
    return toMeResponse(user, user.notificationPreference);
  }
}
