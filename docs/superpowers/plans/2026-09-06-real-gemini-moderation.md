# Real Gemini Moderation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace temporary auto-approval and the mock Admin AI queue with secure, auditable Gemini text-and-image moderation for public posts, edited posts, and comments.

**Architecture:** Mobile persists unpublished content in Supabase and asks the existing Express API to moderate the authoritative record. A Google GenAI adapter returns schema-validated evidence, the API applies CyanZone's fixed thresholds through transactional Supabase functions, and the Admin Portal reviews genuine medium-risk cases through protected API routes. The database stores revisioned cases so retries are idempotent and stale results cannot publish edited content.

**Tech Stack:** PostgreSQL/RLS/Supabase RPC, Node.js 22, Express, TypeScript, Zod, `@google/genai`, Flutter/Dart, `package:http`, React, Vitest, Vercel Functions

---

## File Structure

### Supabase

- Create `supabase/ai_moderation.sql`: idempotent existing-project migration, run after `admin_portal.sql`, containing moderation case storage, revision invalidation, field protection, RPCs, RLS, grants, and indexes.
- Modify `supabase/schema.sql`: mirror the final moderation schema for a new project and remove temporary auto-approval.
- Modify `supabase/README.md`: document migration order and verification queries.

### Express API

- Modify `services/api/package.json` and `services/api/package-lock.json`: add the maintained Google GenAI SDK.
- Modify `services/api/.env.example` and `services/api/src/config/env.ts`: define the model and timeout configuration.
- Create `services/api/src/moderation/moderationTypes.ts`: CyanZone-owned target, provider result, case, response, repository, and service contracts.
- Create `services/api/src/moderation/moderationSchemas.ts`: Gemini output schema and HTTP request/query schemas.
- Create `services/api/src/moderation/geminiModerationGateway.ts`: Adapter from Google GenAI structured multimodal output to CyanZone types.
- Create `services/api/src/moderation/moderationAuth.ts`: active-member bearer authentication middleware.
- Create `services/api/src/moderation/moderationRepository.ts`: authoritative Supabase target reads and moderation RPC calls.
- Create `services/api/src/moderation/moderationService.ts`: idempotency, retry, thresholds, stale-revision, and response mapping.
- Create `services/api/src/moderation/moderationRouter.ts`: member moderation endpoints and stable HTTP errors.
- Create matching `*.test.ts` files plus `moderationSql.test.ts`.
- Modify `services/api/src/admin/adminTypes.ts`, `adminSchemas.ts`, `adminRepository.ts`, `adminService.ts`, and `adminRouter.ts`: add real moderation case list/detail/decision operations.
- Modify their existing tests for the new admin behavior.
- Modify `services/api/src/app.ts`: mount the member moderation router.
- Create `services/api/src/index.ts`: compose and default-export the Vercel-detectable Express application.
- Modify `services/api/src/server.ts`: start the exported app only for local development.
- Modify `services/api/src/all.test.ts`: include the new test modules.

### Flutter mobile

- Modify `apps/mobile/pubspec.yaml` and `pubspec.lock`: declare `http` directly.
- Modify `apps/mobile/.env.example`: add `API_BASE_URL`.
- Create `apps/mobile/lib/src/core/config/api_config.dart`: validated API base URL access.
- Create `apps/mobile/lib/src/features/posts/domain/content_moderation.dart`: result/state/failure contracts.
- Create `apps/mobile/lib/src/features/posts/domain/post_submission_repository.dart`: narrow create/update/comment persistence contract for coordination and tests.
- Create `apps/mobile/lib/src/features/posts/data/http_content_moderation_gateway.dart`: authenticated API adapter.
- Create `apps/mobile/lib/src/features/posts/presentation/content_moderation_scope.dart`: app-level gateway access with test injection.
- Modify `apps/mobile/lib/src/app_dependencies.dart` and `app.dart`: compose and expose the gateway.
- Modify `apps/mobile/lib/src/features/posts/data/posts_repository.dart`: return created IDs, store image MIME types, and stop writing privileged moderation fields.
- Modify `create_post_page.dart`, `post_detail_page.dart`, and `post_submission_error.dart`: coordinate moderation outcomes and retry the same record.
- Add focused gateway, repository contract, and widget tests.

### React Admin Portal

- Delete `apps/admin/src/features/aiFlagged/aiFlaggedMockData.ts` and `aiFlaggedMockAdapter.ts`.
- Modify `aiFlaggedTypes.ts`: match the real API contract.
- Create `aiFlaggedApi.ts`: list/detail/decision adapter over `adminApi`.
- Modify `AiFlaggedContentPage.tsx`: asynchronous real case loading and decisions.
- Replace the mock-based page tests with API-backed tests.

### Documentation

- Modify `README.md`, `docs/setup.md`, and `Project_Overview.md`: record the implemented boundary and exact local/Vercel/Supabase configuration.

---

### Task 1: Add Gemini Environment and SDK Foundations

**Files:**
- Modify: `services/api/src/config/env.test.ts`
- Modify: `services/api/src/config/env.ts`
- Modify: `services/api/.env.example`
- Modify: `services/api/package.json`
- Modify: `services/api/package-lock.json`

- [ ] **Step 1: Write failing environment tests**

Add tests proving the model and per-attempt timeout have safe defaults and valid overrides:

```ts
test('Gemini moderation configuration has bounded defaults', () => {
  const env = parseEnv(baseEnv);
  assert.equal(env.GEMINI_MODEL, 'gemini-3.8-flash');
  assert.equal(env.GEMINI_TIMEOUT_MS, 8500);
});

test('Gemini moderation configuration accepts deployment overrides', () => {
  const env = parseEnv({
    ...baseEnv,
    GEMINI_MODEL: 'gemini-3.7-flash',
    GEMINI_TIMEOUT_MS: '7000',
  });
  assert.equal(env.GEMINI_MODEL, 'gemini-3.7-flash');
  assert.equal(env.GEMINI_TIMEOUT_MS, 7000);
});

test('Gemini timeout cannot consume the complete 20 second budget', () => {
  assert.throws(() =>
    parseEnv({ ...baseEnv, GEMINI_TIMEOUT_MS: '10000' }),
  );
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd services/api; npx tsx --test src/config/env.test.ts`

Expected: FAIL because `GEMINI_MODEL` and `GEMINI_TIMEOUT_MS` do not exist.

- [ ] **Step 3: Install the maintained SDK**

Run: `cd services/api; npm install @google/genai`

Expected: `package.json` and `package-lock.json` record `@google/genai` and npm exits successfully.

- [ ] **Step 4: Implement the environment contract**

Extend `envSchema` with:

```ts
GEMINI_API_KEY: z.string().min(1).optional(),
GEMINI_MODEL: z.string().trim().min(1).default('gemini-3.8-flash'),
GEMINI_TIMEOUT_MS: z.coerce.number().int().min(1000).max(9500).default(8500),
```

