import cors from 'cors';
import express, { type Router } from 'express';
import helmetModule from 'helmet';

import type { VerifyAdmin } from './admin/adminAuth.js';
import {
  createAdminRouter,
  type CreateAdministratorInput,
} from './routes/admin.js';
import { healthRouter } from './routes/health.js';
import { requestTelemetry } from './middleware/requestTelemetry.js';

export type AppDependencies = {
  allowedOrigins?: readonly string[];
  bootstrapSecret: string;
  countAdministrators: () => Promise<number>;
  createAdministrator: (
    input: CreateAdministratorInput,
  ) => Promise<{ id: string }>;
  upsertAdministratorProfile: (
    input: CreateAdministratorInput & { id: string },
  ) => Promise<void>;
  protectedAdminRouter: Router;
  moderationRouter: Router;
  pushRouter?: Router;
  maintenanceRouter?: Router;
  verifyAdmin: VerifyAdmin;
};

const createHelmetMiddleware = helmetModule as unknown as () => express.RequestHandler;

export function createApp(
  dependencies: AppDependencies,
  app: express.Express = express(),
) {
  const allowedOrigins = new Set(dependencies.allowedOrigins ?? []);

  app.use(requestTelemetry());
  app.use(createHelmetMiddleware());
  app.use(cors({
    origin: (origin, callback) => {
      callback(null, origin == null || allowedOrigins.has(origin));
    },
  }));
  app.use(express.json({ limit: '2mb' }));

  app.use('/admin', createAdminRouter(dependencies));
  app.use('/moderation', dependencies.moderationRouter);
  if (dependencies.pushRouter) app.use('/push', dependencies.pushRouter);
  if (dependencies.maintenanceRouter) app.use('/maintenance', dependencies.maintenanceRouter);
  app.use('/health', healthRouter);

  app.use(
    (
      error: unknown,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      res.locals.errorCategory = 'unhandled';
      console.error('Unhandled API error', error instanceof Error ? error.name : 'unknown');
      res.status(500).json({
        error: 'Unable to complete the administrator request.',
      });
    },
  );

  return app;
}
