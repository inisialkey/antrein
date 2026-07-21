import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Request } from 'express';
import { Observable, map } from 'rxjs';
import { buildMeta } from './meta';

/**
 * Wraps controller results in the contract envelope:
 * { success: true, data, meta: { requestId, timestamp } }
 * Health endpoints keep their own contract shape and are skipped.
 */
@Injectable()
export class ResponseEnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    if (req.path.startsWith('/health/')) {
      return next.handle();
    }
    return next.handle().pipe(map((data) => ({ success: true, data, meta: buildMeta(req) })));
  }
}
