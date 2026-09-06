import { Router, type Request, type Response } from 'express';
import {
  requireMember,
  type MemberIdentity,
  type VerifyMember,
} from './moderationAuth.js';
import {
  ModerationProviderFailureError,
  ModerationServiceError,
  type ModerationResponse,
  type ModerationService,
} from './moderationService.js';

export type ModerationRouterDependencies = {
  verifyMember: VerifyMember;
  service: ModerationService;
};

export function createModerationRouter(
  dependencies: ModerationRouterDependencies,
) {
  const router = Router();
  router.use(requireMember(dependencies.verifyMember));

  router.post('/posts/:postId', async (req, res) => {
    await handleModeration(req, res, dependencies.service, 'post', req.params.postId);
  });
  router.post('/comments/:commentId', async (req, res) => {
    await handleModeration(req, res, dependencies.service, 'comment', req.params.commentId);
  });

  return router;
}

async function handleModeration(
  _req: Request,
  res: Response,
  service: ModerationService,
  type: 'post' | 'comment',
  id: string,
): Promise<void> {
  const member = res.locals.member as MemberIdentity | undefined;
  if (!member) {
    res.status(401).json({ error: 'Member session required.' });
    return;
  }

  try {
    const result: ModerationResponse = await service.moderate(type, id, member);
    res.status(200).json(result);
  } catch (error) {
    if (error instanceof ModerationProviderFailureError) {
      res.status(error.status).json({
        error: error.message,
        retryAllowed: error.retryAllowed,
      });
      return;
    }
    if (error instanceof ModerationServiceError) {
      res.status(error.status).json({ error: error.message });
      return;
    }

    console.error('Unhandled moderation error', error);
    res.status(500).json({
      error: 'Unable to complete the moderation request.',
    });
  }
}
