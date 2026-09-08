import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';

import { createApp, type AppDependencies } from './createApp.js';

function dependencies(): AppDependencies {
  return {
    allowedOrigins: ['https://admin.cyanzone.test'],
    bootstrapSecret: 'test-bootstrap-secret',
    countAdministrators: async () => 1,
    createAdministrator: async () => ({ id: 'admin-1' }),
    upsertAdministratorProfile: async () => undefined,
    protectedAdminRouter: express.Router(),
    moderationRouter: express.Router(),
    verifyAdmin: async () => ({
      id: 'admin-1',
      email: 'admin@cyanzone.test',
    }),
  };
}

test('CORS exposes configured browser origins only', async () => {
  const app = createApp(dependencies());
  const allowed = await request(app)
    .get('/health')
    .set('Origin', 'https://admin.cyanzone.test');
  assert.equal(
    allowed.headers['access-control-allow-origin'],
    'https://admin.cyanzone.test',
  );

  const unknown = await request(app)
    .get('/health')
    .set('Origin', 'https://attacker.example');
  assert.equal(unknown.status, 200);
  assert.equal(unknown.headers['access-control-allow-origin'], undefined);
});

test('CORS permits native requests without an Origin header', async () => {
  const response = await request(createApp(dependencies())).get('/health');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
});
