import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';

import { createMaintenanceRouter } from './maintenanceRouter.js';

test('cleanup endpoint requires the exact Cron bearer secret', async () => {
  const secret = 'c'.repeat(32);
  const app = express().use('/maintenance', createMaintenanceRouter({
    cronSecret: secret,
    runRejectedPostCleanup: async () => ({ processed: 1, deleted: 1, skipped: 0, failed: 0 }),
  }));

  assert.equal((await request(app).get('/maintenance/rejected-posts')).status, 401);
  assert.equal((await request(app).get('/maintenance/rejected-posts').set('Authorization', 'Bearer wrong')).status, 401);
  const accepted = await request(app)
    .get('/maintenance/rejected-posts')
    .set('Authorization', `Bearer ${secret}`);
  assert.equal(accepted.status, 200);
  assert.deepEqual(accepted.body, { processed: 1, deleted: 1, skipped: 0, failed: 0 });
});
