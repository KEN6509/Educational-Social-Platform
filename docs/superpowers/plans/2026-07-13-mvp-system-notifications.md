# MVP System Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate reliable creator-award and post-rejection system notifications, display them as email-like cards/details, and support durable rejected-post appeals.

**Architecture:** PostgreSQL transition triggers create immutable notification snapshots and enforce appeal ownership/deduplication. The existing chat notification model/repository remains the data boundary; focused Flutter widgets provide the System card, detail page, and appeal form while reusing existing read-state, realtime, badge, and rejected-post navigation infrastructure.

**Tech Stack:** PostgreSQL/Supabase RLS and triggers, Flutter/Dart, Supabase Flutter, `flutter_test`

---

## File Structure

- Modify `supabase/chat.sql`: appeal table/RLS/RPC, system notification triggers, delete policy.
- Modify `apps/mobile/lib/src/features/chat/data/chat_models.dart`: parse action metadata and expose system-template helpers.
- Modify `apps/mobile/lib/src/features/chat/data/chat_repository.dart`: delete, appeal, and rejected-post operations.
- Modify `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`: route System rows to the new card/detail flow.
- Create `apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart`: focused card and appeal form widgets.
- Create `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`: email-like detail screen and actions.
- Modify existing chat SQL/model/repository/widget tests for regression coverage.

### Task 1: Define the SQL contract and system-event lifecycle

**Files:**
- Modify: `apps/mobile/test/chat_sql_migration_test.dart`
- Modify: `supabase/chat.sql`

- [ ] **Step 1: Write failing SQL contract tests**

Assert that `chat.sql` contains `post_appeals`, a trimmed 20–500 reason constraint, one appeal per `(post_id, user_id)`, owner-select/insert policies, notification owner-delete policy, transition checks using `old` and `new`, preference checks, and triggers on `profiles` and `posts`.

```dart
expect(sql, contains('create table if not exists public.post_appeals'));
expect(sql, contains("char_length(btrim(reason)) between 20 and 500"));
expect(sql, contains('unique (post_id, user_id)'));
expect(sql, contains('old.is_content_creator is distinct from true'));
expect(sql, contains("new.moderation_status = 'rejected'"));
expect(sql, contains('system_enabled'));
expect(sql, contains('Users delete own notifications'));
```

- [ ] **Step 2: Run the SQL test and verify RED**

Run from `apps/mobile`:

```powershell
flutter test test/chat_sql_migration_test.dart
```

Expected: FAIL because the appeal schema and transition triggers are absent.

- [ ] **Step 3: Add appeal schema, policies, and RPC**

In `supabase/chat.sql`, create `post_appeals` with review fields and timestamps. Add an authenticated `submit_post_appeal(p_post_id uuid, p_reason text)` security-definer RPC that validates current-user authorship, rejected status, trimmed length, and uniqueness before inserting. Grant execute only to `authenticated`; allow users to select their own rows and prevent direct review-field updates.

- [ ] **Step 4: Add notification transition triggers**

Create idempotent security-definer functions that insert `type = 'system'` only for `false -> true` creator status and non-rejected -> rejected post status. Store `template_type`, post title, evidence, rejected timestamp, and `scheduled_deletion_at = now() + interval '7 days'` in `action_payload`; set `post_id` and `action_type = 'open_rejected_post'` only for rejection. Add a delete policy restricted to `user_id = auth.uid()`.

- [ ] **Step 5: Run SQL tests and commit**

```powershell
flutter test test/chat_sql_migration_test.dart
git add supabase/chat.sql apps/mobile/test/chat_sql_migration_test.dart
git commit -m "feat: add system notification and appeal SQL"
```

Expected: all SQL migration tests pass.

### Task 2: Extend notification and appeal models

**Files:**
- Modify: `apps/mobile/test/chat_models_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_models.dart`

- [ ] **Step 1: Write failing model tests**

Parse a rejection row and assert:

```dart
expect(notification.systemTemplateType, 'post_rejected');
expect(notification.actionType, 'open_rejected_post');
expect(notification.moderationEvidence, 'Image safety score exceeded');
expect(notification.scheduledDeletionAt, DateTime(2026, 7, 20));
expect(notification.isPostRejection, isTrue);
```

Also parse `creator_badge_awarded` and assert it is informational.

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test test/chat_models_test.dart --plain-name "system notification"
```

Expected: compilation failure for missing metadata accessors.

- [ ] **Step 3: Implement minimal model fields and helpers**

Add immutable `actionType` and `actionPayload` fields to `ChatNotification`, safely parse JSON-map values, and expose nullable helpers for template type, post title, evidence fallback, scheduled deletion, `isPostRejection`, and `isCreatorAward`.

- [ ] **Step 4: Verify and commit**

```powershell
flutter test test/chat_models_test.dart
git add apps/mobile/lib/src/features/chat/data/chat_models.dart apps/mobile/test/chat_models_test.dart
git commit -m "feat: model system notification metadata"
```

### Task 3: Add repository operations

**Files:**
- Modify: `apps/mobile/test/chat_repository_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`

- [ ] **Step 1: Write failing repository contract tests**

Assert the notification select includes `action_type, action_payload`, and source methods use:

```dart
_client.from('notifications').delete().eq('id', notificationId)
_client.rpc<void>('submit_post_appeal', params: {
  'p_post_id': postId,
  'p_reason': reason.trim(),
})
_client.from('post_appeals').select().eq('post_id', postId).maybeSingle()
```

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test test/chat_repository_test.dart
```