Keep the API key optional at process startup so `/health` and administrator
setup remain usable locally. The moderation service will return a typed
provider-unavailable failure when the key is missing.

Add to `.env.example`:

```dotenv
GEMINI_API_KEY=your-gemini-api-key
GEMINI_MODEL=gemini-3.8-flash
GEMINI_TIMEOUT_MS=8500
```

- [ ] **Step 5: Run the focused test and type-check**

Run: `cd services/api; npx tsx --test src/config/env.test.ts; npm run typecheck`

Expected: environment tests PASS and TypeScript reports no errors.

- [ ] **Step 6: Commit**

```powershell
git add -- services/api/package.json services/api/package-lock.json services/api/.env.example services/api/src/config/env.ts services/api/src/config/env.test.ts
git commit -m "build: add Gemini moderation configuration"
```

---

### Task 2: Make Supabase the Revisioned Moderation Authority

**Files:**
- Create: `supabase/ai_moderation.sql`
- Modify: `supabase/schema.sql`
- Create: `services/api/src/moderation/moderationSql.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write the failing SQL contract test**

Create a test that reads both fresh-project and migration SQL and asserts every
security boundary:

```ts
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migration = readFileSync(
  new URL('../../../../supabase/ai_moderation.sql', import.meta.url),
  'utf8',
);
const schema = readFileSync(
  new URL('../../../../supabase/schema.sql', import.meta.url),
  'utf8',
);

for (const [name, sql] of [['migration', migration], ['schema', schema]] as const) {
  test(`${name} defines the moderation authority`, () => {
    assert.match(sql, /create table if not exists public\.content_moderation_cases/i);
    assert.match(sql, /unique\s*\(target_type, target_id, moderation_revision\)/i);
    assert.match(sql, /prepare_content_moderation/i);
    assert.match(sql, /apply_ai_moderation_result/i);
    assert.match(sql, /mark_content_moderation_failed/i);
    assert.match(sql, /grant execute[\s\S]*to service_role/i);
    assert.match(sql, /moderation_revision/i);
    assert.match(sql, /invalidate_post_image_moderation/i);
  });
}

test('upgrade SQL adds the audited administrator decision boundary', () => {
  assert.match(migration, /decide_content_moderation_case/i);
  assert.match(migration, /admin_action_audit/i);
  assert.match(migration, /grant execute[\s\S]*to authenticated/i);
});

test('new content is no longer auto-approved', () => {
  assert.doesNotMatch(schema, /default 'approved'.*auto-approve/i);
  assert.doesNotMatch(schema, /update public\.(posts|comments) set moderation_status = 'approved'/i);
  assert.match(schema, /moderation_status[^\n]+default 'pending'/i);
});
```

Import `./moderation/moderationSql.test.js` from `src/all.test.ts`.

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd services/api; npx tsx --test src/moderation/moderationSql.test.ts`

Expected: FAIL because `supabase/ai_moderation.sql` and the moderation contracts do not exist.

- [ ] **Step 3: Add the moderation case table and content columns**

Define the same final table and content-column structure in both SQL files.
`schema.sql` owns fresh-project tables and core service-role functions;
`ai_moderation.sql` is the complete existing-project upgrade and additionally
defines the admin decision function after `admin_portal.sql` has created its
audit table:

```sql
create table if not exists public.content_moderation_cases (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('post', 'comment')),
  target_id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  moderation_revision integer not null check (moderation_revision > 0),
  state text not null check (
    state in ('processing', 'admin_review', 'approved', 'rejected', 'failed', 'superseded')
  ),
  overall_risk_score numeric(5,2)
    check (overall_risk_score between 0 and 100),
  category_scores jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  user_reason text,
  provider text,
  model text,
  prompt_version text,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  claim_token uuid,
  lease_expires_at timestamptz,
  failure_code text,
  failure_message text,
  decision_source text check (decision_source in ('gemini', 'admin')),
  decided_by uuid references public.profiles(id) on delete set null,
  decision_reason text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (target_type, target_id, moderation_revision)
);

alter table public.posts
  add column if not exists moderation_revision integer not null default 1;
alter table public.comments
  add column if not exists moderation_revision integer not null default 1;
alter table public.post_images
  add column if not exists mime_type text
    check (mime_type is null or mime_type in (
      'image/png', 'image/jpeg', 'image/webp', 'image/heic', 'image/heif'
    ));
```

Change new post/comment defaults to `pending`, remove the two temporary bulk
approval statements from `schema.sql`, and preserve all existing approved rows
when applying the incremental migration.

- [ ] **Step 4: Add revision invalidation and field protection**

Create triggers with these exact transitions:

```sql
-- Post title, content, or tags changed by a member:
new.moderation_revision := old.moderation_revision + 1;
new.moderation_status := 'pending';
new.ai_toxicity_score := null;
new.moderation_reason := null;
new.reviewed_by := null;
new.reviewed_at := null;
new.published_at := null;

-- Comment content changed by a member: apply the same reset.
-- Post image insert/update/delete: increment the owning post revision and
-- apply the same reset through invalidate_post_image_moderation().
```

For authenticated direct writes, reject attempts to set `approved`, `rejected`,
AI score, reason, reviewer, review time, publication time, or revision. Preserve
the existing author-owned `removed` transition used for deleting content.
Service-role RPC calls may set authority fields.

- [ ] **Step 5: Add transactional service-role RPCs**

Implement and revoke-by-default these signatures:

```sql
public.prepare_content_moderation(
  p_target_type text,
  p_target_id uuid,
  p_owner_id uuid
) returns public.content_moderation_cases

public.apply_ai_moderation_result(
  p_case_id uuid,
  p_expected_revision integer,
  p_claim_token uuid,
  p_case_state text,
  p_overall_risk_score numeric,
  p_category_scores jsonb,
  p_evidence jsonb,
  p_user_reason text,
  p_model text,
  p_prompt_version text,
  p_attempt_count integer
) returns public.content_moderation_cases

public.mark_content_moderation_failed(
  p_case_id uuid,
  p_expected_revision integer,
  p_claim_token uuid,
  p_failure_code text,
  p_failure_message text,
  p_attempt_count integer
) returns public.content_moderation_cases
```

`prepare_content_moderation` must lock the target, verify `owner_id`, reuse a
completed case, return an already-processing case while its 30-second lease is
live, reclaim an expired processing case with a new random claim token, enforce
a 15-second retry cooldown for a failed case, and change a retryable failed case
back to `processing` with a new claim token. `apply_ai_moderation_result` and
`mark_content_moderation_failed` must require the current claim token. They
reject a late result from an expired/reclaimed invocation. Result application
also locks the target, marks a stale revision `superseded`, normalizes the
target's legacy `ai_toxicity_score` to score divided by 100, and sets target
status from case state. `admin_review` maps to target `pending`.

Grant only these functions to the backend role:

```sql
revoke all on function public.prepare_content_moderation(text, uuid, uuid) from public, anon, authenticated;
grant execute on function public.prepare_content_moderation(text, uuid, uuid) to service_role;
```

