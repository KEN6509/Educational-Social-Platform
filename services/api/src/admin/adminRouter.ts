import { Router, type Request, type Response } from 'express';

import type { AdminIdentity } from './adminAuth.js';
import {
  creatorRequestDecisionSchema,
  creatorRequestListQuerySchema,
  userAccountStatusSchema,
  userCreatorStatusSchema,
  userListQuerySchema,
} from './adminSchemas.js';
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

  router.get('/users', async (req, res) => {
    const parsed = userListQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid user filters.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.listUsers(parsed.data));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.get('/users/:userId', async (req, res) => {
    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.getUser(req.params.userId));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.post('/users/:userId/account-status', async (req, res) => {
    const parsed = userAccountStatusSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid account decision.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      await service.setUserAccountStatus(req.params.userId, parsed.data);
      return res.status(204).send();
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.post('/users/:userId/creator-status', async (req, res) => {
    const parsed = userCreatorStatusSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid creator decision.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      await service.setUserCreatorStatus(req.params.userId, parsed.data);
      return res.status(204).send();
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.get('/creator-requests', async (req, res) => {
    const parsed = creatorRequestListQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Invalid creator request filters.',
      });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.listCreatorRequests(parsed.data));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.get('/creator-requests/:requestId', async (req, res) => {
    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(
        await service.getCreatorRequest(req.params.requestId),
      );
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.post('/creator-requests/:requestId/decision', async (req, res) => {
    const parsed = creatorRequestDecisionSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({
        error: 'Invalid creator request decision.',
      });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      await service.decideCreatorRequest(req.params.requestId, parsed.data);
      return res.status(204).send();
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  return router;
}
