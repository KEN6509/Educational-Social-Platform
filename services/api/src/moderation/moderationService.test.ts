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
    evidence: ['test evidence'],
    userReason: 'test reason',
    model: 'gemini-3.8-flash',
    promptVersion: 'cyanzone-moderation-v3',
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

test('uses the risk score as the sole decision input and preserves the explanation', async () => {
  const harness = createHarness();
  harness.provider.moderate = async () => ({
    ...providerResult(30),
    evidence: ['fuck you'],
    userReason: 'Direct hostile profanity targets another person.',
  });

  const response = await harness.service.moderate('post', 'post-1', member);

  assert.equal(response.caseState, 'approved');
  assert.equal(harness.persistedResult?.state, 'approved');
  assert.equal(
    harness.persistedResult?.userReason,
    'Direct hostile profanity targets another person.',
  );
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

test('persists the exact attempt count when the second provider call is safety-blocked', async () => {
  const harness = createHarness();
  harness.provider.moderate = async () => {
    throw new GeminiInputSafetyError(
      [{ category: 'HARM_CATEGORY_HATE_SPEECH', blocked: true }],
      2,
    );
  };

  await harness.service.moderate('post', 'post-1', member);

  assert.equal(harness.persistedResult?.attemptCount, 2);
  assert.equal(harness.persistedResult?.providerAttempts, 2);
});

test('safety-blocked input records a score-100 explanation and concrete evidence', async () => {
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
    );
  };

  await harness.service.moderate('post', 'post-1', member);

  assert.equal(harness.persistedResult?.overallRiskScore, 100);
  assert.match(harness.persistedResult?.userReason ?? '', /safety/i);
  assert.match(harness.persistedResult?.evidence.join(' ') ?? '', /hate/i);
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