Apply equivalent revoke/grant statements to the other service-role functions.

- [ ] **Step 6: Add the administrator decision RPC and RLS**

Implement this in `ai_moderation.sql` after the already-applied
`admin_portal.sql` contract:

```sql
public.decide_content_moderation_case(
  p_case_id uuid,
  p_decision text,
  p_reason text default ''
) returns public.content_moderation_cases
```

It must resolve the current active admin from `auth.uid()`, lock the case and
target, require case state `admin_review`, require `approved` or `rejected`,
require 10-to-500 characters for rejection, reject stale revisions, update the
target and case atomically, and insert `admin_action_audit` with action type
`ai_content_approved` or `ai_content_rejected`.

Enable RLS on `content_moderation_cases`. Add SELECT policies for the owner and
active administrators. Revoke direct INSERT/UPDATE/DELETE from `authenticated`.
Grant administrator RPC execution to `authenticated` because the function
performs its own active-admin check.

- [ ] **Step 7: Run SQL contract tests**

Run: `cd services/api; npx tsx --test src/moderation/moderationSql.test.ts src/admin/adminSql.test.ts`

Expected: both SQL contract suites PASS.

- [ ] **Step 8: Commit**

```powershell
git add -- supabase/schema.sql supabase/ai_moderation.sql services/api/src/moderation/moderationSql.test.ts services/api/src/all.test.ts
git commit -m "feat: add revisioned moderation database authority"
```

---

### Task 3: Build the Gemini Adapter and Threshold Contract

**Files:**
- Create: `services/api/src/moderation/moderationTypes.ts`
- Create: `services/api/src/moderation/moderationSchemas.ts`
- Create: `services/api/src/moderation/geminiModerationGateway.ts`
- Create: `services/api/src/moderation/geminiModerationGateway.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing adapter tests**

Use an injected `createInteraction` function so tests never call Google:

```ts
test('sends title, body, tags, and every trusted image URL', async () => {
  const calls: unknown[] = [];
  const gateway = createGeminiModerationGateway({
    model: 'gemini-test',
    timeoutMs: 8500,
    createInteraction: async (input) => {
      calls.push(input);
      return { outputText: safeJson };
    },
  });

  const result = await gateway.moderate({
    targetType: 'post',
    title: 'Science project',
    content: 'Testing clean water samples.',
    tags: ['science', 'school'],
    images: [
      { uri: 'https://project.supabase.co/storage/v1/object/public/images/a.jpg', mimeType: 'image/jpeg' },
      { uri: 'https://project.supabase.co/storage/v1/object/public/images/b.png', mimeType: 'image/png' },
    ],
  });

  assert.equal(result.overallRiskScore, 12);
  assert.equal((calls[0] as { input: unknown[] }).input.length, 3);
});

test('rejects malformed structured output instead of approving it', async () => {
  const gateway = createGatewayReturning('{"overallRiskScore": -1}');
  await assert.rejects(() => gateway.moderate(commentTarget), ModerationProviderError);
});

test('maps an explicit input safety block to risk 100', async () => {
  const gateway = createGatewayThrowing(
    new GeminiInputSafetyError(['HARM_CATEGORY_HARASSMENT: HIGH']),
  );
  const result = await gateway.moderate(commentTarget);
  assert.equal(result.overallRiskScore, 100);
  assert.equal(result.evidenceSource, 'text');
});
```

Also test comment input has no image entries and all seven category scores are
required within 0 through 100.

- [ ] **Step 2: Run the adapter tests and verify they fail**

Run: `cd services/api; npx tsx --test src/moderation/geminiModerationGateway.test.ts`

Expected: FAIL because the moderation adapter does not exist.

- [ ] **Step 3: Define CyanZone-owned contracts and schema**

Define these stable types independently of Google SDK types:

```ts
export type ModerationTarget = {
  targetType: 'post' | 'comment';
  title: string | null;
  content: string;
  tags: string[];
  images: Array<{ uri: string; mimeType: SupportedImageMimeType }>;
};

export type ModerationProviderResult = {
  overallRiskScore: number;
  categoryScores: Record<ModerationCategory, number>;
  evidence: string[];
  userReason: string;
  evidenceSource: 'text' | 'image' | 'both';
  model: string;
  promptVersion: 'cyanzone-moderation-v1';
};

export interface ModerationProvider {
  moderate(target: ModerationTarget): Promise<ModerationProviderResult>;
}

export type ModerationDecision = 'approved' | 'admin_review' | 'rejected';

export function decideModeration(score: number): ModerationDecision {
  if (score < 40) return 'approved';
  if (score <= 60) return 'admin_review';
  return 'rejected';
}
```

Use Zod to require finite scores from 0 through 100, one through five concise
evidence strings, a 1-to-300-character user reason, and the exact category keys
`harassmentBullying`, `hate`, `sexual`, `violenceDanger`, `selfHarm`,
`spamScam`, and `privacyExposure`.

- [ ] **Step 4: Implement the Google GenAI adapter**

Construct GoogleGenAI with SDK retries disabled so the service owns the exact
two-attempt policy:

```ts
const client = new GoogleGenAI({
  apiKey,
  httpOptions: {
    timeout: timeoutMs,
    retryOptions: { attempts: 1 },
  },
});
```

Build one text input containing the versioned moderation instruction, title,
body, and tags, followed by every image:

```ts
const input = [
  { type: 'text', text: buildModerationPrompt(target) },
  ...target.images.map((image) => ({
    type: 'image' as const,
    uri: image.uri,
    mime_type: image.mimeType,
  })),
];

const interaction = await client.interactions.create({
  model,
  input,
  response_format: {
    type: 'text',
    mime_type: 'application/json',
    schema: moderationResultJsonSchema,
  },
  generation_config: { thinking_level: 'minimal' },
});
```

Parse `interaction.output_text` with JSON then Zod. Convert provider timeout,
429, and 5xx errors to retryable `ModerationProviderError`; convert invalid
schema and unsupported responses to non-retryable errors. Convert explicit
input safety feedback to the deterministic risk-100 result.

- [ ] **Step 5: Run the focused adapter tests and type-check**

Run: `cd services/api; npx tsx --test src/moderation/geminiModerationGateway.test.ts; npm run typecheck`

Expected: adapter tests PASS and TypeScript reports no errors.

- [ ] **Step 6: Commit**

```powershell
git add -- services/api/src/moderation/moderationTypes.ts services/api/src/moderation/moderationSchemas.ts services/api/src/moderation/geminiModerationGateway.ts services/api/src/moderation/geminiModerationGateway.test.ts services/api/src/all.test.ts
git commit -m "feat: add structured Gemini moderation adapter"
```

---

### Task 4: Add Member Authentication and the Supabase Moderation Repository

**Files:**
- Create: `services/api/src/moderation/moderationAuth.ts`
- Create: `services/api/src/moderation/moderationAuth.test.ts`
- Create: `services/api/src/moderation/moderationRepository.ts`
- Create: `services/api/src/moderation/moderationRepository.test.ts`
- Modify: `services/api/src/moderation/moderationTypes.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing member-authentication tests**

