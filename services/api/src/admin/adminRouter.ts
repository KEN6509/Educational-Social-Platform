import { Router, type Request, type Response } from 'express';

import type { AdminIdentity } from './adminAuth.js';
import {
  appealDecisionSchema,
  appealListQuerySchema,
  creatorRequestDecisionSchema,
  creatorRequestListQuerySchema,
  reportCaseListQuerySchema,
  reportDecisionSchema,
  reportTargetTypeSchema,
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

  router.get('/users/:userId/posts', async (req, res) => {
    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.listUserPosts(req.params.userId));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.get('/posts/:postId', async (req, res) => {
    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.getPost(req.params.postId));
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

  router.get('/report-cases', async (req, res) => {
    const parsed = reportCaseListQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid report filters.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.listReportCases(parsed.data));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.get('/report-cases/:targetType/:targetId', async (req, res) => {
    const targetType = reportTargetTypeSchema.safeParse(
      req.params.targetType,
    );
    if (!targetType.success) {
      return res.status(400).json({ error: 'Invalid report target.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(
        await service.getReportCase(
          targetType.data,
          req.params.targetId,
        ),
      );
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.post(
    '/report-cases/:targetType/:targetId/decision',
    async (req, res) => {
      const targetType = reportTargetTypeSchema.safeParse(
        req.params.targetType,
      );
      const decision = reportDecisionSchema.safeParse(req.body);
      if (!targetType.success || !decision.success) {
        return res.status(400).json({ error: 'Invalid report decision.' });
      }

      try {
        const service = dependencies.createService(
          getRequestContext(req),
        );
        await service.decideReportCase(
          targetType.data,
          req.params.targetId,
          decision.data,
        );
        return res.status(204).send();
      } catch (error) {
        return sendAdminError(res, error);
      }
    },
  );

  router.get('/appeals', async (req, res) => {
    const parsed = appealListQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid appeal filters.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.listAppeals(parsed.data));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.get('/appeals/:appealId', async (req, res) => {
    try {
      const service = dependencies.createService(getRequestContext(req));
      return res.json(await service.getAppeal(req.params.appealId));
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  router.post('/appeals/:appealId/decision', async (req, res) => {
    const parsed = appealDecisionSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Invalid appeal decision.' });
    }

    try {
      const service = dependencies.createService(getRequestContext(req));
      await service.decideAppeal(req.params.appealId, parsed.data);
      return res.status(204).send();
    } catch (error) {
      return sendAdminError(res, error);
    }
  });

  return router;
}
