import { ExecutionContext, createParamDecorator } from '@nestjs/common';
import { Request } from 'express';
import { AccessTokenPrincipal } from './token.service';

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AccessTokenPrincipal => {
    const req = context.switchToHttp().getRequest<Request>();
    return req.principal as AccessTokenPrincipal;
  },
);

declare module 'express-serve-static-core' {
  interface Request {
    principal?: AccessTokenPrincipal;
  }
}
