# Gemini Moderation Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the audited database, Gemini, mobile, administration, and Vercel gaps while preserving the approved request-driven MVP architecture.

**Architecture:** Supabase remains the public-visibility authority and forcibly initializes untrusted content as pending. The Express adapter distinguishes explicit provider safety blocks from ordinary failures, Flutter persists same-record retries, and moderation cases carry immutable target snapshots for reliable administration. Deployment uses an explicit Vercel function entry and origin allowlist.

**Tech Stack:** PostgreSQL/RLS/Supabase Storage, TypeScript/Express/Node test runner, `@google/genai`, Flutter/Dart, SharedPreferences, React/Vitest, Vercel Functions

---

### Task 1: Lock down moderation inserts and privileged SQL helpers

**Files:**
- Modify: `services/api/src/moderation/moderationSql.test.ts`
- Modify: `supabase/ai_moderation.sql`
- Modify: `supabase/schema.sql`

- [ ] Add SQL contract assertions requiring `BEFORE INSERT` triggers for posts and comments that force `pending`, revision 1, null evidence, and null publication data.
- [ ] Run `npm test` in `services/api` and confirm the new contract fails before SQL changes.
- [ ] Add `initialize_post_moderation_fields` and `initialize_comment_moderation_fields` trigger functions and their triggers to the migration and baseline schema.
- [ ] Revoke execute permission from `PUBLIC`, `anon`, and `authenticated` for the two initializer functions, both update-protection functions, `set_moderation_target_pending`, `invalidate_moderation_cases`, and `invalidate_post_image_moderation`.
- [ ] Re-run API tests and confirm the SQL contract passes.
- [ ] Commit only the SQL and contract-test files with `fix: secure moderation database authority`.

### Task 2: Make shared image writes owner-scoped and immutable

**Files:**
- Modify: `services/api/src/moderation/moderationSql.test.ts`
- Modify: `supabase/ai_moderation.sql`
- Modify: `supabase/storage.sql`
- Modify: `supabase/schema.sql`

- [ ] Add a failing SQL contract for allowed post paths `<uid>/...`, chat paths `chat/<uid>/...`, owner-only delete, and the absence of an `UPDATE` policy on the `images` bucket.
- [ ] Run the focused API SQL contract test and confirm failure.
- [ ] Replace broad image insert/delete policies with folder ownership checks and drop all shared-image update policies without recreating them.
- [ ] Tighten the existing `avatars` migration policies to the same first-folder ownership rule while retaining owner updates for avatar upsert.
- [ ] Re-run the SQL contract and full API tests.
- [ ] Commit with `fix: scope storage writes to object owners`.

### Task 3: Correct Gemini safety and provider-error semantics

**Files:**
- Modify: `services/api/src/moderation/geminiModerationGateway.test.ts`
- Modify: `services/api/src/moderation/moderationService.test.ts`
- Modify: `services/api/src/moderation/moderationTypes.ts`
- Modify: `services/api/src/moderation/geminiModerationGateway.ts`
- Modify: `services/api/src/moderation/moderationService.ts`

- [ ] Add a gateway regression test where `{ status: 400 }` without explicit safety metadata is a non-retryable provider failure, not `GeminiInputSafetyError`.
- [ ] Add service tests proving supplied blocked ratings map only relevant categories to 100 and preserve the supplied evidence source.
- [ ] Run the focused tests and confirm both fail for the audited behavior.
- [ ] Normalize only explicit block reasons, blocked ratings, or safety-specific SDK metadata to `GeminiInputSafetyError`; classify generic 4xx request errors as non-retryable provider failures and transient errors as retryable.
- [ ] Convert explicit provider safety ratings into CyanZone category scores without fabricating all-category evidence.
- [ ] Run focused and full API tests, typecheck, and build.
- [ ] Commit with `fix: distinguish Gemini safety blocks from request errors`.

### Task 4: Add CORS allowlisting and a real Vercel entry

**Files:**
- Modify: `services/api/src/config/env.test.ts`
- Modify: `services/api/src/config/env.ts`
- Create: `services/api/src/app.test.ts`
- Modify: `services/api/src/app.ts`
- Modify: `services/api/src/index.ts`
- Create: `services/api/api/index.ts`
- Create: `services/api/vercel.json`
- Modify: `services/api/tsconfig.json`
- Modify: `services/api/package.json`
- Modify: `services/api/.env.example`

- [ ] Add failing environment tests for parsing a comma-separated `CORS_ALLOWED_ORIGINS` list.
- [ ] Add failing app tests proving configured browser origins receive CORS headers, unknown origins are rejected, and native requests without `Origin` still work.
- [ ] Add a structural test that imports the Vercel entry and receives `/health` through the default Express export.
- [ ] Implement the parsed allowlist and pass it into `createApp`; use a CORS callback that accepts no-origin requests and exact configured origins only.
- [ ] Add `api/index.ts`, route all paths to `/api` in `vercel.json`, and include the API entry in TypeScript compilation while preserving `npm start`.
- [ ] Run API tests, typecheck, and build.
- [ ] Commit with `fix: harden API deployment configuration`.

