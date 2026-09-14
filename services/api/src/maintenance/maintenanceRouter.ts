import { timingSafeEqual } from 'node:crypto';
import { Router } from 'express';

import type { CleanupResult } from './rejectedPostCleanup.js';

export type MaintenanceRouterDependencies = {
  cronSecret: string;
  runRejectedPostCleanup: () => Promise<CleanupResult>;
};

function secretMatches(header: string | undefined, expected: string) {
  const supplied = header?.startsWith('Bearer ') ? header.slice(7).trim() : '';
  const left = Buffer.from(supplied);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

export function createMaintenanceRouter(dependencies: MaintenanceRouterDependencies) {
  const router = Router();

  router.get('/rejected-posts', async (req, res) => {
    if (!secretMatches(req.header('authorization'), dependencies.cronSecret)) {
      return res.status(401).json({ error: 'Maintenance authorization required.' });
    }
    try {
      return res.json(await dependencies.runRejectedPostCleanup());
    } catch {
      return res.status(500).json({ error: 'Maintenance could not be completed.' });
    }
  });

  return router;
}
