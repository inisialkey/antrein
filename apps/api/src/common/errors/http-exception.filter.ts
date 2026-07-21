import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { buildMeta } from '../envelope/meta';

interface ErrorBody {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

/**
 * Maps every thrown error to the contract error envelope with a stable code.
 * Custom exceptions pass { code, message, details } as the HttpException body;
 * bare framework exceptions fall back to their name (e.g. NOT_FOUND), and
 * anything unexpected becomes SYSTEM_INTERNAL_ERROR with no internals leaked.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest<Request>();
    const res = ctx.getResponse<Response>();

    const { status, error } = this.resolve(exception);

    if (status >= 500) {
      this.logger.error(
        `Unhandled exception on ${req.method} ${req.path}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    res.status(status).json({ success: false, error, meta: buildMeta(req) });
  }

  private resolve(exception: unknown): { status: number; error: ErrorBody } {
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();

      if (typeof body === 'object' && body !== null && 'code' in body) {
        const { code, message, details } = body as ErrorBody & { message?: string };
        return {
          status,
          error: { code, message: message ?? exception.message, ...(details ? { details } : {}) },
        };
      }

      const fallbackCode = exception.constructor.name
        .replace(/Exception$/, '')
        .replace(/([a-z])([A-Z])/g, '$1_$2')
        .toUpperCase();
      return { status, error: { code: fallbackCode, message: exception.message } };
    }

    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      error: { code: 'SYSTEM_INTERNAL_ERROR', message: 'An unexpected error occurred.' },
    };
  }
}