### Task 5: Type mobile transport failures and remove dotenv coupling

**Files:**
- Modify: `apps/mobile/test/http_content_moderation_gateway_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/data/http_content_moderation_gateway.dart`
- Modify: `apps/mobile/test/app_dependencies_test.dart`
- Modify: `apps/mobile/lib/src/app_dependencies.dart`
- Modify: `apps/mobile/lib/main.dart`

- [ ] Add failing tests for `SocketException`, `http.ClientException`, and timeout mapping to a retryable `ContentModerationFailure`.
- [ ] Add a failing dependency test that supplies an explicit test API URL without loading dotenv.
- [ ] Wrap network and timeout exceptions at the HTTP boundary while leaving response parsing and HTTP status mapping unchanged.
- [ ] Change `AppDependencies.production` to require an API base URL parameter and pass `ApiConfig.baseUrl` from `main.dart` after dotenv initialization.
- [ ] Run the focused Flutter tests and `flutter analyze`.
- [ ] Commit with `fix: make mobile moderation transport recoverable`.

### Task 6: Persist same-record retries across app restarts

**Files:**
- Create: `apps/mobile/lib/src/features/posts/domain/pending_moderation_retry.dart`
- Create: `apps/mobile/lib/src/features/posts/data/shared_preferences_pending_moderation_retry_store.dart`
- Create: `apps/mobile/lib/src/features/posts/application/moderation_submission_coordinator.dart`
- Create: `apps/mobile/test/pending_moderation_retry_store_test.dart`
- Create: `apps/mobile/test/moderation_submission_coordinator_test.dart`
- Modify: `apps/mobile/lib/src/app_dependencies.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/content_moderation_scope.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`

- [ ] Add failing store tests for saving, deduplicating, listing, and removing post/comment target IDs.
- [ ] Add failing coordinator tests proving a retryable failure stores the same target ID and a terminal/admin-review result removes it.
- [ ] Implement the SharedPreferences-backed store and coordinator without persisting access tokens or content.
- [ ] Route post/comment moderation calls through the coordinator so the persistence call occurs once and retry uses the same ID.
- [ ] Add a compact pending-moderation action in the existing shell that lists retained targets and lets the author retry them.
- [ ] Run the focused widget/unit tests and analyzer.
- [ ] Commit with `feat: persist moderation retries`.

### Task 7: Snapshot moderation targets for trustworthy admin history

**Files:**
- Modify: `services/api/src/moderation/moderationSql.test.ts`
- Modify: `supabase/ai_moderation.sql`
- Modify: `supabase/schema.sql`
- Modify: `services/api/src/admin/adminModeration.test.ts`
- Modify: `services/api/src/admin/adminRepository.ts`

- [ ] Add failing SQL tests requiring a `target_snapshot jsonb` column and snapshot construction during case preparation.
- [ ] Add a failing admin repository test where current target text differs from snapshot text and assert the snapshot wins.
- [ ] Add the nullable snapshot column and capture post title/content/tags/image path metadata or comment content in `prepare_content_moderation`.
- [ ] Prefer snapshot fields during admin hydration and fall back to live rows for pre-migration cases.
- [ ] Run API and Admin Portal moderation tests.
- [ ] Commit with `fix: preserve moderation case target snapshots`.

### Task 8: Resolve dependency and regression-test gaps

**Files:**
- Modify: `services/api/package.json`
- Modify: `services/api/package-lock.json`
- Modify: `apps/admin/package.json`
- Modify: `apps/admin/package-lock.json`
- Modify: `apps/mobile/test/posts_repository_test.dart`

- [ ] Move `@vitejs/plugin-react` to Admin Portal dev dependencies and use `npm audit fix` only for compatible dependency updates.
- [ ] Replace the brittle mobile source-position assertion with a behavior/contract assertion scoped to `createReport`.
- [ ] Run `npm audit --omit=dev` in API and Admin Portal and record any remaining production findings.
- [ ] Run full API tests/typecheck/build, Admin tests/typecheck/build, and Flutter tests/analyze.
- [ ] Commit with `chore: close moderation verification gaps`.

### Task 9: Update rollout documentation

**Files:**
- Modify: `README.md`
- Modify: `Project_Overview.md`
- Modify: `docs/setup.md`
- Modify: `supabase/README.md`
- Modify: `Future_Improvements.md`

- [ ] Document that `gemini-3.8-flash` is the current stable default and remains environment-configurable.
- [ ] Add the exact revised Supabase migration order, Vercel root/variables, CORS origins, mobile API URL, and real-provider smoke-test steps.
- [ ] Record private media storage and server-side moderation search/cursor pagination as post-MVP improvements.
- [ ] Run documentation link/path checks and `git diff --check`.
- [ ] Commit with `docs: update moderation hardening rollout`.

