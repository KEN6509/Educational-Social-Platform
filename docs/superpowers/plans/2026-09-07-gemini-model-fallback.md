# Gemini Model Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Gemini 3.5 Flash-Lite the primary CyanZone moderation model and perform at most one controlled Gemini 3.8 Flash fallback without exceeding the two-call request budget.

**Architecture:** The Gemini gateway will own the complete two-attempt provider policy, while the moderation service invokes the provider only once and persists attempt metadata. HTTP 429/503 selects the fallback model; other retryable failures retry the primary model; safety and permanent failures stop immediately.

**Tech Stack:** TypeScript, Node.js, Express, `@google/genai`, Zod, Node test runner, Supabase moderation RPCs

---

### Task 1: Configure primary and fallback models

**Files:**
- Modify: `services/api/src/config/env.test.ts`
- Modify: `services/api/src/config/env.ts`
- Modify: `services/api/.env.example`

- [ ] **Step 1: Write failing environment tests**

Add assertions to the bounded-default test and deployment-override test:

```ts
test('Gemini moderation configuration has bounded defaults', () => {
  const parsed = parseEnv(requiredEnv);

  assert.equal(parsed.GEMINI_MODEL, 'gemini-3.5-flash-lite');
  assert.equal(parsed.GEMINI_FALLBACK_MODEL, 'gemini-3.8-flash');
  assert.equal(parsed.GEMINI_TIMEOUT_MS, 8500);
});

test('Gemini moderation configuration accepts deployment overrides', () => {
  const parsed = parseEnv({
    ...requiredEnv,
    GEMINI_MODEL: 'gemini-3.6-flash',
    GEMINI_FALLBACK_MODEL: 'gemini-3.8-flash',
    GEMINI_TIMEOUT_MS: '7000',
  });

  assert.equal(parsed.GEMINI_MODEL, 'gemini-3.6-flash');
  assert.equal(parsed.GEMINI_FALLBACK_MODEL, 'gemini-3.8-flash');
  assert.equal(parsed.GEMINI_TIMEOUT_MS, 7000);
});

test('Gemini primary and fallback models must differ', () => {
  assert.throws(
    () => parseEnv({
      ...requiredEnv,
      GEMINI_MODEL: 'gemini-3.8-flash',
      GEMINI_FALLBACK_MODEL: 'gemini-3.8-flash',
    }),
    /fallback/i,
  );
});
```

- [ ] **Step 2: Run the environment tests and confirm failure**

Run:

```powershell
cd services/api
npx tsx --test src/config/env.test.ts
```

Expected: failure because the primary default is still 3.8 Flash and `GEMINI_FALLBACK_MODEL` is not parsed.

- [ ] **Step 3: Implement the environment contract**

Extend the Zod object and add a cross-field check:

```ts
const envSchema = z.object({
  PORT: z.coerce.number().default(4000),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ADMIN_BOOTSTRAP_SECRET: z.string().min(24),
  REPORT_REVIEW_THRESHOLD: z.coerce.number().int().min(1).default(1),
  GEMINI_API_KEY: z.string().min(1).optional(),
  GEMINI_MODEL: z.string().trim().min(1).default('gemini-3.5-flash-lite'),
  GEMINI_FALLBACK_MODEL: z.string().trim().min(1).default('gemini-3.8-flash'),
  GEMINI_TIMEOUT_MS: z.coerce.number().int().min(1000).max(9500).default(8500),
  CORS_ALLOWED_ORIGINS: corsOriginsSchema,
}).refine(
  (value) => value.GEMINI_MODEL !== value.GEMINI_FALLBACK_MODEL,
  {
    path: ['GEMINI_FALLBACK_MODEL'],
    message: 'Gemini fallback model must differ from the primary model',
  },
);
```

Add the fallback variable to `.env.example`:

```text
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_FALLBACK_MODEL=gemini-3.8-flash
GEMINI_TIMEOUT_MS=8500
```

- [ ] **Step 4: Run the focused test and typecheck**

Run:

```powershell
npx tsx --test src/config/env.test.ts
npm run typecheck
```

