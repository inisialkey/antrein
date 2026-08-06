import { Injectable } from '@nestjs/common';
import { fileUrl } from '../../common/files/file-url';
import { Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { accessTokenInvalid } from '../auth/auth.errors';
import { normalizePhoneNumber } from '../auth/auth.policies';
import { FilesService } from '../files/files.service';
import { MembershipsService } from '../memberships/memberships.service';
import { UpdateMeDto, UpdateNotificationPreferencesDto } from './dto/user.dto';
import { userPhoneAlreadyUsed } from './user.errors';
import { toMeResponse } from './user.mapper';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly memberships: MembershipsService,
    private readonly files: FilesService,
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

  /** api-contract §32. Omitted fields stay as-is; an explicit null clears one. */
  async updateMe(userId: string, dto: UpdateMeDto): Promise<Record<string, unknown>> {
    const current = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!current || current.status === 'deleted') throw accessTokenInvalid();

    const data: Prisma.UserUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name.trim();
    if (dto.phoneNumber !== undefined) {
      data.phoneNumber = dto.phoneNumber === null ? null : dto.phoneNumber.trim();
      data.phoneNumberNormalized = normalizePhoneNumber(dto.phoneNumber);
    }
    if (dto.avatarFileId !== undefined) {
      data.avatarFile =
        dto.avatarFileId === null ? { disconnect: true } : { connect: { id: dto.avatarFileId } };
    }

    const updated = await this.prisma
      .$transaction(async (tx) => {
        if (dto.avatarFileId) {
          await this.files.attach(
            { fileId: dto.avatarFileId, actorUserId: userId, previousFileId: current.avatarFileId },
            tx,
          );
        }
        return tx.user.update({ where: { id: userId }, data });
      })
      .catch((error: unknown) => {
        // users_phone_normalized_uq is the only unique column this can touch.
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          throw userPhoneAlreadyUsed();
        }
        throw error;
      });

    return {
      id: updated.id,
      name: updated.name,
      email: updated.email,
      phoneNumber: updated.phoneNumber,
      avatarUrl: fileUrl(updated.avatarFileId),
      updatedAt: updated.updatedAt.toISOString(),
    };
  }

  /** api-contract §33. Partial — an omitted flag keeps its stored value. */
  async updateNotificationPreferences(
    userId: string,
    dto: UpdateNotificationPreferencesDto,
  ): Promise<Record<string, unknown>> {
    const prefs = await this.prisma.userNotificationPreference.upsert({
      where: { userId },
      // Registration seeds this row; upsert covers accounts that predate M9.
      create: { userId, ...dto },
      update: dto,
    });
    return {
      bookingUpdates: prefs.bookingUpdates,
      paymentUpdates: prefs.paymentUpdates,
      queueUpdates: prefs.queueUpdates,
      marketing: prefs.marketing,
      updatedAt: prefs.updatedAt.toISOString(),
    };
  }
}
