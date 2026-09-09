# Android FCM Push Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove deleted posts from the profile immediately and deliver authorized CyanZone notifications to Android devices through Firebase Cloud Messaging, with independent in-app and phone-push settings.

**Architecture:** Supabase remains the source of truth for notification records and preferences. Supabase Database Webhooks send inserted notification IDs to the Vercel Express API, which reloads the authoritative record, claims an idempotent delivery, and sends through a Firebase gateway. The Flutter app registers one token per installation, handles foreground/background/terminated messages, and resolves only safe typed destinations after authentication.

**Tech Stack:** Flutter/Dart, Firebase Core, Firebase Messaging, Flutter Local Notifications, SharedPreferences, Node.js/Express/TypeScript, Firebase Admin SDK, Supabase/PostgreSQL/RLS/Database Webhooks, Vercel.

---

## Preconditions and execution rules

- Work in the original repository folder on `feature/AI-Moderation`; do not create a Git worktree.
- Preserve unrelated modified/deleted files already present in the working tree.
- Run terminal commands directly in the user's terminal.
- Follow test-driven development: add one failing focused test, run it to see the expected failure, implement the smallest change, then rerun it.
- Create local commits at the checkpoints below, but do not push until the complete Android FCM feature has passed scoped verification and the user approves the combined push.
- Never commit Firebase service-account credentials, webhook secrets, FCM tokens, Supabase service-role keys, or local `.env` files.

## Task 1: Remove a deleted post from every visible profile cache immediately

**Files:**

- Create: `apps/mobile/test/post_interaction_sync_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/data/post_interaction_sync.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`
- Modify: `apps/mobile/test/feed_card_test.dart`

- [ ] Add a failing unit test proving that `PostInteractionUpdate` removes the matching post when `result['deleted'] == true`, leaves unrelated posts unchanged, and never inserts a deleted missing post.

```dart
test('deleted result removes the matching post', () {
  final update = PostInteractionUpdate(
    postId: deletedPost.id,
    post: deletedPost,
    result: const {'deleted': true},
  );

  expect(update.applyToPosts([deletedPost, otherPost]), [otherPost]);
  expect(
    update.applyToPosts([otherPost], insertIfMissing: true),
    [otherPost],
  );
});
```

- [ ] Run the focused test and confirm that it fails because the current implementation replaces instead of removes.

```powershell
Set-Location apps/mobile
flutter test test/post_interaction_sync_test.dart
```

- [ ] Add `bool get isDeleted => result['deleted'] == true` and return a filtered list from `applyToPosts` before replacement/insertion logic.
- [ ] Update `_ProfilePostGridState._handlePostInteractionUpdate` so a posted-grid deletion updates `_posts`, `_postedPostsCache[profileUserId]`, and the SharedPreferences posted-post cache immediately.
- [ ] Add an optional `VoidCallback? onPostDeleted` from `_ProfilePostGrid` to the profile owner so the visible post count decrements once without a full refresh.
- [ ] Extend the relevant widget regression test to delete from a profile grid and assert that the card and count disappear immediately.
- [ ] Run focused tests.

```powershell
flutter test test/post_interaction_sync_test.dart test/feed_card_test.dart
```

- [ ] Commit the immediate-delete fix locally.

```powershell
git add apps/mobile/lib/src/features/posts/data/post_interaction_sync.dart apps/mobile/lib/src/features/profile/presentation/profile_page.dart apps/mobile/test/post_interaction_sync_test.dart apps/mobile/test/feed_card_test.dart
git commit -m "fix: remove deleted posts immediately"
```

## Task 2: Change the Android identity to `com.cyanzone.mobile`

**Files:**

- Modify: `apps/mobile/android/app/build.gradle.kts`
- Create: `apps/mobile/android/app/src/main/kotlin/com/cyanzone/mobile/MainActivity.kt`
- Delete: `apps/mobile/android/app/src/main/kotlin/com/example/cyanzone_mobile/MainActivity.kt`
- Create: `apps/mobile/test/android_firebase_config_test.dart`

