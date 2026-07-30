import { Router, type Request, type Response } from 'express';

import type { AdminIdentity } from './adminAuth.js';
import type { AdminService } from './adminTypes.js';
import {
  AdminConflictError,
  AdminNotFoundError,
  AdminValidationError,
} from './adminTypes.js';

export type AdminRequestContext = {
  admin: AdminIdentity;
  accessToken: string;
};

export type ProtectedAdminRouterDependencies = {
  createService: (context: AdminRequestContext) => AdminService;
};

function sendAdminError(res: Response, error: unknown) {
  if (error instanceof AdminValidationError) {
    return res.status(400).json({ error: error.message });
  }
  if (error instanceof AdminNotFoundError) {
    return res.status(404).json({ error: error.message });
  }
  if (error instanceof AdminConflictError) {
    return res.status(409).json({ error: error.message });
  }

  return res.status(500).json({
    error: 'Unable to complete the administrator request.',
  });
}

function getRequestContext(req: Request): AdminRequestContext {
  return {
    admin: req.res?.locals.admin as AdminIdentity,
    accessToken: req.res?.locals.adminAccessToken as string,
  };
}

export function createProtectedAdminRouter(
  dependencies: ProtectedAdminRouterDependencies,
) {
  const router = Router();

  router.get('/overview', async (req, res) => {
    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.getOverview());
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  return router;
}
