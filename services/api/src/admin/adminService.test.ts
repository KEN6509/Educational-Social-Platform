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
import {
  AdminNotFoundError,
  AdminValidationError,
  type AdminRepository,
  type PageResult,
  type UserSummaryView,
} from './adminTypes.js';

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
    listUsers: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getUserDetail: async () => null,
    setUserAccountStatus: async () => undefined,
    setUserCreatorStatus: async () => undefined,
    listCreatorRequests: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getCreatorRequestDetail: async () => null,
    decideCreatorRequest: async () => undefined,
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

test('user listing trims search before delegating to the repository', async () => {
  let receivedSearch = '';
  const result: PageResult<UserSummaryView> = {
    items: [],
    page: 1,
    pageSize: 20,
    total: 0,
  };
  const repository = {
    ...createRepository(),
    listUsers: async (query: { search: string }) => {
      receivedSearch = query.search;
      return result;
    },
  } as unknown as AdminRepository;

  const service = createAdminService(repository, 3, {
    id: 'admin-id',
    email: 'admin@cyanzone.test',
  });

  assert.equal(
    await service.listUsers({
      page: 1,
      pageSize: 20,
      search: '  cyan member  ',
      accountStatus: undefined,
      creator: 'all',
    }),
    result,
  );
  assert.equal(receivedSearch, 'cyan member');
});

test('missing user detail becomes a typed not-found error', async () => {
  const repository = {
    ...createRepository(),
    getUserDetail: async () => null,
  } as unknown as AdminRepository;
  const service = createAdminService(repository, 3, {
    id: 'admin-id',
    email: 'admin@cyanzone.test',
  });

  await assert.rejects(
    () => service.getUser('missing-user'),
    AdminNotFoundError,
  );
});

test('administrators cannot suspend their own account', async () => {
  let repositoryCalled = false;
  const repository = {
    ...createRepository(),
    setUserAccountStatus: async () => {
      repositoryCalled = true;
    },
  } as unknown as AdminRepository;
  const service = createAdminService(repository, 3, {
    id: 'admin-id',
    email: 'admin@cyanzone.test',
  });

  await assert.rejects(
    () =>
      service.setUserAccountStatus('admin-id', {
        status: 'suspended',
        reason: 'This action must never reach the repository.',
      }),
    AdminValidationError,
  );
  assert.equal(repositoryCalled, false);
});

test('creator-request decisions delegate only validated domain values', async () => {
  let received:
    | {
        requestId: string;
        decision: string;
        reason: string;
      }
    | undefined;
  const repository = {
    ...createRepository(),
    decideCreatorRequest: async (
      requestId: string,
      input: { decision: string; reason: string },
    ) => {
      received = { requestId, ...input };
    },
  } as unknown as AdminRepository;
  const service = createAdminService(repository, 3, {
    id: 'admin-id',
    email: 'admin@cyanzone.test',
  });

  await service.decideCreatorRequest('request-1', {
    decision: 'approved',
    reason: 'Consistently helpful educational contributions.',
  });

  assert.deepEqual(received, {
    requestId: 'request-1',
    decision: 'approved',
    reason: 'Consistently helpful educational contributions.',
  });
});
