import assert from 'node:assert/strict';
import test from 'node:test';

import request from 'supertest';

import { createApp, type AppDependencies } from '../app.js';
import {
  AdminConflictError,
  AdminNotFoundError,
  AdminValidationError,
  type OverviewView,
} from './adminTypes.js';
import { createProtectedAdminRouter } from './adminRouter.js';

const expectedOverview: OverviewView = {
  pendingCreatorRequests: 2,
  pendingReportCases: 1,
  pendingAppeals: 3,
  recentDecisions: [],
};

function createDependencies(
  getOverview: () => Promise<OverviewView>,
): AppDependencies {
  return {
    bootstrapSecret: 'a'.repeat(24),
    countAdministrators: async () => 0,
    createAdministrator: async () => ({ id: 'created-admin' }),
    upsertAdministratorProfile: async () => undefined,
    protectedAdminRouter: createProtectedAdminRouter({
      createService: () => ({ getOverview }),
    }),
    verifyAdmin: async () => ({
      id: 'admin-id',
      email: 'admin@cyanzone.test',
    }),
  };
}

test('returns the protected administrator overview', async () => {
  const response = await request(
    createApp(createDependencies(async () => expectedOverview)),
  )
    .get('/admin/overview')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, expectedOverview);
});

test('maps typed administrator errors to stable HTTP statuses', async () => {
  const scenarios = [
    [new AdminValidationError('Invalid request.'), 400],
    [new AdminNotFoundError('Missing record.'), 404],
    [new AdminConflictError('Record changed.'), 409],
  ] as const;

  for (const [error, expectedStatus] of scenarios) {
    const response = await request(
      createApp(
        createDependencies(async () => {
          throw error;
        }),
      ),
    )
      .get('/admin/overview')
      .set('Authorization', 'Bearer valid-token');

    assert.equal(response.status, expectedStatus);
    assert.equal(response.body.error, error.message);
  }
});

test('replaces unknown overview failures with a safe message', async () => {
  const response = await request(
    createApp(
      createDependencies(async () => {
        throw new Error('Database internals must remain private.');
      }),
    ),
  )
    .get('/admin/overview')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(response.status, 500);
  assert.deepEqual(response.body, {
    error: 'Unable to complete the administrator request.',
  });
});
