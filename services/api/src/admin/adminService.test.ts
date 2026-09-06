import assert from 'node:assert/strict';
import test from 'node:test';

import {
  accountStatusSchema,
  appealStatusSchema,
  creatorRequestStatusSchema,
  pageSchema,
  reportDecisionSchema,
  reportCaseListQuerySchema,
  reportStatusSchema,
  userCreatorStatusSchema,
} from './adminSchemas.js';
import { createAdminService } from './adminService.js';
import {
  AdminNotFoundError,
  AdminValidationError,
  type AdminRepository,
  type PageResult,
  type ReportCaseDecisionInput,
  type ReportCaseRow,
  type UserCreatorStatusInput,
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
    listUserPublishedPosts: async () => [],
    getPostDetail: async () => null,
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
    getReportCaseRows: async () => [],
    getReportCaseDetail: async () => null,
    decideReportCase: async () => undefined,
    listAppeals: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getAppealDetail: async () => null,
    decideAppeal: async () => undefined,
    listModerationCases: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getModerationCase: async () => null,
    decideModerationCase: async () => undefined,
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
  assert.equal(reportStatusSchema.safeParse('pending_review').success, true);
  assert.equal(reportStatusSchema.safeParse('open').success, false);
  assert.equal(reportStatusSchema.safeParse('reviewing').success, false);
  assert.equal(reportCaseListQuerySchema.parse({}).status, 'pending_review');
  assert.equal(appealStatusSchema.safeParse('dismissed').success, false);
});

test('creator and report decisions require reasons only for punitive actions', () => {
  assert.deepEqual(userCreatorStatusSchema.parse({ isCreator: true }), {
    isCreator: true,
    reason: '',
  });
  assert.equal(
    userCreatorStatusSchema.safeParse({ isCreator: false, reason: '' })
      .success,
    false,
  );
  assert.equal(
    userCreatorStatusSchema.safeParse({ isCreator: true, reason: 'short' })
      .success,
    false,
  );
  assert.deepEqual(reportDecisionSchema.parse({ decision: 'retain' }), {
    decision: 'retain',
    reason: '',
  });
  assert.equal(
    reportDecisionSchema.safeParse({ decision: 'remove', reason: 'short' })
      .success,
    false,
  );
  assert.equal(
    reportDecisionSchema.safeParse({
      decision: 'remove',
      reason: 'The reported content violates the community rules.',
    }).success,
    true,
  );
});

test('reason-free positive decisions receive stable internal audit reasons', async () => {
  const creatorInputs: UserCreatorStatusInput[] = [];
  const reportInputs: ReportCaseDecisionInput[] = [];
  const repository = createRepository({
    setUserCreatorStatus: async (_userId, input) => {
      creatorInputs.push(input);
    },
    decideReportCase: async (_targetType, _targetId, input) => {
      reportInputs.push(input);
    },
  });
  const service = createAdminService(repository, 1);

  await service.setUserCreatorStatus('user-1', {
    isCreator: true,
    reason: '',
  });
  await service.decideReportCase('post', 'post-1', {
    decision: 'retain',
    reason: '',
  });

  assert.equal(
    creatorInputs[0]?.reason,
    'Creator status assigned by an administrator.',
  );
  assert.equal(
    reportInputs[0]?.reason,
    'Reported content retained by an administrator.',
  );
});