- [ ] Add a source-contract test that reads the Android Gradle file and `MainActivity.kt` and expects the namespace, application ID, package declaration, and Kotlin path to be `com.cyanzone.mobile`.
- [ ] Run the test and confirm it fails on the current placeholder identity.

```powershell
Set-Location apps/mobile
flutter test test/android_firebase_config_test.dart
```

- [ ] Set both `namespace` and `applicationId` to `com.cyanzone.mobile`.
- [ ] Move `MainActivity.kt` to `com/cyanzone/mobile/` and change its package declaration to `package com.cyanzone.mobile`.
- [ ] Remove the obsolete generated `TODO` comment about choosing an application ID.
- [ ] Rerun the focused test.
- [ ] Commit locally.

```powershell
git add apps/mobile/android/app/build.gradle.kts apps/mobile/android/app/src/main/kotlin apps/mobile/test/android_firebase_config_test.dart
git commit -m "chore: set CyanZone Android application id"
```

## Task 3: Add the push database schema and preserve independent master switches

**Files:**

- Create: `supabase/fcm_push_notifications.sql`
- Modify: `supabase/chat.sql`
- Modify: `supabase/admin_portal.sql`
- Modify: `apps/mobile/test/chat_sql_migration_test.dart`
- Create: `services/api/src/push/pushSql.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] Write failing SQL contract tests for all of these requirements:

  - `notification_preferences.push_enabled` defaults to `false`;
  - `notifications.in_app_visible` and `supervision_notifications.in_app_visible` default to `true`;
  - `push_device_tokens` permits Android only and uniquely identifies both a token and a user/device installation;
  - `push_deliveries` uniquely identifies `(source_table, source_id)` and constrains delivery status;
  - member RLS exposes notification rows only when `in_app_visible = true`;
  - all existing producers allow the matching category when either `in_app_enabled` or `push_enabled` is enabled;
  - both notification tables have a shared preference-enforcement `BEFORE INSERT` trigger;
  - token registration/revocation and delivery claim/completion RPCs revoke public execution and grant only `service_role` execution.

- [ ] Import `pushSql.test.ts` from `services/api/src/all.test.ts` and run the focused API and Flutter SQL tests to confirm failure.

```powershell
Set-Location services/api
npx tsx --test --test-name-pattern="push SQL" src/all.test.ts
Set-Location ../../apps/mobile
flutter test test/chat_sql_migration_test.dart
```

- [ ] Implement `supabase/fcm_push_notifications.sql` as an idempotent migration:

  - add `push_enabled` and both `in_app_visible` columns with safe backfills;
  - create `push_device_tokens` and `push_deliveries` plus indexes, timestamp maintenance, RLS, and service-role-only RPCs;
  - create a category-mapping function for `chat`, `activity`, `system`, and `followers`;
  - create preference triggers that discard disabled events and set `in_app_visible` from the in-app master;
  - replace member SELECT policies so push-only rows cannot appear in lists or badge queries later;
  - make delivery claiming atomic and lease-aware so duplicate/concurrent webhook attempts cannot send twice.

- [ ] Update each existing preference check in `chat.sql` and `admin_portal.sql` from an in-app-only gate to `(in_app_enabled or push_enabled) and <category>_enabled`. Keep the central trigger as the final authoritative guard, including for parent-supervision inserts.
- [ ] Ensure `mark_notification_section_read` and unread queries act only on member-visible rows through RLS or an explicit `in_app_visible` predicate.
- [ ] Rerun both SQL contract suites.
- [ ] Commit locally.

```powershell
git add supabase/fcm_push_notifications.sql supabase/chat.sql supabase/admin_portal.sql apps/mobile/test/chat_sql_migration_test.dart services/api/src/push/pushSql.test.ts services/api/src/all.test.ts
git commit -m "feat: add Android push notification schema"
```

## Task 4: Add typed push configuration and safe Firebase initialization

**Files:**

- Modify: `services/api/package.json`
- Modify: `services/api/package-lock.json`
- Modify: `services/api/src/config/env.ts`
- Modify: `services/api/src/config/env.test.ts`
- Create: `services/api/src/push/pushTypes.ts`
- Create: `services/api/src/push/firebasePushGateway.ts`
- Create: `services/api/src/push/firebasePushGateway.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] Install Firebase Admin in the API.