Test missing/invalid bearer tokens, suspended profiles, missing profiles, and a
successful active member:

```ts
test('active member middleware exposes only the verified identity', async () => {
  const verifyMember = createVerifyMember({
    getUser: async () => ({ id: 'member-1', email: 'member@cyanzone.test' }),
    getProfile: async () => ({ id: 'member-1', accountStatus: 'active', isAdmin: false }),
  });
  await assert.doesNotReject(() => verifyMember('valid-token'));
});

test('suspended members cannot request moderation', async () => {
  const verifyMember = createVerifyMember(suspendedSource);
  await assert.rejects(() => verifyMember('valid-token'), MemberAuthorizationError);
});
```

- [ ] **Step 2: Write failing repository tests**

Use a small fake Supabase client to prove the repository:

- reads post title/content/tags/revision/owner and ordered images;
- reconstructs image URLs from the `images` bucket and `storage_path` instead
  of accepting client URLs;
- uses stored MIME type or supported extension inference;
- reads comment content/revision/owner with no images;
- calls `prepare_content_moderation`, `apply_ai_moderation_result`, and
  `mark_content_moderation_failed` with exact parameters;
- rejects an unsupported image extension before provider invocation.

Core assertion:

```ts
assert.deepEqual(target.images, [{
  uri: 'https://project.supabase.co/storage/v1/object/public/images/member-1/post-1/a.jpg',
  mimeType: 'image/jpeg',
}]);
assert.equal(rpcCalls[0].name, 'prepare_content_moderation');
assert.equal(rpcCalls[0].args.p_owner_id, 'member-1');
```

- [ ] **Step 3: Run both tests and verify they fail**

Run: `cd services/api; npx tsx --test src/moderation/moderationAuth.test.ts src/moderation/moderationRepository.test.ts`

Expected: FAIL because member authentication and repository files do not exist.

- [ ] **Step 4: Implement active-member authentication**

Mirror the existing administrator bearer parser but expose:

```ts
export type MemberIdentity = { id: string; email: string | null };
export type VerifyMember = (token: string) => Promise<MemberIdentity>;
export function requireMember(verifyMember: VerifyMember): RequestHandler;
```

Require a valid Supabase Auth user, an existing profile, `account_status =
'active'`, and `is_admin = false`. Return 401 for missing/invalid sessions and
403 for inactive/non-member identities.

- [ ] **Step 5: Implement the repository adapter**

Define the repository interface:

```ts
export interface ModerationRepository {
  loadTarget(type: 'post' | 'comment', id: string): Promise<ModerationTargetRecord | null>;
  prepare(type: 'post' | 'comment', id: string, ownerId: string): Promise<ModerationCase>;
  applyResult(caseId: string, revision: number, result: PersistedModerationResult): Promise<ModerationCase>;
  markFailed(caseId: string, revision: number, failure: PersistedModerationFailure): Promise<ModerationCase>;
}
```

Use the service-role Supabase client only after member verification. Infer MIME
types exactly as follows:

```ts
const mimeByExtension = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
} as const;
```

Reconstruct each URI with `client.storage.from('images').getPublicUrl(storagePath).data.publicUrl`.

- [ ] **Step 6: Run the focused tests**

Run: `cd services/api; npx tsx --test src/moderation/moderationAuth.test.ts src/moderation/moderationRepository.test.ts`

Expected: both suites PASS.

- [ ] **Step 7: Commit**

```powershell
git add -- services/api/src/moderation/moderationAuth.ts services/api/src/moderation/moderationAuth.test.ts services/api/src/moderation/moderationRepository.ts services/api/src/moderation/moderationRepository.test.ts services/api/src/moderation/moderationTypes.ts services/api/src/all.test.ts
git commit -m "feat: add authenticated moderation repository"
```

---

### Task 5: Expose Idempotent Member Moderation Endpoints

**Files:**
- Create: `services/api/src/moderation/moderationService.ts`
- Create: `services/api/src/moderation/moderationService.test.ts`
- Create: `services/api/src/moderation/moderationRouter.ts`
- Create: `services/api/src/moderation/moderationRouter.test.ts`
- Modify: `services/api/src/app.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write failing service threshold and retry tests**

Cover scores 39.99, 40, 60, and 60.01; completed-case reuse; processing-case
reuse during a live lease; expired-lease reclaim; rejection of an old claim
token; one retry; permanent failure; second transient failure; safety-block
risk 100; and stale/superseded results.

```ts
for (const [score, expected] of [
  [39.99, 'approved'],
  [40, 'admin_review'],
  [60, 'admin_review'],
  [60.01, 'rejected'],
] as const) {
  test(`score ${score} becomes ${expected}`, async () => {
    provider.moderate = async () => providerResult(score);
    const response = await service.moderatePost('post-1', member);
    assert.equal(response.caseState, expected);
  });
}

test('retries one transient failure and never creates a second case', async () => {
  provider.moderate = sequence([
    Promise.reject(new ModerationProviderError('timeout', true)),
    Promise.resolve(providerResult(10)),
  ]);
  const response = await service.moderatePost('post-1', member);
  assert.equal(response.status, 'approved');
  assert.equal(providerCalls, 2);
  assert.equal(prepareCalls, 1);
});
```

- [ ] **Step 2: Write failing router tests**

Mount the router in `createApp` with a fake member and fake service. Assert:

```ts
await request(app).post('/moderation/posts/post-1').expect(401);

const response = await request(app)
  .post('/moderation/comments/comment-1')
  .set('Authorization', 'Bearer member-token')
  .expect(200);
assert.equal(response.body.targetId, 'comment-1');

await request(cooldownApp)
  .post('/moderation/posts/post-1')
  .set('Authorization', 'Bearer member-token')
  .expect(429);