- [ ] **Step 3: Implement focused repository methods**

Add `deleteNotification`, `fetchPostAppeal`, and `submitPostAppeal`. Reuse `fetchPostForNotification` for owner-visible rejected posts and translate database validation failures through the existing friendly-error path at the UI boundary.

- [ ] **Step 4: Verify and commit**

```powershell
flutter test test/chat_repository_test.dart
git add apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/test/chat_repository_test.dart
git commit -m "feat: add system notification repository actions"
```

### Task 4: Build the System notification cards

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing card tests**

Pump the System section and assert a keyed rounded card contains `System Notification`, title, truncated preview/date, `View more`, unread treatment, and a three-dot Delete menu. Assert tapping the card marks read and invokes an injected detail opener; confirm Delete requires confirmation and refreshes only after success.

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test test/chat_widgets_test.dart --plain-name "system notification card"
```

- [ ] **Step 3: Implement `SystemNotificationCard`**

Create a reusable stateless card with explicit callbacks `onOpen` and `onDelete`. Use a three-line preview, rounded white surface, category row, overflow menu, date, and `View more` label. Preserve accessibility semantics by exposing one card-level open action and a separate menu action.

- [ ] **Step 4: Route only the System section through cards**

Add optional injected `openSystemNotification` and `deleteNotification` callbacks to `NotificationSectionsPage`. Keep Activity and follower rows unchanged. On open, mark the individual row read before navigation; on delete, confirm, await deletion, then refresh.

- [ ] **Step 5: Verify and commit**

```powershell
flutter test test/chat_widgets_test.dart --plain-name "system notification"
git add apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: add email-like system notification cards"
```

### Task 5: Build the detail page and rejected-post navigation

**Files:**
- Create: `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing detail tests**

Assert the page renders back/delete, full title/date/body, an interactive post-title reference only for rejection, friendly unavailable handling, and no appeal action for creator awards. Assert deletion confirms and returns a deleted result so the list refreshes.

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test test/chat_widgets_test.dart --plain-name "system notification detail"
```

- [ ] **Step 3: Implement the detail page**

Use a scrollable email layout. Render the rejected template as structured paragraphs so the post title is a tappable span rather than attempting to parse an arbitrary body string. Open the post only when it remains owner-visible; show the existing friendly unavailable snackbar otherwise. Render the creator template as informational content.

- [ ] **Step 4: Wire default navigation and verify**

`NotificationSectionsPage` pushes `SystemNotificationDetailPage` when no injected opener is supplied and refreshes when it returns read/deleted/appeal changes.

```powershell
flutter test test/chat_widgets_test.dart --plain-name "system notification"
git add apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: add system notification detail page"
```

### Task 6: Add the appeal form and submitted state

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write failing appeal tests**

Cover hidden action for non-rejections, required 20–500 trimmed reason, live count, keyboard-safe scrolling, preserved text after failure, successful submit, and disabled `Appeal submitted` state when an appeal already exists.

- [ ] **Step 2: Run and verify RED**

```powershell
flutter test test/chat_widgets_test.dart --plain-name "post appeal"
```

- [ ] **Step 3: Implement the form and state flow**

Add a focused modal form with a multiline field, Cancel, and Submit. Disable Submit while invalid or sending. Await `submitPostAppeal`; keep the controller content on failure and show a friendly message. On success close the form and update the detail page to `Appeal submitted` without requiring a full app restart.

- [ ] **Step 4: Verify and commit**

```powershell
flutter test test/chat_widgets_test.dart --plain-name "post appeal|system notification"
git add apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "feat: submit rejected post appeals"
```

### Task 7: Full verification and manual Supabase handoff

**Files:**
- Modify: `supabase/README.md`
- Verify: `apps/mobile`

- [ ] **Step 1: Document manual SQL application**

State that the user must run the full updated `supabase/chat.sql` in Supabase SQL Editor after the existing base schema. Include queries checking `post_appeals`, both triggers, notification delete policy, and `submit_post_appeal`.

- [ ] **Step 2: Run complete verification**

```powershell
dart format lib test
flutter test
flutter analyze
git diff --check
git status --short
```

Expected: all tests pass, `No issues found!`, no whitespace errors, and a clean worktree after the documentation commit.

- [ ] **Step 3: Commit documentation**

```powershell
git add supabase/README.md
git commit -m "docs: add system notification Supabase setup"
```