```powershell
Set-Location services/api
npm install firebase-admin
```

- [ ] Add failing environment tests for an all-or-none Firebase configuration using:

  - `PUSH_WEBHOOK_SECRET` with at least 32 characters;
  - `FIREBASE_PROJECT_ID`;
  - `FIREBASE_CLIENT_EMAIL` as an email;
  - `FIREBASE_PRIVATE_KEY`, accepting Vercel's escaped `\n` and normalizing it to real newlines.

- [ ] Define provider-neutral types: `PushCategory`, `PushDestination`, `PushMessage`, `PushSendResult`, `PushFailure`, and `PushGateway`.
- [ ] Write failing gateway tests using an injected Firebase messaging port. Verify notification title/body, all-string data payloads, Android high priority, a stable channel ID, and mapping of invalid-token versus retryable error codes.
- [ ] Implement lazy Firebase Admin initialization so local API startup remains possible only when push dependencies are deliberately replaced in tests, while production fails clearly if `/push` is invoked without complete Firebase configuration.
- [ ] Ensure logs never contain a private key or full FCM token.
- [ ] Run focused tests and typecheck.

```powershell
npx tsx --test --test-name-pattern="environment|Firebase push" src/all.test.ts
npm run typecheck
```

- [ ] Commit locally.

```powershell
git add services/api/package.json services/api/package-lock.json services/api/src/config services/api/src/push services/api/src/all.test.ts
git commit -m "feat: add Firebase push gateway"
```

## Task 5: Implement the push repository and atomic device lifecycle

**Files:**

- Create: `services/api/src/push/pushRepository.ts`
- Create: `services/api/src/push/pushRepository.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] Write repository tests with a fake Supabase client for:

  - member device registration using `register_push_device`;
  - token refresh on the same installation;
  - token transfer away from a previously signed-in account;
  - member device revocation using `deactivate_push_device`;
  - authoritative reload of `notifications` and `supervision_notifications` by ID and recipient;
  - preference and active-token reads;
  - atomic delivery claim, completion, expired-lease reclaim, and invalid-token deactivation.

- [ ] Run the focused tests and confirm the module is missing.
- [ ] Implement `createPushRepository` with narrow Supabase interfaces rather than spreading raw SDK types through the service.
- [ ] Return domain records with validated strings/dates and never return the full token from an error object.
- [ ] Rerun focused tests and typecheck.
- [ ] Commit locally.

```powershell
git add services/api/src/push/pushRepository.ts services/api/src/push/pushRepository.test.ts services/api/src/all.test.ts
git commit -m "feat: add push delivery repository"
```

## Task 6: Implement event mapping, preference checks, deduplication, and retry

**Files:**

- Create: `services/api/src/push/pushService.ts`
- Create: `services/api/src/push/pushService.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] Write service tests for the complete mapping matrix:

  - `chat_message` → Chat → conversation;
  - `like`, `favorite`, `comment`, `comment_reply`, `comment_like`, `mention` → Activity → post/comment;
  - `new_follower` → Followers → profile;
  - `system` → System → system notification detail;
  - every `supervision_notifications` event → System → typed family/check-in/SOS/screen-time destination.

- [ ] Add failing tests for unsupported source/type, mismatched webhook record ID/user, category off, push master off, no active token, an already-completed delivery, an active processing lease, an expired lease, full success, partial success, invalid-token deactivation, and exactly one retry for retryable failures.
- [ ] Use only safe versioned payload data:

```ts
{
  version: '1',
  sourceTable: 'notifications',
  sourceId: notification.id,
  route: 'conversation',
  conversationId: notification.conversationId,
}
```

- [ ] Implement `createPushService(repository, gateway)` so it reloads the database row instead of trusting title, body, recipient, or route data received from the webhook.
- [ ] Claim before sending, cap Firebase batches at 500, retry only retryable device results once, deactivate permanent invalid registrations, and always complete the delivery with safe counts/status.
- [ ] Rerun service tests and typecheck.
- [ ] Commit locally.

