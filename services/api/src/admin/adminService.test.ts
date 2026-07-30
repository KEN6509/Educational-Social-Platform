import assert from 'node:assert/strict';
import test from 'node:test';

import {
  accountStatusSchema,
  appealStatusSchema,
  creatorRequestStatusSchema,
  pageSchema,
  reportStatusSchema,
} from './adminSchemas.js';
import { createAdminService } from './adminService.js';
import type { AdminRepository } from './adminTypes.js';

function createRepository(
  overrides: Partial<AdminRepository> = {},
): AdminRepository {
  return {
    getOverviewSnapshot: async () => ({
      pendingCreatorRequests: 2,
      pendingAppeals: 3,
      reportRows: [],
      recentAuditRows: [],
    }),
    ...overrides,
  };
}

test('page schema applies defaults and rejects sizes outside 1 through 50', () => {
  assert.deepEqual(pageSchema.parse({}), {
    page: 1,
    pageSize: 20,
  });
  assert.equal(pageSchema.safeParse({ pageSize: 0 }).success, false);
  assert.equal(pageSchema.safeParse({ pageSize: 51 }).success, false);
});

test('status schemas reject values outside their stored state contracts', () => {
  assert.equal(accountStatusSchema.safeParse('deleted').success, false);
  assert.equal(creatorRequestStatusSchema.safeParse('reviewing').success, false);
  assert.equal(reportStatusSchema.safeParse('pending').success, false);
  assert.equal(appealStatusSchema.safeParse('dismissed').success, false);
});

test('overview counts grouped report targets meeting three unique reporters', async () => {
  const repository = createRepository({
    getOverviewSnapshot: async () => ({
      pendingCreatorRequests: 2,
      pendingAppeals: 3,
      reportRows: [
        {
          targetType: 'post',
          targetId: 'post-ready',
          reporterId: 'reporter-1',
          status: 'open',
        },
        {
          targetType: 'post',
          targetId: 'post-ready',
          reporterId: 'reporter-2',
          status: 'open',
        },
        {
          targetType: 'post',
          targetId: 'post-ready',
          reporterId: 'reporter-3',
          status: 'open',
        },
        {
          targetType: 'comment',
          targetId: 'comment-below-threshold',
          reporterId: 'reporter-1',
          status: 'open',
        },
        {
          targetType: 'comment',
          targetId: 'comment-below-threshold',
          reporterId: 'reporter-2',
          status: 'open',
        },
        {
          targetType: 'post',
          targetId: 'post-reviewing',
          reporterId: 'reporter-1',
          status: 'reviewing',
        },
        {
          targetType: 'post',
          targetId: 'post-reviewing',
          reporterId: 'reporter-2',
          status: 'reviewing',
        },
        {
          targetType: 'post',
          targetId: 'post-reviewing',
          reporterId: 'reporter-3',
          status: 'reviewing',
        },
      ],
      recentAuditRows: [],
    }),
  });

  const service = createAdminService(repository, 3);

  assert.deepEqual(await service.getOverview(), {
    pendingCreatorRequests: 2,
    pendingReportCases: 1,
    pendingAppeals: 3,
    recentDecisions: [],
  });
});

test('overview deduplicates repeated report rows from the same reporter', async () => {
  const repository = createRepository({
    getOverviewSnapshot: async () => ({
      pendingCreatorRequests: 0,
      pendingAppeals: 0,
      reportRows: [
        {
          targetType: 'post',
          targetId: 'post-1',
          reporterId: 'same-reporter',
          status: 'open',
        },
        {
          targetType: 'post',
          targetId: 'post-1',
          reporterId: 'same-reporter',
          status: 'open',
        },
        {
          targetType: 'post',
          targetId: 'post-1',
          reporterId: null,
          status: 'open',
        },
      ],
      recentAuditRows: [],
    }),
  });

  const overview = await createAdminService(repository, 3).getOverview();

  assert.equal(overview.pendingReportCases, 0);
});

test('overview maps recent audit rows to safe view models', async () => {
  const repository = createRepository({
    getOverviewSnapshot: async () => ({
      pendingCreatorRequests: 0,
      pendingAppeals: 0,
      reportRows: [],
      recentAuditRows: [
        {
          id: 'audit-1',
          adminId: 'admin-1',
          adminEmail: 'admin@cyanzone.test',
          actionType: 'user_suspended',
          targetType: 'user',
          targetId: 'user-1',
          reason: 'Repeated harmful conduct.',
          createdAt: '2026-07-31T00:00:00.000Z',
        },
      ],
    }),
  });

  const overview = await createAdminService(repository, 3).getOverview();

  assert.equal(overview.recentDecisions[0]?.adminEmail, 'admin@cyanzone.test');
  assert.equal(overview.recentDecisions[0]?.targetId, 'user-1');
});
