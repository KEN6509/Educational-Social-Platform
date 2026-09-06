import assert from 'node:assert/strict';
import test from 'node:test';
import {
  GeminiInputSafetyError,
  ModerationProviderError,
  type ModerationCase,
  type ModerationRepository,
  type ModerationTargetRecord,
  type ModerationProvider,
  type ModerationProviderResult,
} from './moderationTypes.js';
import {
  createModerationService,
  ModerationProviderFailureError,
} from './moderationService.js';

const member = { id: 'member-1', email: 'member@cyanzone.test' };

function providerResult(score: number): ModerationProviderResult {
  return {
    overallRiskScore: score,
    categoryScores: {
      harassmentBullying: score,
      hate: score,
      sexual: score,
      violenceDanger: score,
      selfHarm: score,
      spamScam: score,
      privacyExposure: score,
    },
    evidence: ['test evidence'],
    userReason: 'test reason',
    evidenceSource: 'text',
    model: 'gemini-3.8-flash',
    promptVersion: 'cyanzone-moderation-v1',
  };
}

function target(): ModerationTargetRecord {
  return {
    id: 'post-1',
    ownerId: 'member-1',
    revision: 2,
    target: {
      targetType: 'post',
      title: 'Post',
      content: 'Content',
      tags: [],
      images: [],
    },
  };
}

function processingCase(overrides: Partial<ModerationCase> = {}): ModerationCase {
  return {
    id: 'case-1',
    targetType: 'post',
    targetId: 'post-1',
    ownerId: 'member-1',
    revision: 2,
    state: 'processing',
    claimToken: 'claim-1',
    attemptCount: 0,
    shouldProcess: true,
    ...overrides,
  };
}

function createHarness() {
  let prepared = processingCase();
  let applied: ModerationCase | undefined;
  let failed = false;
  let providerCalls = 0;
  const provider: ModerationProvider = {
    moderate: async () => {
      providerCalls += 1;
      return providerResult(10);
    },
  };
  const repository: ModerationRepository = {
    loadTarget: async () => target(),
    prepare: async () => prepared,
    applyResult: async (_caseId, _revision, result) => {
      applied = {
        ...prepared,
        state: result.state,
        riskScore: result.overallRiskScore,
        reason: result.userReason,
        shouldProcess: false,
      };
      return applied;
    },
    markFailed: async () => {
      failed = true;
      return { ...prepared, state: 'failed', shouldProcess: false };
    },
  };
  return {
    provider,
    repository,
    service: createModerationService(repository, provider),
    setPrepared: (value: ModerationCase) => {
      prepared = value;
    },
    get applied() {
      return applied;
    },
    get failed() {
      return failed;
    },
    get providerCalls() {
      return providerCalls;
    },
  };
}

for (const [score, expected] of [
  [39.99, 'approved'],
  [40, 'admin_review'],
  [60, 'admin_review'],
  [60.01, 'rejected'],
] as const) {
  test(`score ${score} maps to ${expected}`, async () => {
    const harness = createHarness();
    harness.provider.moderate = async () => providerResult(score);

    const response = await harness.service.moderate('post', 'post-1', member);

    assert.equal(response.caseState, expected);
    assert.equal(response.status, expected === 'admin_review' ? 'pending' : expected);
  });
}

test('returns a live processing case without invoking Gemini twice', async () => {
  const harness = createHarness();
  harness.setPrepared(processingCase({ shouldProcess: false }));

  const response = await harness.service.moderate('post', 'post-1', member);

  assert.equal(response.caseState, 'processing');
  assert.equal(response.status, 'pending');
  assert.equal(harness.providerCalls, 0);
});

test('retries one transient failure and persists one case', async () => {
  const harness = createHarness();
  let calls = 0;
  harness.provider.moderate = async () => {
    calls += 1;
    if (calls === 1) throw new ModerationProviderError('timeout');
    return providerResult(10);
  };

  const response = await harness.service.moderate('post', 'post-1', member);

  assert.equal(response.status, 'approved');
  assert.equal(calls, 2);
  assert.equal(harness.failed, false);
  assert.equal(harness.applied?.state, 'approved');
});

test('safety-blocked input is fail-closed as a score-100 rejection', async () => {
  const harness = createHarness();
  harness.provider.moderate = async () => {
    throw new GeminiInputSafetyError([{ category: 'hate' }]);
  };

  const response = await harness.service.moderate('post', 'post-1', member);

  assert.equal(response.caseState, 'rejected');
  assert.equal(response.riskScore, 100);
  assert.equal(harness.applied?.state, 'rejected');
});

test('final provider failure marks the case and exposes retryable 503 semantics', async () => {
  const harness = createHarness();
  harness.provider.moderate = async () => {
    throw new ModerationProviderError('timeout');
  };

  await assert.rejects(
    harness.service.moderate('post', 'post-1', member),
    (error: unknown) =>
      error instanceof ModerationProviderFailureError &&
      error.status === 503 &&
      error.retryAllowed === true,
  );
  assert.equal(harness.providerCalls, 0);
  assert.equal(harness.failed, true);
});

test('rejects a member attempting to moderate another member\'s target', async () => {
  const harness = createHarness();
  harness.repository.loadTarget = async () => ({ ...target(), ownerId: 'other-member' });

  await assert.rejects(
    harness.service.moderate('post', 'post-1', member),
    /ownership/i,
  );
});
