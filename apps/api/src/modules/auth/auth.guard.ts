import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { accessTokenInvalid } from './auth.errors';
import { IS_PUBLIC_KEY } from './public.decorator';
import { TokenService } from './token.service';

/**
 * Global bearer-token guard. Stateless by design (ADR 0039): no session lookup
 * per request — revocation takes effect within the 15-minute access TTL, and
 * sensitive mutations re-check user state in their own use cases.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const req = context.switchToHttp().getRequest<Request>();
    const header = req.header('authorization');
    if (!header?.startsWith('Bearer ')) throw accessTokenInvalid();

    req.principal = this.tokens.verifyAccessToken(header.slice('Bearer '.length));
    return true;
  }
}