```

Also assert 403 ownership, 404 target, 409 stale/superseded, 503 provider
failure with `retryAllowed: true`, and no provider/database details in 500.

- [ ] **Step 3: Run service and router tests and verify they fail**

Run: `cd services/api; npx tsx --test src/moderation/moderationService.test.ts src/moderation/moderationRouter.test.ts`

Expected: FAIL because service and router files do not exist.

- [ ] **Step 4: Implement the service state machine**

Return a stable response:

```ts
export type ModerationResponse = {
  targetType: 'post' | 'comment';
  targetId: string;
  moderationRevision: number;
  status: 'pending' | 'approved' | 'rejected';
  caseState: 'processing' | 'admin_review' | 'approved' | 'rejected' | 'failed' | 'superseded';
  riskScore: number | null;
  reason: string | null;
  retryAllowed: boolean;
};
```

The service order is fixed: load target, verify owner, prepare case, return
stored terminal/processing cases, call provider at most twice, derive the
decision with `decideModeration`, apply the result, or mark failure. Retry only
retryable provider errors. Pass the preparation claim token to every completion
or failure call. Use a total attempt count of 1 or 2 in persistence.

- [ ] **Step 5: Implement and mount the member router**

Create:

```ts
router.post('/posts/:postId', handle((req, member) =>
  service.moderate('post', req.params.postId, member),
));
router.post('/comments/:commentId', handle((req, member) =>
  service.moderate('comment', req.params.commentId, member),
));
```

Add `moderationRouter: Router` to `AppDependencies` and mount it before the
fallback handler:

```ts
app.use('/moderation', dependencies.moderationRouter);
```

Update existing API test dependency builders to supply `Router()` so unrelated
admin tests remain isolated.

- [ ] **Step 6: Run focused API tests and type-check**

Run: `cd services/api; npx tsx --test src/moderation/moderationService.test.ts src/moderation/moderationRouter.test.ts src/admin/adminRouter.test.ts; npm run typecheck`

Expected: all selected suites PASS and TypeScript reports no errors.

- [ ] **Step 7: Commit**

```powershell
git add -- services/api/src/moderation/moderationService.ts services/api/src/moderation/moderationService.test.ts services/api/src/moderation/moderationRouter.ts services/api/src/moderation/moderationRouter.test.ts services/api/src/app.ts services/api/src/all.test.ts services/api/src/admin/adminRouter.test.ts services/api/src/admin/adminAuth.test.ts
git commit -m "feat: expose member moderation endpoints"
```

---

### Task 6: Replace the Admin Moderation Backend Placeholder

**Files:**
- Modify: `services/api/src/admin/adminTypes.ts`
- Modify: `services/api/src/admin/adminSchemas.ts`
- Modify: `services/api/src/admin/adminRepository.ts`
- Modify: `services/api/src/admin/adminService.ts`
- Modify: `services/api/src/admin/adminRouter.ts`
- Modify: `services/api/src/admin/adminRepository.test.ts`
- Modify: `services/api/src/admin/adminService.test.ts`
- Modify: `services/api/src/admin/adminRouter.test.ts`

- [ ] **Step 1: Write failing administrator moderation tests**

Add repository, service, and router tests for paginated pending/approved/rejected
lists, complete detail, decision validation, stale conflict, and authorization.

```ts
const response = await request(app)
  .get('/admin/moderation-cases?status=pending&page=1&pageSize=20')
  .set('Authorization', 'Bearer admin-token')
  .expect(200);
assert.equal(response.body.items[0].riskScore, 50);

await request(app)
  .post('/admin/moderation-cases/case-1/decision')
  .set('Authorization', 'Bearer admin-token')
  .send({ decision: 'rejected', reason: 'Bullying directed at another member.' })
  .expect(204);
```

Assert rejection under 10 characters is 400, approval accepts an empty reason,
non-`admin_review` decisions are 409, and repository calls
`decide_content_moderation_case`.

- [ ] **Step 2: Run affected admin API tests and verify they fail**

Run: `cd services/api; npx tsx --test src/admin/adminRepository.test.ts src/admin/adminService.test.ts src/admin/adminRouter.test.ts`

Expected: FAIL because the moderation operations are missing.

- [ ] **Step 3: Define admin moderation types and schemas**

Add:

```ts
export type AiModerationTab = 'pending' | 'approved' | 'rejected';
export type AiModerationCaseView = {
  id: string;
  targetType: 'post' | 'comment';
  targetId: string;
  moderationRevision: number;
  authorName: string;
  authorEmail: string;
  submittedAt: string;
  title: string | null;
  content: string;
  imageUrls: string[];
  riskScore: number;
  categoryScores: Record<string, number>;
  evidence: string[];
  userReason: string;
  model: string;
  status: AiModerationTab;
  decisionReason: string | null;
  decidedAt: string | null;
};
```

Map `pending` to database `admin_review`; completed AI/admin approvals and
rejections map to their matching tabs. Add a paginated query schema with
search, status, target type, page, and page size. Add a discriminated decision
schema: approval has optional empty-or-10-character reason; rejection requires
10-to-500 characters.

- [ ] **Step 4: Implement repository and service operations**

Extend `AdminRepository` and `AdminService` with:

```ts
listModerationCases(query: AiModerationListQuery): Promise<PageResult<AiModerationCaseView>>;
getModerationCase(caseId: string): Promise<AiModerationCaseView | null>;
decideModerationCase(caseId: string, input: AiModerationDecisionInput): Promise<void>;
```

Repository list/detail reads case, target, profile, and ordered image data and
maps it to the view. Decision invokes:

```ts
client.rpc('decide_content_moderation_case', {
  p_case_id: caseId,
  p_decision: input.decision,
  p_reason: input.reason,
});
```

Service converts missing rows to `AdminNotFoundError` and stale/non-reviewable
decisions to `AdminConflictError`.

- [ ] **Step 5: Add protected admin routes**

```ts
router.get('/moderation-cases', listModerationCasesHandler);
router.get('/moderation-cases/:caseId', getModerationCaseHandler);
router.post('/moderation-cases/:caseId/decision', decideModerationCaseHandler);
```

Use the existing `sendAdminError` mapping and return 204 only after the RPC
succeeds.

- [ ] **Step 6: Run the selected admin API suites and type-check**

Run: `cd services/api; npx tsx --test src/admin/adminRepository.test.ts src/admin/adminService.test.ts src/admin/adminRouter.test.ts; npm run typecheck`

Expected: all selected tests PASS and TypeScript reports no errors.

- [ ] **Step 7: Commit**

```powershell
git add -- services/api/src/admin/adminTypes.ts services/api/src/admin/adminSchemas.ts services/api/src/admin/adminRepository.ts services/api/src/admin/adminService.ts services/api/src/admin/adminRouter.ts services/api/src/admin/adminRepository.test.ts services/api/src/admin/adminService.test.ts services/api/src/admin/adminRouter.test.ts
git commit -m "feat: add real admin moderation case API"
```

---

### Task 7: Compose a Local and Vercel-Compatible API Entry Point

**Files:**
- Create: `services/api/src/index.ts`
- Modify: `services/api/src/server.ts`
- Modify: `services/api/src/app.ts`
- Create: `services/api/src/index.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] **Step 1: Write a failing composition test**

Import the default application only after supplying test environment variables,
then verify health and missing-key moderation behavior:

```ts
test('default API export is a Vercel-compatible Express application', async () => {
  const { default: app } = await import('./index.js');
  await request(app).get('/health').expect(200);
});
```

Keep external Gemini and Supabase operations behind injected composition seams
so this test does not call the network.

- [ ] **Step 2: Run the test and verify it fails**

Run: `cd services/api; npx tsx --test src/index.test.ts`

Expected: FAIL because `src/index.ts` does not exist.

- [ ] **Step 3: Move composition out of the local listener**

`src/index.ts` must construct member/admin auth sources, repositories, the
Gemini gateway, both protected routers, and `createApp`, then finish with:

```ts
export default app;
```

If `GEMINI_API_KEY` is absent, inject a provider whose `moderate` operation
throws a safe retryable `ModerationProviderError('provider_unconfigured',
true)`; do not crash `/health` or administrator bootstrap.

