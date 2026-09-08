import assert from 'node:assert/strict';
import test from 'node:test';

import { Router } from 'express';
import request from 'supertest';

import { createApp, type AppDependencies } from '../createApp.js';
import {
  AdminAuthorizationError,
  createVerifyAdmin,
} from './adminAuth.js';

function createTestDependencies(
  verifyAdmin: AppDependencies['verifyAdmin'],
): AppDependencies {
  const protectedAdminRouter = Router();
  protectedAdminRouter.get('/overview', (_req, res) => {
    res.json({ admin: res.locals.admin });
  });

  return {
    bootstrapSecret: 'a'.repeat(24),
    countAdministrators: async () => 0,
    createAdministrator: async () => ({ id: 'created-admin' }),
    upsertAdministratorProfile: async () => undefined,
    protectedAdminRouter,
    moderationRouter: Router(),
    verifyAdmin,
  };
}

test('rejects protected administrator requests without a bearer token', async () => {
  const response = await request(
    createApp(
      createTestDependencies(async () => ({
        id: 'admin-id',
        email: 'admin@cyanzone.test',
      })),
    ),
  ).get('/admin/overview');

  assert.equal(response.status, 401);
  assert.deepEqual(response.body, {
    error: 'Administrator session required.',
  });
});

test('passes the verified administrator to protected routes', async () => {
  const response = await request(
    createApp(
      createTestDependencies(async (token) => {
        assert.equal(token, 'valid-token');
        return {
          id: 'admin-id',
          email: 'admin@cyanzone.test',
        };
      }),
    ),
  )
    .get('/admin/overview')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, {
    admin: {
      id: 'admin-id',
      email: 'admin@cyanzone.test',
    },
  });
});

test('returns forbidden when the verified profile is not an active administrator', async () => {
  const verifyAdmin = createVerifyAdmin({
    getUser: async () => ({
      id: 'normal-user',
      email: 'member@cyanzone.test',
    }),
    getProfile: async () => ({
      id: 'normal-user',
      email: 'member@cyanzone.test',
      isAdmin: false,
      accountStatus: 'active',
    }),
  });

  const response = await request(
    createApp(createTestDependencies(verifyAdmin)),
  )
    .get('/admin/overview')
    .set('Authorization', 'Bearer member-token');

  assert.equal(response.status, 403);
  assert.deepEqual(response.body, {
    error: 'Active administrator access required.',
  });
});

test('classifies missing or expired sessions as unauthenticated', async () => {
  const verifyAdmin = createVerifyAdmin({
    getUser: async () => null,
    getProfile: async () => {
      throw new Error('Profile lookup must not run without a user.');
    },
  });

  await assert.rejects(
    () => verifyAdmin('expired-token'),
    (error: unknown) =>
      error instanceof AdminAuthorizationError && error.status === 401,
  );
});
