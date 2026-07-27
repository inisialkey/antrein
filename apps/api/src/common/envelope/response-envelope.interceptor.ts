import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Request } from 'express';
import { Observable, map } from 'rxjs';
import { buildMeta } from './meta';

/**
 * Wraps controller results in the contract envelope:
 * { success: true, data, meta: { requestId, timestamp } }
 * Health endpoints keep their own contract shape and are skipped.
 *
 * Collection convention (api-contract §16): controllers return
 * { items, pagination } and the pagination block is hoisted into meta so the
 * body stays { data: { items }, meta: { ..., pagination } }.
 */
@Injectable()
export class ResponseEnvelopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    if (req.path.startsWith('/health/')) {
      return next.handle();
    }
    return next.handle().pipe(
      map((data: unknown) => {
        if (data !== null && typeof data === 'object' && 'pagination' in data && 'items' in data) {
          const { pagination, ...rest } = data as { pagination: unknown };
          return { success: true, data: rest, meta: { ...buildMeta(req), pagination } };
        }
        return { success: true, data, meta: buildMeta(req) };
      }),
    );
  }
}
