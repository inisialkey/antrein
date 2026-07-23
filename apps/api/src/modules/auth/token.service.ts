import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, TokenExpiredError } from '@nestjs/jwt';
import { accessTokenExpired, accessTokenInvalid } from './auth.errors';

export interface TokenServiceOptions {
  accessSecret: string;
  accessTtlMinutes: number;
  refreshTtlDays: number;
  issuer: string;
  audience: string;
}

export interface AccessTokenPrincipal {
  userId: string;
  sessionId: string;
  issuedAt: Date;
}

interface AccessTokenPayload {
  sub: string;
  sid: string;
  type: string;
  iat: number;
}

const SESSION_ID_PATTERN = /^ses_[0-9A-HJKMNP-TV-Z]{26}$/;

/**
 * Access JWT (HS256, ADR 0025) + opaque refresh token `sessionId.randomSecret`
 * (ADR 0039). Only the SHA-256 of the refresh secret is ever stored.
 */
@Injectable()
export class TokenService {
  private readonly jwt: JwtService;

  constructor(private readonly options: TokenServiceOptions) {
    this.jwt = new JwtService({
      secret: options.accessSecret,
      signOptions: { algorithm: 'HS256', issuer: options.issuer, audience: options.audience },
      verifyOptions: {
        algorithms: ['HS256'],
        issuer: options.issuer,
        audience: options.audience,
      },
    });
  }

  static fromConfig(config: ConfigService): TokenService {
    return new TokenService({
      accessSecret: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      accessTtlMinutes: config.getOrThrow<number>('ACCESS_TOKEN_TTL_MINUTES'),
      refreshTtlDays: config.getOrThrow<number>('REFRESH_TOKEN_TTL_DAYS'),
      issuer: config.get<string>('JWT_ISSUER') ?? 'antrein-api',
      audience: config.get<string>('JWT_AUDIENCE') ?? 'antrein-mobile',
    });
  }

  signAccessToken(userId: string, sessionId: string): { token: string; expiresAt: Date } {
    const expiresAt = new Date(Date.now() + this.options.accessTtlMinutes * 60_000);
    const token = this.jwt.sign(
      { sub: userId, sid: sessionId, type: 'access' },
      { expiresIn: `${this.options.accessTtlMinutes}m` },
    );
    return { token, expiresAt };
  }

  verifyAccessToken(token: string): AccessTokenPrincipal {
    let payload: AccessTokenPayload;
    try {
      payload = this.jwt.verify<AccessTokenPayload>(token);
    } catch (error) {
      throw error instanceof TokenExpiredError ? accessTokenExpired() : accessTokenInvalid();
    }
    if (payload.type !== 'access' || !payload.sub || !SESSION_ID_PATTERN.test(payload.sid)) {
      throw accessTokenInvalid();
    }
    return { userId: payload.sub, sessionId: payload.sid, issuedAt: new Date(payload.iat * 1000) };
  }

  generateRefreshToken(sessionId: string): { token: string; secretHash: string; expiresAt: Date } {
    const secret = randomBytes(32).toString('base64url');
    return {
      token: `${sessionId}.${secret}`,
      secretHash: this.hashRefreshSecret(secret),
      expiresAt: new Date(Date.now() + this.options.refreshTtlDays * 86_400_000),
    };
  }

  parseRefreshToken(raw: string): { sessionId: string; secret: string } | null {
    const separator = raw.indexOf('.');
    if (separator <= 0) return null;
    const sessionId = raw.slice(0, separator);
    const secret = raw.slice(separator + 1);
    if (!SESSION_ID_PATTERN.test(sessionId) || secret.length === 0) return null;
    return { sessionId, secret };
  }

  refreshSecretMatches(secret: string, storedHash: string): boolean {
    const candidate = Buffer.from(this.hashRefreshSecret(secret), 'hex');
    const stored = Buffer.from(storedHash, 'hex');
    return candidate.length === stored.length && timingSafeEqual(candidate, stored);
  }

  private hashRefreshSecret(secret: string): string {
    return createHash('sha256').update(secret).digest('hex');
  }
}
