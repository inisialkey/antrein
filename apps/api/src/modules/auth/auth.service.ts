import { Injectable, Logger } from '@nestjs/common';
import { newId } from '../../common/id/id';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import { Prisma, User } from '../../generated/prisma/client';
import { MembershipsService } from '../memberships/memberships.service';
import { toUserResponse, UserResponse } from '../users/user.mapper';
import {
  accountInactive,
  accountSuspended,
  emailAlreadyRegistered,
  invalidCredentials,
  rateLimitExceeded,
  refreshTokenExpired,
  refreshTokenInvalid,
  refreshTokenReused,
  sessionRevoked,
} from './auth.errors';
import { normalizeEmail, validatePasswordPolicy } from './auth.policies';
import { DeviceDto, LoginDto, LogoutDto, RefreshDto, RegisterDto } from './dto/auth.dto';
import { PasswordHasher } from './password.hasher';
import { RateLimitService } from './rate-limit.service';
import { AccessTokenPrincipal, TokenService } from './token.service';

export interface RequestContext {
  ip?: string;
  userAgent?: string;
}

export interface SessionTokens {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

/** ADR 0034 rate-limit defaults. ponytail: constants here, env overrides when ops needs them. */
const LIMITS = {
  login: { limit: 5, windowMs: 60_000 },
  register: { limit: 3, windowMs: 60_000 },
} as const;

interface RawSessionRow {
  id: string;
  user_id: string;
  device_id: string | null;
  refresh_token_hash: string;
  token_family_id: string;
  status: string;
  expires_at: Date;
}

type RefreshOutcome =
  | { kind: 'invalid' | 'revoked' | 'expired' | 'reused' }
  | { kind: 'ok'; userId: string; sessionId: string; refreshToken: string; refreshExpiresAt: Date };

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly hasher: PasswordHasher,
    private readonly tokens: TokenService,
    private readonly rateLimit: RateLimitService,
    private readonly memberships: MembershipsService,
  ) {}

  async register(
    dto: RegisterDto,
    ctx: RequestContext,
  ): Promise<{ user: UserResponse; session: SessionTokens }> {
    if (
      !this.rateLimit.consume(
        'register',
        ctx.ip ?? 'unknown',
        LIMITS.register.limit,
        LIMITS.register.windowMs,
      )
    ) {
      throw rateLimitExceeded();
    }

    validatePasswordPolicy(dto.password);
    const emailNormalized = normalizeEmail(dto.email);
    const passwordHash = await this.hasher.hash(dto.password);
    const userId = newId('usr');

    try {
      const { user, session } = await this.prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: {
            id: userId,
            email: dto.email.trim(),
            emailNormalized,
            phoneNumber: dto.phoneNumber ?? null,
            name: dto.name.trim(),
            passwordHash,
            status: 'active',
          },
        });
        await tx.userNotificationPreference.create({ data: { userId } });
        const session = await this.createSession(tx, { userId, ctx });
        return { user, session };
      });

      this.logger.log(`auth.registration_succeeded user=${userId}`);
      return { user: toUserResponse(user, []), session };
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw emailAlreadyRegistered();
      throw error;
    }
  }

  async login(
    dto: LoginDto,
    ctx: RequestContext,
  ): Promise<{ user: UserResponse; session: SessionTokens }> {
    const emailNormalized = normalizeEmail(dto.email);
    const rateKey = `${ctx.ip ?? 'unknown'}|${emailNormalized}`;
    if (!this.rateLimit.consume('login', rateKey, LIMITS.login.limit, LIMITS.login.windowMs)) {
      throw rateLimitExceeded();
    }

    const user = await this.prisma.user.findUnique({ where: { emailNormalized } });
    if (!user) {
      await this.hasher.verifyAgainstDummy(dto.password);
      this.logger.warn(`auth.login_failed reason=unknown_email`);
      throw invalidCredentials();
    }

    const passwordValid = await this.hasher.verify(user.passwordHash, dto.password);
    if (!passwordValid) {
      this.logger.warn(`auth.login_failed user=${user.id} reason=wrong_password`);
      throw invalidCredentials();
    }

    this.assertCanAuthenticate(user);
    await this.rehashIfNeeded(user, dto.password);

    const session = await this.prisma.$transaction(async (tx) => {
      const deviceId = dto.device ? await this.upsertDevice(tx, user.id, dto.device) : null;
      const session = await this.createSession(tx, { userId: user.id, deviceId, ctx });
      await tx.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
      return session;
    });

    this.logger.log(`auth.login_succeeded user=${user.id}`);
    return { user: toUserResponse(user, await this.memberships.listForUser(user.id)), session };
  }

  async refresh(dto: RefreshDto, ctx: RequestContext): Promise<SessionTokens> {
    const parsed = this.tokens.parseRefreshToken(dto.refreshToken);
    if (!parsed) throw refreshTokenInvalid();

    const outcome = await this.prisma.$transaction(async (tx): Promise<RefreshOutcome> => {
      const rows = await tx.$queryRaw<RawSessionRow[]>`
        SELECT id, user_id, device_id, refresh_token_hash, token_family_id, status, expires_at
        FROM auth_sessions WHERE id = ${parsed.sessionId} FOR UPDATE`;
      const session = rows[0];
      if (!session) return { kind: 'invalid' };
      if (!this.tokens.refreshSecretMatches(parsed.secret, session.refresh_token_hash)) {
        return { kind: 'invalid' };
      }

      const now = new Date();
      if (session.status === 'rotated') {
        // Strict reuse detection (ADR 0039): kill every active session in the family.
        await tx.authSession.updateMany({
          where: { tokenFamilyId: session.token_family_id, status: 'active' },
          data: { status: 'compromised', revokedAt: now, revokedReason: 'refresh_token_reuse' },
        });
        return { kind: 'reused' };
      }
      if (session.status !== 'active') return { kind: 'revoked' };
      if (session.expires_at.getTime() <= now.getTime()) {
        await tx.authSession.update({ where: { id: session.id }, data: { status: 'expired' } });
        return { kind: 'expired' };
      }

      const sessionId = newId('ses');
      const refresh = this.tokens.generateRefreshToken(sessionId);
      await tx.authSession.update({
        where: { id: session.id },
        data: { status: 'rotated', lastUsedAt: now },
      });
      await tx.authSession.create({
        data: {
          id: sessionId,
          userId: session.user_id,
          deviceId: session.device_id,
          refreshTokenHash: refresh.secretHash,
          tokenFamilyId: session.token_family_id,
          parentSessionId: session.id,
          status: 'active',
          issuedAt: now,
          expiresAt: refresh.expiresAt,
          ipAddress: ctx.ip ?? null,
          userAgent: ctx.userAgent ?? null,
        },
      });
      return {
        kind: 'ok',
        userId: session.user_id,
        sessionId,
        refreshToken: refresh.token,
        refreshExpiresAt: refresh.expiresAt,
      };
    });

    switch (outcome.kind) {
      case 'invalid':
        throw refreshTokenInvalid();
      case 'revoked':
        throw sessionRevoked();
      case 'expired':
        throw refreshTokenExpired();
      case 'reused':
        this.logger.warn(
          `auth.refresh_token_reused session=${parsed.sessionId} severity=high family_revoked=true`,
        );
        throw refreshTokenReused();
    }

    const access = this.tokens.signAccessToken(outcome.userId, outcome.sessionId);
    this.logger.log(`auth.refresh_succeeded user=${outcome.userId} session=${outcome.sessionId}`);
    return {
      accessToken: access.token,
      accessTokenExpiresAt: access.expiresAt.toISOString(),
      refreshToken: outcome.refreshToken,
      refreshTokenExpiresAt: outcome.refreshExpiresAt.toISOString(),
    };
  }

  async logout(principal: AccessTokenPrincipal, dto: LogoutDto): Promise<{ loggedOut: true }> {
    const session = await this.prisma.authSession.findUnique({
      where: { id: principal.sessionId },
    });

    await this.prisma.authSession.updateMany({
      where: { id: principal.sessionId, status: 'active' },
      data: { status: 'revoked', revokedAt: new Date(), revokedReason: 'user_logout' },
    });

    // Signed-out phones stop receiving pushes (ADR 0039).
    const deviceId = session?.deviceId ?? dto.deviceId;
    if (deviceId) {
      await this.prisma.device.updateMany({
        where: { id: deviceId, userId: principal.userId },
        data: { status: 'inactive' },
      });
    }

    this.logger.log(`auth.logout user=${principal.userId} session=${principal.sessionId}`);
    return { loggedOut: true };
  }

  /** Shared by register/login (root session: family = own id). */
  private async createSession(
    tx: Prisma.TransactionClient,
    input: { userId: string; deviceId?: string | null; ctx: RequestContext },
  ): Promise<SessionTokens> {
    const sessionId = newId('ses');
    const refresh = this.tokens.generateRefreshToken(sessionId);
    const now = new Date();

    await tx.authSession.create({
      data: {
        id: sessionId,
        userId: input.userId,
        deviceId: input.deviceId ?? null,
        refreshTokenHash: refresh.secretHash,
        tokenFamilyId: sessionId,
        status: 'active',
        issuedAt: now,
        expiresAt: refresh.expiresAt,
        ipAddress: input.ctx.ip ?? null,
        userAgent: input.ctx.userAgent ?? null,
      },
    });

    const access = this.tokens.signAccessToken(input.userId, sessionId);
    return {
      accessToken: access.token,
      accessTokenExpiresAt: access.expiresAt.toISOString(),
      refreshToken: refresh.token,
      refreshTokenExpiresAt: refresh.expiresAt.toISOString(),
    };
  }

  private async upsertDevice(
    tx: Prisma.TransactionClient,
    userId: string,
    device: DeviceDto,
  ): Promise<string> {
    const data = {
      userId,
      platform: device.platform,
      appVersion: device.appVersion ?? null,
      deviceName: device.deviceName ?? null,
      status: 'active',
      lastSeenAt: new Date(),
    };
    await tx.device.upsert({
      where: { id: device.deviceId },
      update: data,
      create: { id: device.deviceId, ...data },
    });
    return device.deviceId;
  }

  private assertCanAuthenticate(user: User): void {
    if (user.status === 'suspended') throw accountSuspended();
    if (user.status === 'inactive') throw accountInactive();
    if (user.status !== 'active') throw invalidCredentials(); // deleted: no disclosure
  }

  private async rehashIfNeeded(user: User, password: string): Promise<void> {
    if (!this.hasher.needsRehash(user.passwordHash)) return;
    try {
      const passwordHash = await this.hasher.hash(password);
      await this.prisma.user.update({ where: { id: user.id }, data: { passwordHash } });
    } catch (error) {
      // §9.4: a failed rehash must never fail a valid login.
      this.logger.warn(`auth.rehash_failed user=${user.id}: ${(error as Error).message}`);
    }
  }
}
