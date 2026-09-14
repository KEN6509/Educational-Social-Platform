import { randomUUID } from 'node:crypto';
import type { RequestHandler } from 'express';

export function requestTelemetry(): RequestHandler {
  return (req, res, next) => {
    const requestId = randomUUID();
    const startedAt = process.hrtime.bigint();
    res.locals.requestId = requestId;
    res.setHeader('X-Request-Id', requestId);
    res.on('finish', () => {
      const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
      console.info(JSON.stringify({
        requestId,
        method: req.method,
        path: req.path,
        status: res.statusCode,
        durationMs: Math.round(durationMs * 100) / 100,
        errorCategory: res.locals.errorCategory ?? null,
      }));
    });
    next();
  };
}
