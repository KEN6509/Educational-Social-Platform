import assert from 'node:assert/strict';
import test from 'node:test';
import { Router } from 'express';
import request from 'supertest';
import { createApp, type AppDependencies } from '../createApp.js';
import { createModerationRouter } from './moderationRouter.js';
import {
  ModerationNotFoundError,
  ModerationOwnershipError,
  ModerationProviderFailureError,
  ModerationStaleError,
  type ModerationService,
} from './moderationService.js';

function dependencies(service: ModerationService, verifyMember = async () => ({ id: 'member-1', email: 'member@cyanzone.test' })): AppDependencies {
  return {
    bootstrapSecret: 'a'.repeat(24),
    countAdministrators: async () => 0,
    createAdministrator: async () => ({ id: 'created-admin' }),
    upsertAdministratorProfile: async () => undefined,
    protectedAdminRouter: Router(),
    moderationRouter: createModerationRouter({ verifyMember, service }),
    verifyAdmin: async () => ({ id: 'admin-1', email: 'admin@cyanzone.test' }),
  };
}

const response = {
  targetType: 'post' as const,
  targetId: 'post-1',
  moderationRevision: 1,
  status: 'approved' as const,
  caseState: 'approved' as const,
  riskScore: 4,
  reason: 'safe',
  retryAllowed: false,
};

test('requires a member bearer token', async () => {
  const service = { moderate: async () => response } as ModerationService;
  const result = await request(createApp(dependencies(service))).post('/moderation/posts/post-1');
  assert.equal(result.status, 401);
});

test('moderates a comment for an authenticated member', async () => {
  let received: unknown;
  const service = {
    moderate: async (type, id, member) => {
      received = { type, id, member };
      return { ...response, targetType: 'comment', targetId: id, caseState: 'approved' as const };
    },
  } as ModerationService;

  const result = await request(createApp(dependencies(service)))
    .post('/moderation/comments/comment-1')
    .set('Authorization', 'Bearer member-token');

  assert.equal(result.status, 200);
  assert.equal(result.body.targetId, 'comment-1');
  assert.deepEqual(received, {
    type: 'comment',
    id: 'comment-1',
    member: { id: 'member-1', email: 'member@cyanzone.test' },
  });
});

test('maps typed moderation failures to safe statuses', async () => {
  const scenarios = [
    [new ModerationOwnershipError('Not yours.'), 403],
    [new ModerationNotFoundError('Missing.'), 404],
    [new ModerationStaleError('Changed.'), 409],
    [new ModerationProviderFailureError('Retry later.', true), 503],
  ] as const;

  for (const [error, status] of scenarios) {
    const service = { moderate: async () => { throw error; } } as ModerationService;
    const result = await request(createApp(dependencies(service)))
      .post('/moderation/posts/post-1')
      .set('Authorization', 'Bearer member-token');
    assert.equal(result.status, status);
    assert.equal(result.body.error, error.message);
    if (status === 503) assert.equal(result.body.retryAllowed, true);
  }
});

test('does not expose provider or database details in unexpected errors', async () => {
  const service = {
    moderate: async () => {
      throw new Error('postgres password and Gemini stack trace');
    },
  } as ModerationService;
  const result = await request(createApp(dependencies(service)))
    .post('/moderation/posts/post-1')
    .set('Authorization', 'Bearer member-token');

  assert.equal(result.status, 500);
  assert.equal(result.body.error, 'Unable to complete the moderation request.');
  assert.doesNotMatch(JSON.stringify(result.body), /postgres|Gemini stack/i);
});