test('punitive decision reasons are trimmed and preserved', async () => {
  const creatorInputs: UserCreatorStatusInput[] = [];
  const reportInputs: ReportCaseDecisionInput[] = [];
  const repository = createRepository({
    setUserCreatorStatus: async (_userId, input) => {
      creatorInputs.push(input);
    },
    decideReportCase: async (_targetType, _targetId, input) => {
      reportInputs.push(input);
    },
  });
  const service = createAdminService(repository, 1);

  await service.setUserCreatorStatus('user-1', {
    isCreator: false,
    reason: '  Creator standards were repeatedly breached.  ',
  });
  await service.decideReportCase('post', 'post-1', {
    decision: 'remove',
    reason: '  The reported content violates community rules.  ',
  });

  assert.equal(
    creatorInputs[0]?.reason,
    'Creator standards were repeatedly breached.',
  );
  assert.equal(
    reportInputs[0]?.reason,
    'The reported content violates community rules.',
  );
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
          status: 'pending_review',
        },
        {
          targetType: 'post',
          targetId: 'post-ready',
          reporterId: 'reporter-2',
          status: 'pending_review',
        },
        {
          targetType: 'post',
          targetId: 'post-ready',
          reporterId: 'reporter-3',
          status: 'pending_review',
        },
        {
          targetType: 'comment',
          targetId: 'comment-below-threshold',
          reporterId: 'reporter-1',
          status: 'pending_review',
        },
        {
          targetType: 'comment',
          targetId: 'comment-below-threshold',
          reporterId: 'reporter-2',
          status: 'pending_review',
        },
        {
          targetType: 'post',
          targetId: 'post-reviewing',
          reporterId: 'reporter-1',
          status: 'resolved',
        },
        {
          targetType: 'post',
          targetId: 'post-reviewing',
          reporterId: 'reporter-2',
          status: 'resolved',
        },
        {
          targetType: 'post',
          targetId: 'post-reviewing',
          reporterId: 'reporter-3',
          status: 'resolved',
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
          status: 'pending_review',
        },
        {
          targetType: 'post',
          targetId: 'post-1',
          reporterId: 'same-reporter',
          status: 'pending_review',
        },
        {
          targetType: 'post',
          targetId: 'post-1',
          reporterId: null,
          status: 'pending_review',
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

test('post review services expose published posts and reject missing details', async () => {
  const postSummary = {
    id: 'post-1',
    title: 'Repair guide',
    content: 'Full guide',
    tags: ['Technology'],
    moderationStatus: 'approved',
    publishedAt: '2026-07-31T00:00:00.000Z',
    createdAt: '2026-07-30T00:00:00.000Z',
    coverImageUrl: 'https://img/cover.jpg',
    imageCount: 1,
    commentCount: 2,
  };
  const postDetail = {
    ...postSummary,
    authorId: 'creator-1',
    authorName: 'Ken',
    authorAvatarUrl: null,
    images: [{ url: 'https://img/cover.jpg', position: 1 }],
    comments: [],
  };
  const service = createAdminService(
    createRepository({
      getUserDetail: async () => ({
        id: 'user-1',
        name: 'Ken',
        email: 'ken@cyanzone.test',
        avatarUrl: null,
        bio: null,
        isContentCreator: true,
        isAdmin: false,
        accountStatus: 'active',
        createdAt: '2026-07-01T00:00:00.000Z',
        emailVerified: true,
        publishedPostCount: 1,
        recentPosts: [postSummary],
        recentDecisions: [],
      }),
      listUserPublishedPosts: async () => [postSummary],
      getPostDetail: async (postId: string) =>
        postId === 'missing' ? null : postDetail,
    }),
    1,
  );

  assert.equal((await service.listUserPosts('user-1')).length, 1);
  assert.equal((await service.getPost('post-1')).id, 'post-1');
  await assert.rejects(() => service.getPost('missing'), AdminNotFoundError);
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

test('report cases group raw rows by target and apply the unique-reporter threshold', async () => {
  const rows: ReportCaseRow[] = [];
  for (let index = 1; index <= 7; index += 1) {
    rows.push({
      id: `report-post-${index}`,
      targetType: 'post',
      targetId: 'post-ready',
      reporterId: `reporter-${index}`,
      reason: index <= 4 ? 'Harassment' : 'Hate speech',
      status: 'pending_review',
      reviewedBy: null,
      reviewedAt: null,
      resolutionNote: null,
      createdAt: `2026-07-${String(index).padStart(2, '0')}T00:00:00.000Z`,
      targetTitle: 'Reported post',
      targetExcerpt: 'Post context',
      ownerName: 'Post Owner',
    });
  }
  for (let index = 1; index <= 2; index += 1) {
    rows.push({
      ...rows[0]!,
      id: `report-below-${index}`,
      targetId: 'post-below',
      reporterId: `below-reporter-${index}`,
    });
  }
  for (let index = 1; index <= 3; index += 1) {
    rows.push({
      ...rows[0]!,
      id: `report-comment-${index}`,
      targetType: 'comment',
      targetId: 'comment-ready',
      reporterId: `comment-reporter-${index}`,
      targetTitle: null,
      targetExcerpt: 'Reported comment',
    });
  }

  const repository = {
    ...createRepository(),
    getReportCaseRows: async () => rows,
  } as unknown as AdminRepository;
  const service = createAdminService(repository, 3, {
    id: 'admin-id',
    email: 'admin@cyanzone.test',
  });

  const result = await service.listReportCases({
    page: 1,
    pageSize: 20,
    search: '',
    status: 'pending_review',
    targetType: undefined,
  });

  assert.equal(result.total, 2);
  assert.deepEqual(
    result.items.map((item) => [item.targetId, item.uniqueReporters]),
    [
      ['post-ready', 7],
      ['comment-ready', 3],
    ],
  );
  assert.deepEqual(result.items[0]?.reasonCounts, [
    { reason: 'Harassment', count: 4 },
    { reason: 'Hate speech', count: 3 },
  ]);
  assert.equal(result.items[0]?.totalReports, 7);
  assert.equal(result.items[1]?.totalReports, 3);
});

test('threshold one exposes a genuine single-reporter case', async () => {
  const row: ReportCaseRow = {
    id: 'report-1',
    targetType: 'post',
    targetId: 'post-1',
    reporterId: 'reporter-1',
    reason: 'Spam',
    status: 'pending_review',
    reviewedBy: null,
    reviewedAt: null,
    resolutionNote: null,
    createdAt: '2026-07-31T00:00:00.000Z',
    targetTitle: 'Reported post',
    targetExcerpt: 'Repeated promotion',
    ownerName: 'Owner',
  };
  const service = createAdminService(
    createRepository({ getReportCaseRows: async () => [row] }),
    1,
  );

  const result = await service.listReportCases({
    page: 1,
    pageSize: 20,
    search: '',
    status: 'pending_review',
    targetType: undefined,
  });

  assert.equal(result.total, 1);
  assert.equal(result.items[0]?.totalReports, 1);
});

test('missing appeal detail becomes a typed not-found error', async () => {
  const repository = {
    ...createRepository(),
    getAppealDetail: async () => null,
  } as unknown as AdminRepository;
  const service = createAdminService(repository, 3, {
    id: 'admin-id',
    email: 'admin@cyanzone.test',
  });

  await assert.rejects(
    () => service.getAppeal('missing-appeal'),
    AdminNotFoundError,
  );
});
