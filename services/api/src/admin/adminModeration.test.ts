import assert from 'node:assert/strict';
import test from 'node:test';
import { Router } from 'express';
import request from 'supertest';
import { createApp, type AppDependencies } from '../app.js';
import { createProtectedAdminRouter } from './adminRouter.js';
import { createAdminRepository } from './adminRepository.js';
import { createAdminService } from './adminService.js';
import {
  AdminConflictError,
  AdminNotFoundError,
  type AdminRepository,
  type AiModerationCaseView,
  type AdminService,
} from './adminTypes.js';

const caseView: AiModerationCaseView = {
  id: 'case-1',
  targetType: 'post',
  targetId: 'post-1',
  moderationRevision: 1,
  authorName: 'Member',
  authorEmail: 'member@cyanzone.test',
  submittedAt: '2026-09-06T12:00:00.000Z',
  title: 'A post',
  content: 'Post content',
  imageUrls: ['https://project.supabase.co/images/a.jpg'],
  riskScore: 50,
  categoryScores: { hate: 50 },
  evidence: ['test evidence'],
  userReason: 'Needs review',
  model: 'gemini-3.8-flash',
  status: 'pending',
  decisionReason: null,
  decidedAt: null,
};

function baseRepository(overrides: Partial<AdminRepository> = {}): AdminRepository {
  return {
    getOverviewSnapshot: async () => ({
      pendingCreatorRequests: 0,
      pendingAppeals: 0,
      reportRows: [],
      recentAuditRows: [],
    }),
    listUsers: async () => ({ items: [], page: 1, pageSize: 20, total: 0 }),
    getUserDetail: async () => null,
    listUserPublishedPosts: async () => [],
    getPostDetail: async () => null,
    setUserAccountStatus: async () => undefined,
    setUserCreatorStatus: async () => undefined,
    listCreatorRequests: async () => ({ items: [], page: 1, pageSize: 20, total: 0 }),
    getCreatorRequestDetail: async () => null,
    decideCreatorRequest: async () => undefined,
    getReportCaseRows: async () => [],
    getReportCaseDetail: async () => null,
    decideReportCase: async () => undefined,
    listAppeals: async () => ({ items: [], page: 1, pageSize: 20, total: 0 }),
    getAppealDetail: async () => null,
    decideAppeal: async () => undefined,
    listModerationCases: async () => ({ items: [caseView], page: 1, pageSize: 20, total: 1 }),
    getModerationCase: async () => caseView,
    decideModerationCase: async () => undefined,
    ...overrides,
  };
}

function createAdminApp(service: AdminService) {
  const dependencies: AppDependencies = {
    bootstrapSecret: 'a'.repeat(24),
    countAdministrators: async () => 0,
    createAdministrator: async () => ({ id: 'admin-1' }),
    upsertAdministratorProfile: async () => undefined,
    protectedAdminRouter: createProtectedAdminRouter({ createService: () => service }),
    moderationRouter: Router(),
    verifyAdmin: async () => ({ id: 'admin-1', email: 'admin@cyanzone.test' }),
  };
  return createApp(dependencies);
}

function queryBuilder(result: unknown) {
  const chain = {
    select: () => chain,
    eq: () => chain,
    in: () => chain,
    order: () => chain,
    range: async () => ({ data: result, count: Array.isArray(result) ? result.length : null, error: null }),
    maybeSingle: async () => ({ data: result, error: null }),
  };
  return chain;
}

