import { timingSafeEqual } from 'node:crypto';
import { Router, type Request, type Response } from 'express';

import {
  requireMember,
  type MemberIdentity,
  type VerifyMember,
} from '../moderation/moderationAuth.js';
import {
  PushServiceError,
  type PushService,
} from './pushService.js';

export type PushRouterDependencies = {
  verifyMember: VerifyMember;
  service: PushService;
  webhookSecret: string;
};

export function createPushRouter(dependencies: PushRouterDependencies) {
  const router = Router();
  const memberRouter = Router();
  memberRouter.use(requireMember(dependencies.verifyMember));

  memberRouter.put('/devices', async (req, res) => {
    const member = res.locals.member as MemberIdentity;
    const deviceId = boundedString(req.body?.deviceId, 8, 160);
    const token = boundedString(req.body?.token, 20, 4096);
    const enabled = req.body?.enabled;
    if (!deviceId || !token || typeof enabled !== 'boolean') {
      res.status(400).json({error: 'A valid Android device ID and token are required.'});
      return;
    }
    try {
      await dependencies.service.registerDevice(
        member.id,
        deviceId,
        token,
        enabled,
      );
      res.status(204).send();
    } catch (error) {
      handleError(res, error, 'Unable to register push device.');
    }
  });

  memberRouter.delete('/devices/:deviceId', async (req, res) => {
    const member = res.locals.member as MemberIdentity;
    const deviceId = boundedString(req.params.deviceId, 8, 160);
    if (!deviceId) {
      res.status(400).json({error: 'A valid device ID is required.'});
      return;
    }
    try {
      await dependencies.service.deactivateDevice(member.id, deviceId);
      res.status(204).send();
    } catch (error) {
      handleError(res, error, 'Unable to deactivate push device.');
    }
  });

  memberRouter.get('/events/:sourceTable/:sourceId', async (req, res) => {
    const member = res.locals.member as MemberIdentity;
    try {
      const resolved = await dependencies.service.resolveDestination(
        member.id,
        req.params.sourceTable as 'notifications' | 'supervision_notifications',
        req.params.sourceId,
      );
      res.status(200).json(resolved);
    } catch (error) {
      handleError(res, error, 'Push source is no longer available.');
    }
  });

  router.post('/events', async (req, res) => {
    if (!hasSecret(req, dependencies.webhookSecret)) {
      res.status(401).json({error: 'Webhook authentication failed.'});
      return;
    }
    try {
      const result = await dependencies.service.processEvent(req.body);
      res.status(200).json(result);
    } catch (error) {
      handleError(res, error, 'Unable to process push event.');
    }
  });
  router.use(memberRouter);

  return router;
}

function hasSecret(req: Request, expectedSecret: string) {
  const provided = Buffer.from(req.header('x-cyanzone-webhook-secret') ?? '');
  const expected = Buffer.from(expectedSecret);
  return provided.length === expected.length && timingSafeEqual(provided, expected);
}

function boundedString(value: unknown, min: number, max: number): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length >= min && trimmed.length <= max ? trimmed : null;
}

function handleError(res: Response, error: unknown, fallback: string) {
  if (error instanceof PushServiceError) {
    res.status(error.status).json({error: error.message});
    return;
  }
  console.error('Push operation failed', error);
  res.status(500).json({error: fallback});
}