Reduce `src/server.ts` to:

```ts
import app from './index.js';
import { env } from './config/env.js';

app.listen(env.PORT, () => {
  console.log(`CyanZone API listening on port ${env.PORT}`);
});
```

- [ ] **Step 4: Verify local and Vercel entry behavior**

Run: `cd services/api; npx tsx --test src/index.test.ts; npm run build`

Expected: composition test PASS and the production TypeScript build succeeds.

- [ ] **Step 5: Commit**

```powershell
git add -- services/api/src/index.ts services/api/src/index.test.ts services/api/src/server.ts services/api/src/app.ts services/api/src/all.test.ts
git commit -m "refactor: add deployable API composition root"
```

---

### Task 8: Add the Authenticated Flutter Moderation Gateway

**Files:**
- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/pubspec.lock`
- Modify: `apps/mobile/.env.example`
- Create: `apps/mobile/lib/src/core/config/api_config.dart`
- Create: `apps/mobile/lib/src/features/posts/domain/content_moderation.dart`
- Create: `apps/mobile/lib/src/features/posts/data/http_content_moderation_gateway.dart`
- Create: `apps/mobile/lib/src/features/posts/presentation/content_moderation_scope.dart`
- Modify: `apps/mobile/lib/src/app_dependencies.dart`
- Modify: `apps/mobile/lib/src/app.dart`
- Modify: `apps/mobile/test/widget_test.dart`
- Create: `apps/mobile/test/http_content_moderation_gateway_test.dart`
- Create: `apps/mobile/test/content_moderation_scope_test.dart`

- [ ] **Step 1: Declare the HTTP dependency**

Run: `cd apps/mobile; flutter pub add http`

Expected: `http` appears under direct dependencies and the lockfile updates.

- [ ] **Step 2: Write failing gateway tests**

Use `package:http/testing.dart` and an injected token reader:

```dart
test('posts the existing target id with the Supabase bearer token', () async {
  late http.Request captured;
  final gateway = HttpContentModerationGateway(
    baseUrl: Uri.parse('https://api.cyanzone.test'),
    accessToken: () async => 'member-token',
    client: MockClient((request) async {
      captured = request;
      return http.Response(successBody, 200);
    }),
  );

  final result = await gateway.moderatePost('post-1');
  expect(captured.url.path, '/moderation/posts/post-1');
  expect(captured.headers['authorization'], 'Bearer member-token');
  expect(result.state, ContentModerationState.approved);
});
```

Add tests for admin review, rejection, 503 retry allowed, 429 cooldown, missing
session, invalid body, and transport failure. Assert no Gemini key exists in
request bodies or mobile config.

- [ ] **Step 3: Run the gateway test and verify it fails**

Run: `cd apps/mobile; flutter test test/http_content_moderation_gateway_test.dart --reporter compact`

Expected: FAIL because the gateway and domain contract do not exist.

- [ ] **Step 4: Implement the mobile domain and HTTP adapter**

Define:

```dart
enum ContentModerationState {
  processing,
  adminReview,
  approved,
  rejected,
  failed,
  superseded,
}

final class ContentModerationResult {
  const ContentModerationResult({
    required this.targetId,
    required this.revision,
    required this.state,
    required this.riskScore,
    required this.reason,
    required this.retryAllowed,
  });
  final String targetId;
  final int revision;
  final ContentModerationState state;
  final double? riskScore;
  final String? reason;
  final bool retryAllowed;
}

abstract interface class ContentModerationGateway {
  Future<ContentModerationResult> moderatePost(String postId);
  Future<ContentModerationResult> moderateComment(String commentId);
}
```

Map stable API errors to `ContentModerationFailure` with safe messages. Read
`API_BASE_URL` through `ApiConfig`; reject missing/invalid URLs during production
composition with a clear startup configuration error.

- [ ] **Step 5: Compose and expose the gateway**

Add `contentModerationGateway` to `AppDependencies.production`, using the
current Supabase session token and `ApiConfig.baseUrl`. Wrap `MaterialApp` in:

```dart
ContentModerationScope(
  gateway: dependencies.contentModerationGateway,
  child: MaterialApp(
    title: 'CyanZone',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: AuthGate(
      authGateway: dependencies.authGateway,
      pendingRegistrationStore: dependencies.pendingRegistrationStore,
    ),
  ),
)
```

Tests construct `AppDependencies` with a fake gateway and verify descendants
resolve the same instance. Update `test/widget_test.dart` to supply the new
required dependency so the application smoke test continues to compile.

- [ ] **Step 6: Run gateway/scope tests and scoped analysis**

Run: `cd apps/mobile; flutter test test/http_content_moderation_gateway_test.dart test/content_moderation_scope_test.dart --reporter compact; flutter analyze lib/src/core/config/api_config.dart lib/src/features/posts/domain/content_moderation.dart lib/src/features/posts/data/http_content_moderation_gateway.dart lib/src/features/posts/presentation/content_moderation_scope.dart lib/src/app_dependencies.dart lib/src/app.dart`

Expected: tests PASS and scoped analysis reports no issues.

- [ ] **Step 7: Commit**

```powershell
git add -- apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/.env.example apps/mobile/lib/src/core/config/api_config.dart apps/mobile/lib/src/features/posts/domain/content_moderation.dart apps/mobile/lib/src/features/posts/data/http_content_moderation_gateway.dart apps/mobile/lib/src/features/posts/presentation/content_moderation_scope.dart apps/mobile/lib/src/app_dependencies.dart apps/mobile/lib/src/app.dart apps/mobile/test/http_content_moderation_gateway_test.dart apps/mobile/test/content_moderation_scope_test.dart
git commit -m "feat: add mobile moderation API gateway"
```

---

### Task 9: Moderate New Posts, Edited Posts, and Comments in Mobile

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/data/posts_repository.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_submission_error.dart`
- Modify: `apps/mobile/test/posts_repository_test.dart`
- Create: `apps/mobile/lib/src/features/posts/domain/post_submission_repository.dart`
- Create: `apps/mobile/test/post_moderation_submission_test.dart`
- Create: `apps/mobile/test/comment_moderation_submission_test.dart`

- [ ] **Step 1: Write failing repository contract tests**

Replace brittle source expectations with explicit assertions that:

- `createPost` returns the inserted post ID;
- `updatePost` returns the existing ID;
- `createComment` uses `.select('id').single()` and returns the comment ID;
- post image rows contain `mime_type`;
- mobile no longer writes `approved`, `rejected`, score, reviewer, or review time;
- editing sends only content fields and lets database triggers invalidate the
  previous moderation revision.

Create the narrow persistence boundary and make `PostsRepository` implement it:

```dart
abstract interface class PostSubmissionRepository {
  Future<String> createPost(CreatePostInput input);
  Future<String> updatePost(String postId, UpdatePostInput input);
  Future<String> createComment(
    String postId,
    String content, {
    String? parentCommentId,
    String? taggedUserId,
    String? taggedUserName,
  });
}
```

