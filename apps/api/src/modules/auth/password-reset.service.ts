import { createHash, randomBytes } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { newId } from '../../common/id/id';
import { EmailPort } from '../../infrastructure/email/email.port';
import { PrismaService } from '../../infrastructure/database/prisma.service';
import {
  passwordReuseNotAllowed,
  rateLimitExceeded,
  resetTokenExpired,
  resetTokenInvalid,
} from './auth.errors';
import { normalizeEmail, validatePasswordPolicy } from './auth.policies';
import { ForgotPasswordDto, ResetPasswordDto } from './dto/auth.dto';
import { PasswordHasher } from './password.hasher';
import { RateLimitService } from './rate-limit.service';
import { RequestContext } from './auth.service';

/** ADR 0034 defaults: forgot 3/15min per IP+email, reset 5/min per IP. */
const LIMITS = {
  forgot: { limit: 3, windowMs: 15 * 60_000 },
  reset: { limit: 5, windowMs: 60_000 },
} as const;

@Injectable()
export class PasswordResetService {
  private readonly logger = new Logger(PasswordResetService.name);
  private readonly tokenTtlMinutes: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly hasher: PasswordHasher,
    private readonly rateLimit: RateLimitService,
    private readonly email: EmailPort,
    config: ConfigService,
  ) {
    this.tokenTtlMinutes = config.get<number>('RESET_TOKEN_TTL_MINUTES') ?? 30;
  }

  async requestReset(dto: ForgotPasswordDto, ctx: RequestContext): Promise<{ accepted: true }> {
    const emailNormalized = normalizeEmail(dto.email);
    const rateKey = `${ctx.ip ?? 'unknown'}|${emailNormalized}`;
    if (!this.rateLimit.consume('forgot', rateKey, LIMITS.forgot.limit, LIMITS.forgot.windowMs)) {
      throw rateLimitExceeded();
    }

    const user = await this.prisma.user.findUnique({ where: { emailNormalized } });
    if (user && user.status === 'active') {
      const token = randomBytes(32).toString('base64url');
      await this.prisma.$transaction(async (tx) => {
        // A new request invalidates prior unused tokens (ADR 0039).
        await tx.passwordResetToken.deleteMany({ where: { userId: user.id, usedAt: null } });
        await tx.passwordResetToken.create({
          data: {
            id: newId('prt'),
            userId: user.id,
            tokenHash: sha256(token),
            expiresAt: new Date(Date.now() + this.tokenTtlMinutes * 60_000),
          },
        });
      });

      // Fire-and-forget: the public response never depends on email delivery (§41).
      void this.email
        .sendPasswordReset({
          to: user.email,
          name: user.name,
          token,
          expiresInMinutes: this.tokenTtlMinutes,
        })
        .catch((error: Error) =>
          this.logger.error(`auth.password_reset_email_failed user=${user.id}: ${error.message}`),
        );
      this.logger.log(`auth.password_reset_requested user=${user.id}`);
    }

    return { accepted: true };
  }

  async resetPassword(
    dto: ResetPasswordDto,
    ctx: RequestContext,
  ): Promise<{ passwordReset: true; allSessionsRevoked: true }> {
    if (
      !this.rateLimit.consume(
        'reset',
        ctx.ip ?? 'unknown',
        LIMITS.reset.limit,
        LIMITS.reset.windowMs,
      )
    ) {
      throw rateLimitExceeded();
    }

    const record = await this.prisma.passwordResetToken.findUnique({
      where: { tokenHash: sha256(dto.token) },
      include: { user: true },
    });
    if (!record || record.usedAt) throw resetTokenInvalid();
    if (record.expiresAt.getTime() <= Date.now()) throw resetTokenExpired();

    validatePasswordPolicy(dto.newPassword);
    if (await this.hasher.verify(record.user.passwordHash, dto.newPassword)) {
      throw passwordReuseNotAllowed();
    }
    const passwordHash = await this.hasher.hash(dto.newPassword);

    const claimed = await this.prisma.$transaction(async (tx) => {
      // Single-use claim: exactly one concurrent reset can win this update.
      const claim = await tx.passwordResetToken.updateMany({
        where: { id: record.id, usedAt: null },
        data: { usedAt: new Date() },
      });
      if (claim.count === 0) return false;

      await tx.user.update({ where: { id: record.userId }, data: { passwordHash } });
      await tx.authSession.updateMany({
        where: { userId: record.userId, status: 'active' },
        data: { status: 'revoked', revokedAt: new Date(), revokedReason: 'password_reset' },
      });
      return true;
    });
    if (!claimed) throw resetTokenInvalid();

    void this.email
      .sendPasswordChanged({ to: record.user.email, name: record.user.name })
      .catch((error: Error) =>
        this.logger.error(
          `auth.password_changed_email_failed user=${record.userId}: ${error.message}`,
        ),
      );

    this.logger.log(`auth.password_reset_succeeded user=${record.userId} sessions_revoked=all`);
    return { passwordReset: true, allSessionsRevoked: true };
  }
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
