import assert from 'node:assert/strict';
import test from 'node:test';

import request from 'supertest';

import { createApp, type AppDependencies } from '../app.js';
import {
  AdminConflictError,
  AdminNotFoundError,
  AdminValidationError,
  type AdminService,
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
  overrides: Partial<AdminService> = {},
): AppDependencies {
  const service: AdminService = {
    getOverview,
    listUsers: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getUser: async () => {
      throw new AdminNotFoundError('User not found.');
    },
    listUserPosts: async () => [],
    getPost: async () => {
      throw new AdminNotFoundError('Post not found.');
    },
    setUserAccountStatus: async () => undefined,
    setUserCreatorStatus: async () => undefined,
    listCreatorRequests: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getCreatorRequest: async () => {
      throw new AdminNotFoundError('Creator request not found.');
    },
    decideCreatorRequest: async () => undefined,
    listReportCases: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getReportCase: async () => {
      throw new AdminNotFoundError('Report case not found.');
    },
    decideReportCase: async () => undefined,
    listAppeals: async (query) => ({
      items: [],
      page: query.page,
      pageSize: query.pageSize,
      total: 0,
    }),
    getAppeal: async () => {
      throw new AdminNotFoundError('Appeal not found.');
    },
    decideAppeal: async () => undefined,
    ...overrides,
  };

  return {
    bootstrapSecret: 'a'.repeat(24),
    countAdministrators: async () => 0,
    createAdministrator: async () => ({ id: 'created-admin' }),
    upsertAdministratorProfile: async () => undefined,
    protectedAdminRouter: createProtectedAdminRouter({
      createService: () => service,
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

test('validates and returns the paginated users endpoint', async () => {
  const dependencies = createDependencies(
    async () => expectedOverview,
    {
      listUsers: async (query) => ({
          items: [
            {
              id: 'user-1',
              name: 'Cyan Member',
              email: 'member@cyanzone.test',
              avatarUrl: null,
              bio: null,
              isContentCreator: false,
              isAdmin: false,
              accountStatus: 'active',
              createdAt: '2026-07-31T00:00:00.000Z',
            },
          ],
          page: query.page,
          pageSize: query.pageSize,
          total: 1,
        }),
    },
  );

  const response = await request(createApp(dependencies))
    .get('/admin/users?search=cyan&page=1&pageSize=20')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(response.status, 200);
  assert.equal(response.body.total, 1);
  assert.equal(response.body.items[0].email, 'member@cyanzone.test');
});

test('returns published user posts and complete post details', async () => {
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
    commentCount: 1,
  };
  const postDetail = {
    ...postSummary,
    authorId: 'creator-1',
    authorName: 'Ken',
    authorAvatarUrl: null,
    images: [{ url: 'https://img/cover.jpg', position: 1 }],
    comments: [
      {
        id: 'comment-1',
        authorId: 'member-1',
        authorName: 'Member',
        authorAvatarUrl: null,
        isCreator: false,
        content: 'Helpful',
        createdAt: '2026-07-31T01:00:00.000Z',
        likeCount: 2,
        replies: [],
      },
    ],
  };
  const dependencies = createDependencies(
    async () => expectedOverview,
    {
      listUserPosts: async () => [postSummary],
      getPost: async () => postDetail,
    },
  );

  const posts = await request(createApp(dependencies))
    .get('/admin/users/user-1/posts')
    .set('Authorization', 'Bearer valid-token');
  const detail = await request(createApp(dependencies))
    .get('/admin/posts/post-1')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(posts.status, 200);
  assert.equal(posts.body[0].id, 'post-1');
  assert.equal(detail.status, 200);
  assert.equal(detail.body.comments[0].content, 'Helpful');
});

test('rejects short reasons before changing account status', async () => {
  let decisionCalled = false;
  const dependencies = createDependencies(
    async () => expectedOverview,
    {
      setUserAccountStatus: async () => {
          decisionCalled = true;
        },
    },
  );

  const response = await request(createApp(dependencies))
    .post('/admin/users/user-1/account-status')
    .set('Authorization', 'Bearer valid-token')
    .send({ status: 'suspended', reason: 'short' });

  assert.equal(response.status, 400);
  assert.equal(decisionCalled, false);
});

test('returns grouped report cases from the protected endpoint', async () => {
  const dependencies = createDependencies(
    async () => expectedOverview,
    {
      listReportCases: async (query) => ({
        items: [
          {
            targetType: 'post',
            targetId: 'post-1',
            targetTitle: 'Reported post',
            targetExcerpt: 'Context',
            ownerName: 'Owner',
            status: 'pending_review',
            totalReports: 7,
            uniqueReporters: 7,
            reasonCounts: [{ reason: 'Harassment', count: 7 }],
            latestReportedAt: '2026-07-31T00:00:00.000Z',
          },
        ],
        page: query.page,
        pageSize: query.pageSize,
        total: 1,
      }),
    },
  );

  const response = await request(createApp(dependencies))
    .get('/admin/report-cases?status=pending_review&page=1&pageSize=20')
    .set('Authorization', 'Bearer valid-token');

  assert.equal(response.status, 200);
  assert.equal(response.body.items[0].uniqueReporters, 7);
});