`CreatePostPage` and `PostDetailPage` accept an optional
`PostSubmissionRepository` for tests and default to `PostsRepository` in
production. This avoids faking unrelated feed, profile, reporting, and reaction
methods.

- [ ] **Step 2: Write failing post submission widget tests**

Inject fake repository operations and wrap the page in a fake
`ContentModerationScope`. Cover:

```dart
expect(find.text('Post published'), findsOneWidget);            // approved
expect(find.text('Sent for administrator review'), findsOneWidget); // 40-60
expect(find.textContaining('Post was not published'), findsOneWidget); // rejected
expect(find.text('Retry moderation'), findsOneWidget);          // failed
```

Tap `Retry moderation` and assert the gateway receives the same `post-1` once
more while repository create/update counts remain one.

- [ ] **Step 3: Write failing comment submission widget tests**

Cover approved, admin review, rejected, and failed states. A failed comment
keeps its returned comment ID in the page state and exposes a SnackBar action
`Retry moderation`; tapping it must call `moderateComment(comment-1)` without
another insert. Do not increment or refresh the public comment count before an
approved result.

- [ ] **Step 4: Run the selected mobile tests and verify they fail**

Run: `cd apps/mobile; flutter test test/posts_repository_test.dart test/post_moderation_submission_test.dart test/comment_moderation_submission_test.dart --reporter compact`

Expected: FAIL because repositories return void and presentation does not call the gateway.

- [ ] **Step 5: Return IDs and record image MIME types**

For inserts:

```dart
final comment = await _client
    .from('comments')
    .insert(commentValues)
    .select('id')
    .single();
return comment['id'] as String;
```

Return `postId` after image rows complete and return the supplied `postId` after
an update. Add `'mime_type': image.contentType` to every post image row. Remove
manual update fields `moderation_status`, `moderation_reason`, `reviewed_by`, and
`reviewed_at`; the SQL invalidation trigger owns them.

- [ ] **Step 6: Coordinate post moderation outcomes**

After persistence, call the gateway with the returned ID and map states:

```dart
final moderation = await gateway.moderatePost(postId);
switch (moderation.state) {
  case ContentModerationState.approved:
    showSuccess('Post published');
  case ContentModerationState.adminReview:
    showSuccess('Sent for administrator review');
  case ContentModerationState.rejected:
    showModerationError(moderation.reason ?? 'Post was not published.');
  case ContentModerationState.failed:
    showRetry(postId, () => gateway.moderatePost(postId));
  case ContentModerationState.processing:
    showSuccess('Moderation is still processing.');
  case ContentModerationState.superseded:
    showModerationError('This post changed. Submit the latest version again.');
}
```

Clear the form after persistence because the draft now exists remotely, but
retain the record ID for the retry action. Never create a second post during a
retry.

- [ ] **Step 7: Coordinate comment moderation outcomes**

Insert first, then moderate its ID. Refresh comments and counts only after
approval. For admin review say `Comment sent for administrator review.` For
rejection show the safe reason. For provider failure show a SnackBar with the
same-ID retry action. Keep direct/group chat unchanged.

- [ ] **Step 8: Run affected mobile tests and scoped analysis**

Run: `cd apps/mobile; flutter test test/posts_repository_test.dart test/post_moderation_submission_test.dart test/comment_moderation_submission_test.dart test/post_submission_error_test.dart --reporter compact; flutter analyze lib/src/features/posts/data/posts_repository.dart lib/src/features/posts/presentation/create_post_page.dart lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_submission_error.dart`

Expected: selected tests PASS and scoped analysis reports no issues.

- [ ] **Step 9: Commit**

```powershell
git add -- apps/mobile/lib/src/features/posts/data/posts_repository.dart apps/mobile/lib/src/features/posts/presentation/create_post_page.dart apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart apps/mobile/lib/src/features/posts/presentation/post_submission_error.dart apps/mobile/test/posts_repository_test.dart apps/mobile/test/post_moderation_submission_test.dart apps/mobile/test/comment_moderation_submission_test.dart
git commit -m "feat: moderate mobile posts and comments"
```

---

### Task 10: Connect the Admin AI Page to Real Cases

**Files:**
- Delete: `apps/admin/src/features/aiFlagged/aiFlaggedMockData.ts`
- Delete: `apps/admin/src/features/aiFlagged/aiFlaggedMockAdapter.ts`
- Modify: `apps/admin/src/features/aiFlagged/aiFlaggedTypes.ts`
- Create: `apps/admin/src/features/aiFlagged/aiFlaggedApi.ts`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.tsx`
- Modify: `apps/admin/src/features/aiFlagged/AiFlaggedContentPage.test.tsx`

- [ ] **Step 1: Replace mock tests with failing API-backed tests**

Mock `adminApi.get` and `adminApi.post`, not global static data. Assert initial
load, tab reload, loading/error/empty states, genuine evidence/images/model,
decision confirmation, and refresh after success:

```ts
vi.mock('../../lib/adminApi', () => ({
  adminApi: {
    get: vi.fn(),
    post: vi.fn(),
  },
}));

expect(adminApi.get).toHaveBeenCalledWith('/admin/moderation-cases', {
  status: 'pending',
  page: 1,
  pageSize: 20,
});

await user.click(screen.getByRole('button', { name: 'Approve content' }));
await user.click(screen.getByRole('button', { name: 'Confirm approval' }));
expect(adminApi.post).toHaveBeenCalledWith(
  '/admin/moderation-cases/case-1/decision',
  { decision: 'approved', reason: '' },
);
```

Retain the existing 10-to-500-character rejection test and add retry after list
failure.

- [ ] **Step 2: Run the page tests and verify they fail**

Run: `cd apps/admin; npm test -- --run src/features/aiFlagged/AiFlaggedContentPage.test.tsx`

Expected: FAIL because the page still uses mock data and makes no API calls.

- [ ] **Step 3: Define the real view contract and API adapter**

Use risk scores in percentage units:

```ts
export type AiFlaggedCase = {
  id: string;
  targetType: 'post' | 'comment';
  targetId: string;
  moderationRevision: number;
  authorName: string;
  authorEmail: string;
  submittedAt: string;
  title: string | null;
  content: string;
  imageUrls: string[];
  riskScore: number;
  categoryScores: Record<string, number>;
  evidence: string[];
  userReason: string;
  model: string;
  status: 'pending' | 'approved' | 'rejected';
  decisionReason: string | null;
  decidedAt: string | null;
};
```

`aiFlaggedApi.ts` exports:

```ts
export const listAiFlaggedCases = (status: AiFlaggedStatus) =>
  adminApi.get<PageResult<AiFlaggedCase>>('/admin/moderation-cases', {
    status,
    page: 1,
    pageSize: 20,
  });