Expected: all environment tests pass and TypeScript reports no errors.

- [ ] **Step 5: Commit configuration changes**

```powershell
git add services/api/src/config/env.test.ts services/api/src/config/env.ts services/api/.env.example
git commit -m "feat: configure Gemini fallback model"
```

### Task 2: Centralize the two-call policy in the Gemini gateway

**Files:**
- Modify: `services/api/src/moderation/moderationTypes.ts`
- Modify: `services/api/src/moderation/geminiModerationGateway.test.ts`
- Modify: `services/api/src/moderation/geminiModerationGateway.ts`

- [ ] **Step 1: Add failing gateway policy tests**

Update the test factory to accept two model names and collect every request.
Add tests with these exact expectations:

```ts
const commentTarget: ModerationTarget = {
  targetType: 'comment',
  content: 'Helpful study advice.',
  tags: [],
  images: [],
};

function createGateway(
  createInteraction: (
    request: GeminiInteractionRequest,
  ) => Promise<{ output_text?: string }>,
) {
  return new GeminiModerationGateway({
    apiKey: 'test-key',
    primaryModel: 'gemini-3.5-flash-lite',
    fallbackModel: 'gemini-3.8-flash',
    timeoutMs: 8500,
    createInteraction,
  });
}

test('falls back to 3.8 Flash once after primary 429', async () => {
  const requests: GeminiInteractionRequest[] = [];
  const gateway = createGateway(async (request) => {
    requests.push(request);
    if (requests.length === 1) throw { status: 429, message: 'quota' };
    return { output_text: JSON.stringify(safeResponse) };
  });

  const result = await gateway.moderate(commentTarget);

  assert.deepEqual(requests.map((request) => request.model), [
    'gemini-3.5-flash-lite',
    'gemini-3.8-flash',
  ]);
  assert.equal(result.model, 'gemini-3.8-flash');
  assert.equal(result.providerAttempts, 2);
});

test('falls back to 3.8 Flash once after primary 503', async () => {
  const models: string[] = [];
  const gateway = createGateway(async (request) => {
    models.push(request.model);
    if (models.length === 1) throw { status: 503, message: 'unavailable' };
    return { output_text: JSON.stringify(safeResponse) };
  });

  await gateway.moderate(commentTarget);
  assert.deepEqual(models, ['gemini-3.5-flash-lite', 'gemini-3.8-flash']);
});

test('retries the primary once for a timeout instead of using fallback', async () => {
  const models: string[] = [];
  const gateway = createGateway(async (request) => {
    models.push(request.model);
    if (models.length === 1) throw new Error('request timed out');
    return { output_text: JSON.stringify(safeResponse) };
  });

  await gateway.moderate(commentTarget);
  assert.deepEqual(models, ['gemini-3.5-flash-lite', 'gemini-3.5-flash-lite']);
});

test('never makes a third provider call', async () => {
  let calls = 0;
  const gateway = createGateway(async () => {
    calls += 1;
    throw { status: 503, message: 'unavailable' };
  });

  await assert.rejects(gateway.moderate(commentTarget));
  assert.equal(calls, 2);
});
```

Retain and strengthen the existing permanent-error and safety tests by asserting
that their injected interaction function is called exactly once.

- [ ] **Step 2: Run the gateway tests and confirm failure**

Run:

```powershell
npx tsx --test src/moderation/geminiModerationGateway.test.ts
```

Expected: failures because the gateway currently has one model and one call.

- [ ] **Step 3: Add provider attempt/status metadata**

Extend the result and error types:

```ts
export type ModerationProviderResult = {
  overallRiskScore: number;
  categoryScores: Record<ModerationCategory, number>;
  evidence: string[];
  userReason: string;
  evidenceSource: ModerationEvidenceSource;
  model: string;
  promptVersion: string;
  providerAttempts?: number;
};

export class ModerationProviderError extends Error {
  readonly retryable: boolean;
  readonly cause?: unknown;
  readonly statusCode?: number;
  readonly providerAttempts: number;

  constructor(message: string, options: {
    retryable?: boolean;
    cause?: unknown;
    statusCode?: number;
    providerAttempts?: number;
  } = {}) {
    super(message);
    this.name = 'ModerationProviderError';
    this.retryable = options.retryable ?? true;
    this.cause = options.cause;
    this.statusCode = options.statusCode;
    this.providerAttempts = options.providerAttempts ?? 1;
  }
}
```