test('repository lists moderation cases and invokes the decision RPC', async () => {
  const rpcCalls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const client = {
    from: (table: string) => {
      if (table === 'content_moderation_cases') {
        return queryBuilder({
          id: 'case-1',
          target_type: 'post',
          target_id: 'post-1',
          owner_id: 'member-1',
          moderation_revision: 1,
          state: 'admin_review',
          overall_risk_score: 50,
          category_scores: { hate: 50 },
          evidence: ['test evidence'],
          user_reason: 'Needs review',
          model: 'gemini-3.8-flash',
          target_snapshot: {
            title: 'Submitted title',
            content: 'Submitted content',
            images: [
              {
                public_url: 'https://project.supabase.co/images/submitted.jpg',
                storage_path: 'member-1/submitted.jpg',
                position: 1,
              },
            ],
          },
          decision_reason: null,
          completed_at: null,
          created_at: '2026-09-06T12:00:00.000Z',
        });
      }
      if (table === 'posts') return queryBuilder({ id: 'post-1', title: 'Edited title', content: 'Edited content', author_id: 'member-1' });
      if (table === 'profiles') return queryBuilder({ id: 'member-1', name: 'Member', email: 'member@cyanzone.test' });
      if (table === 'post_images') return queryBuilder([{ post_id: 'post-1', public_url: 'https://project.supabase.co/images/a.jpg', position: 1 }]);
      return queryBuilder(null);
    },
    rpc: async (name: string, args: Record<string, unknown>) => {
      rpcCalls.push({ name, args });
      return { data: null, error: null };
    },
  } as any;

  const repository = createAdminRepository(client);
  const listed = await repository.listModerationCases({ page: 1, pageSize: 20, search: '', status: 'pending' });
  await repository.decideModerationCase('case-1', { decision: 'rejected', reason: 'Bullying directed at another member.' });

  assert.equal(listed.items[0]?.riskScore, 50);
  assert.equal(listed.items[0]?.status, 'pending');
  assert.equal(listed.items[0]?.title, 'Submitted title');
  assert.equal(listed.items[0]?.content, 'Submitted content');
  assert.deepEqual(listed.items[0]?.imageUrls, [
    'https://project.supabase.co/images/submitted.jpg',
  ]);
  assert.equal(rpcCalls[0]?.name, 'decide_content_moderation_case');
  assert.equal(rpcCalls[0]?.args.p_case_id, 'case-1');
});

test('service maps missing moderation cases and forwards decisions', async () => {
  const repository = baseRepository({
    getModerationCase: async () => null,
    decideModerationCase: async () => undefined,
  });
  const service = createAdminService(repository, 1);

  await assert.rejects(service.getModerationCase('missing'), AdminNotFoundError);
  await assert.doesNotReject(() => service.decideModerationCase('case-1', { decision: 'approved', reason: '' }));
});

test('admin moderation routes list cases and validate decisions', async () => {
  let decision: unknown;
  const service = {
    listModerationCases: async () => ({ items: [caseView], page: 1, pageSize: 20, total: 1 }),
    getModerationCase: async () => caseView,
    decideModerationCase: async (_id: string, input: unknown) => { decision = input; },
  } as unknown as AdminService;
  const app = createAdminApp(service);

  const list = await request(app)
    .get('/admin/moderation-cases?status=pending&page=1&pageSize=20')
    .set('Authorization', 'Bearer admin-token');
  assert.equal(list.status, 200);
  assert.equal(list.body.items[0].riskScore, 50);

  const invalid = await request(app)
    .post('/admin/moderation-cases/case-1/decision')
    .set('Authorization', 'Bearer admin-token')
    .send({ decision: 'rejected', reason: 'short' });
  assert.equal(invalid.status, 400);

  const approved = await request(app)
    .post('/admin/moderation-cases/case-1/decision')
    .set('Authorization', 'Bearer admin-token')
    .send({ decision: 'approved', reason: '' });
  assert.equal(approved.status, 204);
  assert.deepEqual(decision, { decision: 'approved', reason: '' });
});

test('admin moderation maps stale conflicts to 409', async () => {
  const service = {
    listModerationCases: async () => ({ items: [], page: 1, pageSize: 20, total: 0 }),
    getModerationCase: async () => caseView,
    decideModerationCase: async () => { throw new AdminConflictError('Case is no longer reviewable.'); },
  } as unknown as AdminService;
  const result = await request(createAdminApp(service))
    .post('/admin/moderation-cases/case-1/decision')
    .set('Authorization', 'Bearer admin-token')
    .send({ decision: 'approved', reason: '' });
  assert.equal(result.status, 409);
});
