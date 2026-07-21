import { Request } from 'express';

export interface ResponseMeta {
  requestId: string;
  timestamp: string;
}

export function buildMeta(req: Request): ResponseMeta {
  return {
    requestId: req.requestId ?? 'req_unknown',
    timestamp: new Date().toISOString(),
  };
}
