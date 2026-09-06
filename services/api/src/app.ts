import cors from 'cors';
import express, { type Router } from 'express';
import helmet from 'helmet';

import type { VerifyAdmin } from './admin/adminAuth.js';
import {
  createAdminRouter,
  type CreateAdministratorInput,
} from './routes/admin.js';
import { healthRouter } from './routes/health.js';

export type AppDependencies = {
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
  verifyAdmin: VerifyAdmin;
};

export function createApp(dependencies: AppDependencies) {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '2mb' }));

  app.use('/admin', createAdminRouter(dependencies));
  app.use('/moderation', dependencies.moderationRouter);
  app.use('/health', healthRouter);

  app.use(
    (
      error: unknown,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      console.error('Unhandled API error', error);
      res.status(500).json({
        error: 'Unable to complete the administrator request.',
      });
    },
  );

  return app;
}