Extend `GeminiInputSafetyError` with an optional third `providerAttempts`
argument and forward it to `ModerationProviderError`.

- [ ] **Step 4: Implement the two-call gateway**

Change the gateway options to:

```ts
export type GeminiModerationGatewayOptions = {
  apiKey: string;
  primaryModel: string;
  fallbackModel: string;
  timeoutMs: number;
  createInteraction?: GeminiInteractionClient['create'];
};
```

Store both models. Split the existing request/parse work into
`moderateWithModel(target, model, providerAttempts)`. Implement `moderate` as:

```ts
async moderate(target: ModerationTarget): Promise<ModerationProviderResult> {
  try {
    return await this.moderateWithModel(target, this.primaryModel, 1);
  } catch (error) {
    const primaryError = withProviderAttempts(normalizeGeminiError(error), 1);
    if (!primaryError.retryable) throw primaryError;

    const secondModel = primaryError.statusCode === 429 ||
        primaryError.statusCode === 503
      ? this.fallbackModel
      : this.primaryModel;

    try {
      return await this.moderateWithModel(target, secondModel, 2);
    } catch (secondError) {
      throw withProviderAttempts(normalizeGeminiError(secondError), 2);
    }
  }
}
```

`moderateWithModel` must set `model` to the model used for that call and
`providerAttempts` to its argument after schema validation. Update
`normalizeGeminiError` to store `findHttpStatus(error)` as `statusCode`.
`withProviderAttempts` must preserve safety ratings/evidence source when it
recreates a `GeminiInputSafetyError`; otherwise it recreates a
`ModerationProviderError` with the original retryability, cause, and status.

Use this helper so second-attempt metadata is never lost:

```ts
function withProviderAttempts(
  error: ModerationProviderError,
  providerAttempts: number,
): ModerationProviderError {
  if (error instanceof GeminiInputSafetyError) {
    return new GeminiInputSafetyError(
      error.ratings,
      error.evidenceSource,
      providerAttempts,
    );
  }
  return new ModerationProviderError(error.message, {
    retryable: error.retryable,
    cause: error.cause,
    statusCode: error.statusCode,
    providerAttempts,
  });
}
```

- [ ] **Step 5: Run focused gateway tests and typecheck**

Run:

```powershell
npx tsx --test src/moderation/geminiModerationGateway.test.ts
npm run typecheck
```

Expected: all gateway tests pass and TypeScript reports no errors.

- [ ] **Step 6: Commit the provider policy**

```powershell
git add services/api/src/moderation/moderationTypes.ts services/api/src/moderation/geminiModerationGateway.test.ts services/api/src/moderation/geminiModerationGateway.ts
git commit -m "feat: add bounded Gemini model fallback"
```

### Task 3: Persist exact provider attempts without service multiplication

**Files:**
- Modify: `services/api/src/moderation/moderationService.test.ts`
- Modify: `services/api/src/moderation/moderationService.ts`
- Modify: `services/api/src/index.ts`

- [ ] **Step 1: Replace service-retry tests with provider-owned-attempt tests**

Import `PersistedModerationResult`, type the harness's captured
`persistedResult` with that type, and make the gateway/service default missing
provider-attempt metadata to one for non-Gemini test providers. Replace the old
service retry test with:

```ts
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
  assert.equal(harness.persistedResult?.attemptCount, 2);
  assert.equal(harness.persistedResult?.model, 'gemini-3.8-flash');
});
```

Update the failed-provider test so the thrown `ModerationProviderError` has
`providerAttempts: 2`, then capture the failure passed to `markFailed` and
assert its `attemptCount` is `2`.

- [ ] **Step 2: Run the service tests and confirm failure**

