import { Router, type Router as ExpressRouter } from 'express';
import { type z } from 'zod';

import {
  requireAdministrator,
  type VerifyAdmin,
} from '../admin/adminAuth.js';
import { bootstrapSchema } from './adminSchema.js';

export type CreateAdministratorInput = z.infer<typeof bootstrapSchema>;

export type AdminRouterDependencies = {
  bootstrapSecret: string;
  countAdministrators: () => Promise<number>;
  createAdministrator: (
    input: CreateAdministratorInput,
  ) => Promise<{ id: string }>;
  upsertAdministratorProfile: (
    input: CreateAdministratorInput & { id: string },
  ) => Promise<void>;
  protectedAdminRouter: ExpressRouter;
  verifyAdmin: VerifyAdmin;
};

export class AdminBootstrapError extends Error {
  constructor(
    public readonly status: 400 | 500,
    message: string,
  ) {
    super(message);
    this.name = 'AdminBootstrapError';
  }
}

export function createAdminRouter(dependencies: AdminRouterDependencies) {
  const adminRouter = Router();

  adminRouter.post('/bootstrap', async (req, res) => {
    const providedSecret = req.header('x-bootstrap-secret');

    if (providedSecret !== dependencies.bootstrapSecret) {
      return res.status(401).json({ error: 'Invalid bootstrap secret.' });
    }

    const parsed = bootstrapSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Invalid request body.',
        details: parsed.error.flatten().fieldErrors,
      });
    }

    try {
      const administratorCount = await dependencies.countAdministrators();

      if (administratorCount > 0) {
        return res.status(409).json({
          error: 'An admin user already exists. Bootstrap is disabled.',
        });
      }

      const createdAdministrator =
        await dependencies.createAdministrator(parsed.data);

      await dependencies.upsertAdministratorProfile({
        ...parsed.data,
        id: createdAdministrator.id,
      });

      return res.status(201).json({
        userId: createdAdministrator.id,
        email: parsed.data.email,
        isAdmin: true,
      });
    } catch (error) {
      if (error instanceof AdminBootstrapError) {
        return res.status(error.status).json({ error: error.message });
      }

      return res.status(500).json({
        error: 'Unable to create admin user.',
      });
    }
  });

  adminRouter.use(
    requireAdministrator(dependencies.verifyAdmin),
    dependencies.protectedAdminRouter,
  );

  return adminRouter;
}