```powershell
git add services/api/src/push/pushService.ts services/api/src/push/pushService.test.ts services/api/src/all.test.ts
git commit -m "feat: process push notification events"
```

## Task 7: Expose authenticated device and protected webhook endpoints

**Files:**

- Create: `services/api/src/push/pushSchemas.ts`
- Create: `services/api/src/push/pushRouter.ts`
- Create: `services/api/src/push/pushRouter.test.ts`
- Modify: `services/api/src/createApp.ts`
- Modify: `services/api/src/app.test.ts`
- Modify: `services/api/src/index.ts`
- Modify: `services/api/src/index.test.ts`
- Modify: `services/api/src/all.test.ts`

- [ ] Add failing router tests for:

  - bearer authentication and active-member checks on `PUT /push/devices` and `DELETE /push/devices/:deviceId`;
  - schema bounds on installation IDs and tokens;
  - ownership derived from the bearer token, never the request body;
  - exact constant-time webhook-secret validation;
  - accepted Supabase INSERT envelopes for only `notifications` and `supervision_notifications`;
  - member-authenticated resolution of a source ID for push-tap navigation,
    including push-only rows hidden from normal in-app lists;
  - stable `200` for delivered/skipped/duplicate outcomes and safe `4xx/5xx` bodies for invalid or retryable failures.

- [ ] Reuse `createVerifyMember` from `moderationAuth.ts` instead of creating a second member-auth implementation.
- [ ] Mount the router at `/push`, compose the repository/service/gateway in `index.ts`, and extend composition tests.
- [ ] Keep the existing `/health`, `/admin`, and `/moderation` behavior unchanged.
- [ ] Run the full API suite and build.

```powershell
Set-Location services/api
npm test
npm run build
```

- [ ] Commit locally.

```powershell
git add services/api/src
git commit -m "feat: expose secure push API"
```

## Task 8: Add Flutter push abstractions and device registration client

**Files:**

- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/pubspec.lock`
- Create: `apps/mobile/lib/src/features/notifications/domain/push_destination.dart`
- Create: `apps/mobile/lib/src/features/notifications/domain/push_notification_gateway.dart`
- Create: `apps/mobile/lib/src/features/notifications/data/http_push_repository.dart`
- Create: `apps/mobile/lib/src/features/notifications/data/supabase_notification_preferences_repository.dart`
- Create: `apps/mobile/lib/src/features/notifications/data/shared_preferences_push_state_store.dart`
- Create: `apps/mobile/test/push_destination_test.dart`
- Create: `apps/mobile/test/http_push_repository_test.dart`
- Create: `apps/mobile/test/notification_preferences_repository_test.dart`
- Create: `apps/mobile/test/shared_preferences_push_state_store_test.dart`

- [ ] Add the mobile packages.

```powershell
Set-Location apps/mobile
flutter pub add firebase_core firebase_messaging flutter_local_notifications
```

- [ ] Write parser tests that accept only version `1`, known source tables/routes, and required IDs; reject unknown/missing fields without navigation.
- [ ] Write HTTP repository tests for bearer headers, `PUT /push/devices`, `DELETE /push/devices/:deviceId`, authenticated source resolution for push taps, timeouts, and safe error mapping.
- [ ] Write preference-repository tests for loading/upserting both master switches and all four category switches without one master mutating the other.
- [ ] Write store tests for a stable generated installation ID, prompt-shown flag, push-enabled local state, and one replaceable pending destination.
- [ ] Implement small interfaces so Firebase, HTTP, and SharedPreferences remain replaceable in tests.
- [ ] Use the existing `ApiConfig.baseUrl` and Supabase session token provider.
- [ ] Run focused tests and analysis for the new files.
- [ ] Commit locally.

```powershell
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/lib/src/features/notifications apps/mobile/test/push_destination_test.dart apps/mobile/test/http_push_repository_test.dart apps/mobile/test/notification_preferences_repository_test.dart apps/mobile/test/shared_preferences_push_state_store_test.dart
git commit -m "feat: add mobile push foundations"
```

## Task 9: Implement Firebase Messaging and foreground local notifications

**Files:**

- Create: `apps/mobile/lib/src/features/notifications/data/firebase_push_notification_gateway.dart`
- Create: `apps/mobile/test/firebase_push_notification_gateway_test.dart`
- Modify: `apps/mobile/lib/main.dart`

- [ ] Write gateway tests around injected Firebase/local-notification ports for:

  - Android authorization status and permission request;
  - token acquisition and refresh stream;
  - foreground messages displayed through a local notification;
  - background/terminated tap streams;
  - stable normal and safety Android notification channels;
  - malformed messages ignored without crashing.

- [ ] Register a top-level `@pragma('vm:entry-point')` background handler before `runApp` and initialize Firebase before constructing production dependencies.
- [ ] Configure foreground presentation through `flutter_local_notifications`; do not generate a duplicate local notification for background messages already displayed by Android.
- [ ] Rerun focused tests.
- [ ] Commit locally.

```powershell
git add apps/mobile/lib/main.dart apps/mobile/lib/src/features/notifications/data/firebase_push_notification_gateway.dart apps/mobile/test/firebase_push_notification_gateway_test.dart
git commit -m "feat: receive Android push messages"
```

## Task 10: Coordinate permission, token lifecycle, account switching, and deferred destinations

**Files:**

- Create: `apps/mobile/lib/src/features/notifications/application/push_notification_coordinator.dart`
- Create: `apps/mobile/test/push_notification_coordinator_test.dart`
- Modify: `apps/mobile/lib/src/app_dependencies.dart`
- Modify: `apps/mobile/test/android_firebase_config_test.dart`

- [ ] Write coordinator tests for:

  - first successful sign-in offering CyanZone's explanation exactly once;
  - `Enable` requesting Android permission, registering only after authorization,
    and then persisting `push_enabled = true`;
  - `Not now` and OS denial leaving in-app notifications operational;
  - push preference off revoking the device;
  - token refresh re-registering the same installation;
  - logout revocation as best-effort and never trapping logout;
  - account switch transferring the token through registration;
  - signed-out taps storing one destination and replaying it after authentication;
  - duplicate startup/open events opening once.

- [ ] Implement a stateful coordinator with explicit `start`, `onAuthenticated`, `setPushEnabled`, and `beforeSignOut` methods plus a destination stream/callback. It owns the ordering between OS permission, device registration/revocation, and the persisted push master preference.
- [ ] Add push gateway, device repository, state store, and coordinator to `AppDependencies.production` without importing Firebase into presentation widgets.
- [ ] Rerun focused tests.
- [ ] Commit locally.

```powershell
git add apps/mobile/lib/src/app_dependencies.dart apps/mobile/lib/src/features/notifications/application apps/mobile/test/push_notification_coordinator_test.dart apps/mobile/test/app_dependencies_test.dart
git commit -m "feat: coordinate Android push lifecycle"
```

## Task 11: Add the permission explanation and independent notification settings

**Files:**

- Create: `apps/mobile/lib/src/features/notifications/presentation/push_notification_scope.dart`
- Create: `apps/mobile/lib/src/features/notifications/presentation/push_permission_prompt.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/notification_settings_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`
- Modify: `apps/mobile/test/settings_page_test.dart`
- Create: `apps/mobile/test/push_permission_prompt_test.dart`

- [ ] Add failing widget tests for the explanation dialog's `Enable` and `Not now` actions and for the phone-push switch.
- [ ] Extend notification preference state with `pushEnabled`, load/save through the shared preference repository, and display separate `In-app notifications` and `Phone push notifications` masters.
- [ ] Keep category switches enabled when either master is enabled. Turning one master off must not mutate the other master or any category values.
- [ ] Route a phone-push switch change through the coordinator. Enabling requests permission, registers the token, and only then persists `push_enabled = true`; failure restores the UI to off. Disabling persists `false` first and then performs best-effort token revocation.
- [ ] Change logout to call `coordinator.beforeSignOut()` before Supabase sign-out, but continue logout if revocation cannot reach the API.
- [ ] Rerun widget tests.
- [ ] Commit locally.

```powershell
git add apps/mobile/lib/src/features/notifications/presentation apps/mobile/lib/src/features/profile/presentation/notification_settings_page.dart apps/mobile/lib/src/features/profile/presentation/settings_page.dart apps/mobile/test/settings_page_test.dart apps/mobile/test/push_permission_prompt_test.dart
git commit -m "feat: add Android push preferences"
```

## Task 12: Add safe deep-link navigation after authentication

**Files:**

- Create: `apps/mobile/lib/src/features/notifications/presentation/push_destination_navigator.dart`
- Create: `apps/mobile/test/push_destination_navigator_test.dart`
- Modify: `apps/mobile/lib/src/app.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart`
- Modify: `apps/mobile/test/features/auth/presentation/auth_gate_test.dart`

- [ ] Write navigation tests for conversation, post/comment, profile, System detail, family link, check-in, SOS, and screen-time destinations.
- [ ] Resolve the source notification through the authenticated API before opening anything. This lets push-only rows remain hidden from normal in-app RLS queries while still authorizing a tap for the intended recipient. Deleted/inaccessible records must show a friendly unavailable message and stop.
- [ ] Reuse `SupervisionNotificationRouter` for parent-supervision routes and the existing post/System/chat/profile pages for ordinary routes.
- [ ] Give `MaterialApp` a root `navigatorKey`; wrap the auth gate in `PushNotificationScope` and invoke `coordinator.onAuthenticated` only after the signed-in tree is mounted.
- [ ] Replay a pending signed-out destination after login and clear it only after the navigation attempt is consumed.
- [ ] Rerun focused auth/navigation tests.
- [ ] Commit locally.

```powershell
git add apps/mobile/lib/src/app.dart apps/mobile/lib/src/features/auth/presentation/auth_gate.dart apps/mobile/lib/src/features/notifications/presentation/push_destination_navigator.dart apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart apps/mobile/test/push_destination_navigator_test.dart apps/mobile/test/features/auth/presentation/auth_gate_test.dart
git commit -m "feat: open safe push destinations"
```

## Task 13: Configure Android Firebase plumbing

**Files:**

- Modify: `apps/mobile/android/settings.gradle.kts`
- Modify: `apps/mobile/android/app/build.gradle.kts`
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/mobile/.gitignore`
- Modify: `apps/mobile/test/app_dependencies_test.dart`

