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
  type PersistedModerationFailure,
  type PersistedModerationResult,
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
  let persistedResult: PersistedModerationResult | undefined;
  let persistedFailure: PersistedModerationFailure | undefined;
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
      persistedResult = result;
      applied = {
        ...prepared,
        state: result.state,
        riskScore: result.overallRiskScore,
        reason: result.userReason,
        shouldProcess: false,
      };
      return applied;
    },
    markFailed: async (_caseId, _revision, failure) => {
      failed = true;
      persistedFailure = failure;
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
    get persistedResult() {
      return persistedResult;
    },
    get persistedFailure() {
      return persistedFailure;
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

test('invokes the provider once and persists its exact attempt count', async () => {
  const harness = createHarness();
  let calls = 0;
  harness.provider.moderate = async () => {
    calls += 1;
    return {
      ...providerResult(10),
      model: 'gemini-3.8-flash',
      providerAttempts: 2,
    };
  };

  const response = await harness.service.moderate('post', 'post-1', member);

  assert.equal(response.status, 'approved');
  assert.equal(calls, 1);
  assert.equal(harness.failed, false);
  assert.equal(harness.applied?.state, 'approved');
  assert.equal(harness.persistedResult?.attemptCount, 2);
  assert.equal(harness.persistedResult?.model, 'gemini-3.8-flash');
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

test('safety-blocked input maps only supplied categories and preserves evidence source', async () => {
  const harness = createHarness();
  harness.provider.moderate = async () => {
    throw new GeminiInputSafetyError(
      [
        {
          category: 'HARM_CATEGORY_HATE_SPEECH',
          probability: 'HIGH',
          blocked: true,
        },
      ],
      'image',
    );
  };

  await harness.service.moderate('post', 'post-1', member);

  assert.equal(harness.persistedResult?.categoryScores.hate, 100);
  assert.equal(harness.persistedResult?.categoryScores.harassmentBullying, 0);
  assert.equal(harness.persistedResult?.categoryScores.sexual, 0);
  assert.equal(harness.persistedResult?.evidenceSource, 'image');
});

test('final provider failure marks the case and exposes retryable 503 semantics', async () => {
  const harness = createHarness();
  harness.provider.moderate = async () => {
    throw new ModerationProviderError('timeout', { providerAttempts: 2 });
  };

  await assert.rejects(
    harness.service.moderate('post', 'post-1', member),
    (error: unknown) =>
      error instanceof ModerationProviderFailureError &&
      error.status === 503 &&
      error.retryAllowed === true,
  );
  assert.equal(harness.failed, true);
  assert.equal(harness.persistedFailure?.attemptCount, 2);
});

test('rejects a member attempting to moderate another member\'s target', async () => {
  const harness = createHarness();
  harness.repository.loadTarget = async () => ({ ...target(), ownerId: 'other-member' });

  await assert.rejects(
    harness.service.moderate('post', 'post-1', member),
    /ownership/i,
  );
});