export const decideAiFlaggedCase = (
  id: string,
  decision: 'approved' | 'rejected',
  reason: string,
) => adminApi.post<void>(`/admin/moderation-cases/${id}/decision`, {
  decision,
  reason,
});
```

- [ ] **Step 4: Implement asynchronous page behavior**

Load the active tab in an effect with cancellation protection. Use
`AsyncState` for loading, safe API error, and empty results. Disable decision
controls while submitting, call the real decision endpoint after confirmation,
show `Decision saved.`, then reload the active tab.

Change list score rendering to `${Math.round(item.riskScore)}%` and detail to
`${selected.riskScore.toFixed(1)}%`. Render category scores, model, revision,
evidence, and every post image. Completed tabs remain read-only.

- [ ] **Step 5: Delete the mock adapter and data**

Remove both files and verify no maintained source imports them:

Run: `rg -n "aiFlaggedMock|loadAiFlaggedPreview|decideAiFlaggedPreview" apps/admin/src`

Expected: no matches.

- [ ] **Step 6: Run affected Admin Portal verification**

Run: `cd apps/admin; npm test -- --run src/features/aiFlagged/AiFlaggedContentPage.test.tsx src/lib/adminApi.test.ts; npm run typecheck; npm run build`

Expected: selected tests PASS, type-check passes, and Vite production build succeeds.

- [ ] **Step 7: Commit**

```powershell
git add -A -- apps/admin/src/features/aiFlagged
git commit -m "feat: connect admin AI moderation queue"
```

---

### Task 11: Document Setup and Perform Affected-Feature Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/setup.md`
- Modify: `Project_Overview.md`
- Modify: `supabase/README.md`

- [ ] **Step 1: Update configuration and manual SQL documentation**

Document the local API environment:

```dotenv
PORT=4000
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
ADMIN_BOOTSTRAP_SECRET=replace-with-long-random-secret
REPORT_REVIEW_THRESHOLD=1
GEMINI_API_KEY=your-google-ai-studio-key
GEMINI_MODEL=gemini-3.8-flash
GEMINI_TIMEOUT_MS=8500
```

Document mobile:

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
API_BASE_URL=http://10.0.2.2:4000
```

Explain that Android Emulator uses `10.0.2.2`, a physical phone uses the
computer's LAN IP while both are on the same network, and production uses the
Vercel HTTPS URL.

- [ ] **Step 2: Add exact Supabase rollout and verification instructions**

Place `ai_moderation.sql` immediately after `admin_portal.sql` in the maintained
existing-project order because its administrator decision function writes
`admin_action_audit`. Tell the operator to run the complete file in Supabase SQL
Editor and inspect any error. Existing projects that already ran
`admin_portal.sql` need to run only the new `ai_moderation.sql` file.

Add verification queries:

```sql
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('posts', 'comments', 'post_images', 'content_moderation_cases')
order by table_name, ordinal_position;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'prepare_content_moderation',
    'apply_ai_moderation_result',
    'mark_content_moderation_failed',
    'decide_content_moderation_case'
  )
order by routine_name;
```

- [ ] **Step 3: Document Vercel deployment**

Record these dashboard steps:

1. Import the GitHub repository into Vercel.
2. Set Root Directory to `services/api`.
3. Let Vercel detect Express; do not configure a static output directory.
4. Add all API environment values for Preview and Production.
5. Deploy and open `https://<deployment>/health`.
6. Put that origin in Admin `VITE_API_BASE_URL` and mobile `API_BASE_URL`.
7. Redeploy Admin and rebuild Flutter after changing their environment files.

No secrets are copied to Flutter, React source, Git, or Supabase public config.

- [ ] **Step 4: Update canonical project status**

Change Gemini moderation from planned/mock to implemented, describe current
coverage and retry behavior, state that chat remains excluded, state that the
live SQL and real-key checks still require the manual rollout, and keep FCM as
the next phase.

- [ ] **Step 5: Run the affected API verification**

Run: `cd services/api; npx tsx --test src/config/env.test.ts src/moderation/geminiModerationGateway.test.ts src/moderation/moderationAuth.test.ts src/moderation/moderationRepository.test.ts src/moderation/moderationService.test.ts src/moderation/moderationRouter.test.ts src/moderation/moderationSql.test.ts src/admin/adminRepository.test.ts src/admin/adminService.test.ts src/admin/adminRouter.test.ts src/admin/adminSql.test.ts src/index.test.ts; npm run typecheck; npm run build`

Expected: selected API tests PASS, type-check passes, and build succeeds.

- [ ] **Step 6: Run the affected mobile verification**

Run: `cd apps/mobile; flutter test test/http_content_moderation_gateway_test.dart test/content_moderation_scope_test.dart test/posts_repository_test.dart test/post_moderation_submission_test.dart test/comment_moderation_submission_test.dart test/post_submission_error_test.dart --reporter compact; flutter analyze lib/src/core/config/api_config.dart lib/src/app_dependencies.dart lib/src/app.dart lib/src/features/posts/domain/content_moderation.dart lib/src/features/posts/data/http_content_moderation_gateway.dart lib/src/features/posts/data/posts_repository.dart lib/src/features/posts/presentation/content_moderation_scope.dart lib/src/features/posts/presentation/create_post_page.dart lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_submission_error.dart`

Expected: selected Flutter tests PASS and scoped analysis reports no issues.

- [ ] **Step 7: Run the affected Admin Portal verification**

Run: `cd apps/admin; npm test -- --run src/features/aiFlagged/AiFlaggedContentPage.test.tsx src/lib/adminApi.test.ts; npm run typecheck; npm run build`

Expected: selected Admin tests PASS, type-check passes, and build succeeds.

- [ ] **Step 8: Perform local real-provider smoke tests**

With a non-production Gemini key and local API running, verify these five cases
against dedicated test accounts/content:

1. Safe text publishes.
2. An intentionally ambiguous test fixture enters administrator review.
3. A clearly policy-violating synthetic fixture is rejected.
4. A harmless test image plus text completes image moderation.
5. Temporarily removing `GEMINI_API_KEY` leaves content unpublished and the
   same-ID retry works after restoring and restarting the API.

Do not use real personal data or harmful imagery in test fixtures. Record only
case IDs, states, scores, and timings; never commit the API key or provider
response containing sensitive user content.

- [ ] **Step 9: Review the final diff and working tree**

Run: `git diff --check; git status --short`

Expected: no whitespace errors. The five pre-existing user-owned mobile
screenshot deletions remain unstaged and are not included in any feature
commit.

- [ ] **Step 10: Commit documentation**

```powershell
git add -- README.md docs/setup.md Project_Overview.md supabase/README.md
git commit -m "docs: add Gemini moderation rollout guide"
```

---

## Implementation Completion Gate

The implementation is complete only after code-level verification passes and
the user has received the exact Supabase, Google AI Studio, Vercel, Admin, and
mobile configuration steps. Live SQL execution, real Gemini key smoke tests,
and deployed physical-device acceptance remain explicitly user-operated if
credentials or dashboards are unavailable to the coding session. FCM push
delivery begins only after these moderation events and transitions are stable.