- [ ] Extend source-contract tests to require:

  - Google Services Gradle plugin declaration and application;
  - `android.permission.POST_NOTIFICATIONS`;
  - default notification channel metadata;
  - `com.cyanzone.mobile` consistently;
  - `android/app/google-services.json` ignored by repository policy.

- [ ] Run the test and confirm the new Firebase plumbing expectations fail.
- [ ] Configure Google Services, permission, and default icon/channel metadata. Do not add iOS/APNs configuration.
- [ ] Add `android/app/google-services.json` to the mobile ignore file so the user's downloaded Firebase client configuration is handled manually.
- [ ] Rerun source-contract tests and `flutter analyze`.
- [ ] Record that an Android build cannot be verified until the user places the matching Firebase file at `apps/mobile/android/app/google-services.json`.
- [ ] Commit locally.

```powershell
git add apps/mobile/android apps/mobile/.gitignore apps/mobile/test/android_firebase_config_test.dart
git commit -m "chore: configure Android Firebase messaging"
```

## Task 14: Update deployment documentation and project status

**Files:**

- Modify: `docs/setup.md`
- Modify: `docs/Future_Improvements.md`
- Modify: `Project_Overview.md`
- Modify: `apps/mobile/README.md`

- [ ] Document the exact API variables without secret values:

```text
PUSH_WEBHOOK_SECRET
FIREBASE_PROJECT_ID
FIREBASE_CLIENT_EMAIL
FIREBASE_PRIVATE_KEY
```