Run:

```powershell
npx tsx --test src/moderation/moderationService.test.ts
```

Expected: failures because the service still loops twice and supplies its own
attempt counter.

- [ ] **Step 3: Make the service invoke the provider once**

Replace the two-iteration loop with one provider call. On success, pass
`providerResult.providerAttempts` into `applyResult`. On a safety block, create
the fail-closed result with `providerAttempts: error.providerAttempts` and pass
that count into `applyResult`. On `ModerationProviderError`, call `markFailed`
with:

```ts
{
  claimToken: moderationCase.claimToken ?? '',
  code: error.retryable ? 'provider_unavailable' : 'provider_rejected',
  message: 'Gemini moderation did not complete.',
  attemptCount: error.providerAttempts,
}
```

Then throw the existing `ModerationProviderFailureError` with
`retryAllowed: error.retryable`. Repository, cooldown, stale-revision, and
score-threshold behavior remain unchanged.

- [ ] **Step 4: Wire both configured models into production**

Construct the provider in `src/index.ts` with:

```ts
new GeminiModerationGateway({
  apiKey: env.GEMINI_API_KEY,
  primaryModel: env.GEMINI_MODEL,
  fallbackModel: env.GEMINI_FALLBACK_MODEL,
  timeoutMs: env.GEMINI_TIMEOUT_MS,
})
```

- [ ] **Step 5: Run service tests, full API tests, typecheck, and build**

Run:

```powershell
npx tsx --test src/moderation/moderationService.test.ts
npm test
npm run typecheck
npm run build
```

Expected: all tests pass, TypeScript reports no errors, and the API build
completes successfully.

- [ ] **Step 6: Commit service integration**

```powershell
git add services/api/src/moderation/moderationService.test.ts services/api/src/moderation/moderationService.ts services/api/src/index.ts
git commit -m "fix: bound Gemini provider attempts"
```

### Task 4: Update rollout documentation and verify the real primary model

**Files:**
- Modify: `README.md`
- Modify: `Project_Overview.md`
- Modify: `docs/setup.md`
- Modify: `docs/superpowers/specs/2026-09-07-gemini-model-fallback-design.md`

- [ ] **Step 1: Update model and fallback documentation**

Replace statements that call 3.8 Flash the default with the implemented chain:

```text
Primary: gemini-3.5-flash-lite
Fallback for HTTP 429/503: gemini-3.8-flash
Maximum provider calls per moderation request: 2
Per-call timeout: 8500 ms
```

Add `GEMINI_FALLBACK_MODEL` to local and Vercel API environment lists. Mark the
fallback design specification as implemented after verification.

- [ ] **Step 2: Run documentation and dependency checks**

Run:

```powershell
rg -n "gemini-3.8-flash|gemini-3.5-flash-lite|GEMINI_FALLBACK_MODEL" README.md Project_Overview.md docs/setup.md services/api/.env.example
git diff --check
cd services/api
npm audit
npm audit --omit=dev
```

Expected: every default statement names 3.5 Flash-Lite, fallback statements
name 3.8 Flash, no whitespace errors are reported, and both audits report zero
vulnerabilities.

- [ ] **Step 3: Run one safe live primary-model smoke test**

Use the existing ignored `services/api/.env` and the production gateway to
moderate one harmless educational text. Print only `ok`, final model, risk
score, evidence source, and attempt count. Never print the API key.

Expected: `ok: true`, model `gemini-3.5-flash-lite`, and provider attempt count
`1`. Do not intentionally consume quota to exercise fallback; automated tests
cover that path.

- [ ] **Step 4: Verify repository state and commit documentation**

Run:

```powershell
cd ../..
git status --short
git diff --check
```

Stage only the four documentation files and commit:

```powershell
git add README.md Project_Overview.md docs/setup.md docs/superpowers/specs/2026-09-07-gemini-model-fallback-design.md
git commit -m "docs: document Gemini fallback rollout"
```

Do not stage `apps/admin/tsconfig.tsbuildinfo` or the user's deleted mobile
screenshots.