- [ ] Document the exact manual setup order: register `com.cyanzone.mobile` in Firebase, place `google-services.json`, create a service account, set Vercel variables, redeploy, run `supabase/fcm_push_notifications.sql`, then create two authenticated Supabase INSERT webhooks.
- [ ] Keep iOS/APNs clearly listed as future work and explain briefly that APNs is Apple's push service required for iPhone delivery.
- [ ] Update the FCM checklist/status in `Project_Overview.md` only for code that is actually implemented. Keep live Firebase/Supabase/Vercel/device acceptance marked pending until the user performs it.
- [ ] Remove obsolete README wording that says all external push notifications are unimplemented.
- [ ] Scan documentation for accidental secret-like values and corrupted/non-English text.

```powershell
rg -n "PRIVATE KEY|service_role|PUSH_WEBHOOK_SECRET=" docs Project_Overview.md apps/mobile/README.md
rg -n "FCM|Firebase|APNs|push" docs/Future_Improvements.md Project_Overview.md apps/mobile/README.md
```

- [ ] Commit locally.

```powershell
git add docs/setup.md docs/Future_Improvements.md Project_Overview.md apps/mobile/README.md
git commit -m "docs: add Android push setup"
```

## Task 15: Run scoped regression verification

**Files:**

- Verify all changed files; do not edit unrelated user files.

- [ ] Run the full API test/build checks.

```powershell
Set-Location services/api
npm test
npm run build
```

- [ ] Run the focused mobile suites covering changed behavior.

```powershell
Set-Location ../../apps/mobile
flutter test test/post_interaction_sync_test.dart test/feed_card_test.dart test/chat_sql_migration_test.dart test/android_firebase_config_test.dart test/app_dependencies_test.dart test/push_destination_test.dart test/http_push_repository_test.dart test/notification_preferences_repository_test.dart test/shared_preferences_push_state_store_test.dart test/firebase_push_notification_gateway_test.dart test/push_notification_coordinator_test.dart test/push_permission_prompt_test.dart test/push_destination_navigator_test.dart test/settings_page_test.dart test/features/auth/presentation/auth_gate_test.dart
flutter analyze
```

- [ ] Run formatter only on changed Dart files and rerun the focused mobile suites if formatting changed anything.

```powershell
dart format lib/src/features/notifications lib/src/features/posts/data/post_interaction_sync.dart lib/src/features/profile/presentation/profile_page.dart lib/src/features/profile/presentation/notification_settings_page.dart lib/src/features/profile/presentation/settings_page.dart lib/src/features/auth/presentation/auth_gate.dart lib/src/app.dart lib/src/app_dependencies.dart test/post_interaction_sync_test.dart test/push_destination_test.dart test/http_push_repository_test.dart test/notification_preferences_repository_test.dart test/shared_preferences_push_state_store_test.dart test/firebase_push_notification_gateway_test.dart test/push_notification_coordinator_test.dart test/push_permission_prompt_test.dart test/push_destination_navigator_test.dart
```

- [ ] Review only the intended diff and confirm no secrets or unrelated files are staged.

```powershell
Set-Location ../..
git status --short
git diff --check
git diff --stat origin/feature/AI-Moderation...HEAD
git diff --name-only origin/feature/AI-Moderation...HEAD
```

- [ ] Do not claim live delivery complete yet. Hand the user the Firebase, Vercel, and Supabase dashboard instructions one step at a time, then perform the physical Android test matrix after configuration.

## Task 16: Manual live acceptance after the user configures Firebase

- [ ] Confirm Vercel `/health` is healthy after adding Firebase variables and redeploying.
- [ ] Confirm both Supabase webhooks return `2xx` for new INSERT events.
- [ ] On a physical Android phone, verify first-login explanation and Android permission approval/denial.
- [ ] Verify Chat, Activity, Followers, System moderation, Check-In, and SOS notifications in foreground, background, and terminated states.
- [ ] Verify each tap opens the correct authorized destination.
- [ ] Verify in-app off/push on, in-app on/push off, category off, logout, and account-switch behavior.
- [ ] Verify duplicate webhooks create one logical delivery and invalid tokens become inactive.
- [ ] Update `Project_Overview.md` with dated evidence only after each live boundary is observed.
- [ ] With the user's approval, push the accumulated commits and create the combined pull request.
