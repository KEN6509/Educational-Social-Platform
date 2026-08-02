# Realtime System Notifications and Appeals Implementation Plan

**Goal:** Make Activity, System, and New Followers unread counts update while the app is open; align the admin post evidence and field-footer UI; redesign System notification cards/details; and support one final appeal for administrator-rejected AI-flagged or report-removed posts.

**Architecture:** Keep `notifications` as the single source for unread section counts, but move global badge listening into the persistent mobile shell and give an open notification section its own realtime refresh. Keep full appeal state in `post_appeals`, expose that state through the mobile repository, and determine whether a notification is appealable from structured `action_payload` metadata. Reuse the existing Users post carousel/detail viewer in Creator Requests instead of maintaining a second post-card design. Notification details use compact structured payload fields (`template_type`, `brief`, `decision_label`, and `decision_message`) with compatibility fallbacks for existing rows.

**Tech stack:** Flutter/Dart, Supabase Flutter Realtime, PostgreSQL/PLpgSQL, React/TypeScript/Tailwind, Vitest, Flutter widget tests, Node test runner.

**Out of scope:** FCM/background delivery, live Supabase deployment, and the pre-deployment 10,000-follower eligibility gate. This work provides foreground realtime updates while the app is running; FCM remains the later background/terminated-app solution.

**Implementation status (August 2, 2026):** Tasks 1-7D and the automated test/build verification recorded in Task 8 are complete. Mobile (**207**), Administration Portal (**51**), and API (**47**) tests pass; Flutter analysis and both production builds pass. Matching-viewport visual recapture remains pending. Repository SQL changes remain unapplied to the live Supabase project. The current working tree intentionally contains this uncommitted implementation; preserve it when starting the next chat.

---

## Files

### Mobile production

- `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
- `apps/mobile/lib/src/features/chat/data/chat_models.dart`
- `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart`
- `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- `apps/mobile/lib/src/features/profile/presentation/verified_badge_page.dart`

### Admin production

- `apps/admin/src/components/casework/DecisionPanel.tsx`
- `apps/admin/src/features/users/RecentPostsCarousel.tsx`
- `apps/admin/src/features/users/AllPostsModal.tsx`
- `apps/admin/src/features/users/PostDetailModal.tsx`
- `apps/admin/src/features/creatorRequests/CreatorRequestDetail.tsx`
- `apps/admin/src/features/creatorRequests/CreatorRequestsPage.tsx`

### Database and API contract

- `supabase/chat.sql`
- `supabase/admin_portal.sql`
- `services/api/src/admin/adminSql.test.ts`

### Tests and documentation

- `apps/mobile/test/chat_repository_test.dart`
- `apps/mobile/test/chat_models_test.dart`
- `apps/mobile/test/chat_widgets_test.dart`
- `apps/mobile/test/chat_sql_migration_test.dart`
- `apps/mobile/test/verified_badge_page_test.dart`
- `apps/admin/src/components/casework/casework.test.tsx`
- `apps/admin/src/features/users/PostReview.test.tsx`
- `apps/admin/src/features/creatorRequests/CreatorRequestsPage.test.tsx`
- `Project_Overview.md`

---

## Task 1: Make notification unread counts realtime outside Messages

- [ ] Add failing repository/source regressions proving there is a dedicated notification-table subscription and that `MainShell` owns and disposes one persistent badge channel.
- [ ] Add a failing lifecycle assertion proving the shell refreshes the badge on app resume without clearing the last confirmed count.
- [ ] Run from `apps/mobile` and verify RED:

  ```powershell
  flutter test test/chat_repository_test.dart --reporter compact
  ```

- [ ] Add `ChatRepository.subscribeToNotificationChanges(...)`, subscribing only to `public.notifications`. Supabase RLS remains the recipient boundary; use distinct channel names for the shell and any open section.
- [ ] Make `_MainShellState` a `WidgetsBindingObserver`. In `initState`, register the observer, subscribe with a unique `main-shell-notification-badge` channel, and call the existing `_refreshChatBadge()` for every notification insert/update/delete.
- [ ] On `AppLifecycleState.resumed`, refresh the badge. In `dispose`, remove the observer and realtime channel.
- [ ] Keep `ChatPage`'s conversation/message realtime subscription for chat rows, but avoid making it the sole owner of the global badge. The existing callback can still send the full calculated count to the shell.
- [ ] Add a notification-table channel to `NotificationSectionsPage` so Activity, System, and New Followers lists refresh while open, not only after route navigation or app resume. Dispose it with the route.
- [ ] Preserve the current count during loading and transient failures; never temporarily write zero.
- [ ] Re-run the focused test and verify GREEN.

Expected behavior: a new Activity, System, or New Followers row updates the Messages-tab badge and Messages shortcut count without first opening that notification section. Chat message realtime behavior remains unchanged.

---

## Task 2: Reuse the Users post evidence UI in Creator Requests and remove media gaps

- [ ] First extend `CreatorRequestsPage.test.tsx` with a failing test that expects Creator Requests to render the same `RecentPostsCarousel` media placeholder used by Users and to open the shared Post Detail viewer when a post card is selected.
- [ ] Extend `PostReview.test.tsx` with a failing assertion that both recent and See All cards are explicit top-aligned flex columns and their media elements are block-level, full-width, clipped, and edge-to-edge.
- [ ] Run from `apps/admin` and verify RED:

  ```powershell
  npm test -- src/features/creatorRequests/CreatorRequestsPage.test.tsx src/features/users/PostReview.test.tsx
  ```

- [ ] Change `CreatorRequestDetail` to accept `onOpenPost`, rename “Recent educational content” to neutral “Recent published content”, and render `RecentPostsCarousel` exactly as `UserDetail` does.
- [ ] In `CreatorRequestsPage`, add the selected-post detail state, fetch `/admin/posts/:postId`, and render the existing `PostDetailModal`; do not duplicate modal or card markup.
- [ ] In `AllPostsModal`, change each card to `flex flex-col`, wrap media in an explicit block/overflow-hidden region, and add `block h-full w-full object-cover` to images. Apply the same no-inline-gap invariant to `RecentPostsCarousel`.
- [ ] Keep `object-cover` for card thumbnails and the existing `object-contain` behavior in the large detail stage.
- [ ] Re-run the focused admin tests and verify GREEN.

Expected behavior: text-only posts show the same file placeholder on Users and Creator Requests; image cards have no white strip around the media region at any card size.

---

## Task 3: Align validation errors and character counters

- [ ] Add a failing `DecisionPanel` test for a footer with the validation error on the left and `0 / 500` pinned to the right. Assert the footer allows wrapping instead of overlap.
- [ ] Add a failing Verified Badge widget test that identifies the counter at the input field's bottom-right edge.
- [ ] Run and verify RED:

  ```powershell
  # apps/admin
  npm test -- src/components/casework/casework.test.tsx

  # apps/mobile
  flutter test test/verified_badge_page_test.dart --reporter compact
  ```

- [ ] Replace the two separate block rows in `DecisionPanel` with one wrapping footer:

  ```tsx
  <span className="mt-1 flex flex-wrap items-start gap-x-3 gap-y-1">
    <span className="min-w-0 flex-1 ...">{validationError}</span>
    <span className="ml-auto shrink-0 text-right ...">{reason.length} / 500</span>
  </span>
  ```

  When the error cannot fit beside the counter, normal flex wrapping moves the counter to the next row while keeping it right-aligned.

- [ ] Give the Verified Badge statement a dedicated footer/counter builder with full input width and `Alignment.centerRight`, matching the admin field's visual rule while retaining Flutter accessibility semantics.
- [ ] Re-run both focused tests and verify GREEN.

---

## Task 4: Compact the System notification list cards

- [ ] Rewrite the existing System card widget test first to require the new compact structure: white card, compact header, two-line title, short brief preview, and one footer row with `View more` left and the date right.
- [ ] Add a long-copy widget test proving the title/body truncate without moving the date into a separate vertical block or overflowing a narrow viewport.
- [ ] Run and verify RED:

  ```powershell
  flutter test test/chat_widgets_test.dart --plain-name "system notification card" --reporter compact
  ```

- [ ] Change the System section scaffold body to the same light gray surface used by Settings (`#F4F6F8` family), while retaining the white app bar.
- [ ] Refactor `SystemNotificationCard` to reduce vertical padding and use:
  1. compact System Notification header + overflow menu,
  2. title and brief preview,
  3. one footer row: `View more` at left, formatted date at right.
- [ ] Keep unread tint/border and unread dot, whole-card tap, delete menu, and confirmation behavior.
- [ ] Re-run the focused card tests and verify GREEN.

---

## Task 5: Introduce structured System notification detail content

- [ ] In `chat_models_test.dart`, first add failing cases for structured payload getters:
  - `brief`
  - `decision_label`
  - `decision_message`
  - `creator_badge_awarded`
  - `creator_request_rejected`
  - `post_rejected`
  - `reported_post_removed`
  - `reported_comment_removed`
- [ ] Add backward-compatibility tests proving old creator-award rows do not display the previous long “We appreciate the time...” text. Old rows receive a concise fallback congratulations message.
- [ ] Replace the current creator-detail widget test with a failing target-layout test: retained app bar, gray body, title/date/brief first, then a white decision container.
- [ ] Run and verify RED:

  ```powershell
  flutter test test/chat_models_test.dart test/chat_widgets_test.dart --reporter compact
  ```

- [ ] Add model-level presentation getters that prefer structured payload values and provide safe compatibility copy for older notifications. Do not parse arbitrary user-facing paragraphs in widgets.
- [ ] Redesign `SystemNotificationDetailPage`:
  - white retained app bar with Back/Delete;
  - light gray page body;
  - title, date/time, and concise brief at the top;
  - white rounded decision card containing `Congratulations`, `Decision`, or `Administrator feedback` and the system/admin message;
  - optional post link/evidence inside the decision card only when the notification carries a post.
- [ ] For verified approval, display the list/detail title `Verification Application`, a short reviewed-account brief, and the administrator's approval message in the white container. Remove the hard-coded long creator-programme copy from presentation fallbacks.
- [ ] For creator rejection, report removal, and moderation rejection, show the administrator/moderation reason in the white decision card.
- [ ] Re-run focused model/widget tests and verify GREEN.

---

## Task 6: Update SQL notification payloads without breaking old rows

- [ ] Write failing SQL contract tests in `chat_sql_migration_test.dart` and `adminSql.test.ts` for the new compact titles and structured payload fields.
- [ ] Require report-removal payloads to distinguish post vs comment and include the administrator reason.
- [ ] Require creator-request approval/rejection payloads to carry the administrator message/reason, while proactive creator assignment retains concise generic fallback copy when no user-facing message was entered.
- [ ] Run and verify RED:

  ```powershell
  # apps/mobile
  flutter test test/chat_sql_migration_test.dart --reporter compact

  # services/api
  npm test
  ```

- [ ] In `supabase/chat.sql`, replace the creator-award trigger's long body with compact `Verification Application` copy and structured payload defaults.
- [ ] In `supabase/admin_portal.sql`:
  - enrich the creator-request approval notification created by the profile trigger with `creator_request_id`, `brief`, `decision_label`, and the mandatory `v_reason` as `decision_message`;
  - make creator rejection use the same structured contract;
  - add `template_type`, `target_type`, `brief`, `decision_label`, and `decision_message: v_reason` to report-removal notifications;
  - label post removals `reported_post_removed` and comment removals `reported_comment_removed`;
  - give appeal-outcome notifications explicit template metadata, without making those outcome notifications appealable.
- [ ] Keep UI compatibility fallbacks because applying SQL changes does not backfill existing notification rows automatically.
- [ ] Re-run both SQL/API contract tests and verify GREEN.

---

## Task 7: Support one final appeal for eligible moderation notifications

- [ ] Add failing model tests for `isAppealableModerationNotification`: true only for `post_rejected` and `reported_post_removed`; false for creator decisions, appeal outcomes, publication approvals, creator-status changes, and removed comments.
- [ ] Replace the repository boolean test with a failing `PostAppealState` test covering `none`, `pending`, `approved`, and `rejected`.
- [ ] Add failing detail widget tests for:
  - no appeal: the inline appeal form with no empty-state status;
  - successful submission: the reason field disappears immediately and status becomes `Appeal submitted` above a disabled action;
  - pending: labelled `Appeal submitted` above a disabled action;
  - approved: labelled `Appeal approved` above a disabled action;
  - rejected: labelled `Appeal rejected` / final decision above a disabled action;
  - non-appealable notification: no appeal status and no form.
- [ ] Add failing SQL tests proving owners may submit one appeal for a post in `rejected` or `removed` moderation state, and that `unique (post_id, user_id)` plus RPC validation prevents a second appeal.
- [ ] Run and verify RED:

  ```powershell
  flutter test test/chat_models_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_sql_migration_test.dart --reporter compact
  ```

- [ ] Add `PostAppealState` to the mobile model and replace `hasPostAppeal` with `fetchPostAppealState`, selecting `status` from `post_appeals`.
- [ ] In `SystemNotificationDetailPage`, render appeal state only for eligible post-moderation notifications. After submission, set the state to Pending immediately and disable the action.
- [ ] Keep all non-`none` states final at the client: no second form opens for Pending, Approved, or Rejected.
- [ ] Update `submit_post_appeal` in `supabase/chat.sql` to accept the owner of a post whose moderation state is either `rejected` (AI/moderation rejection) or `removed` (administrator removal after reports).
- [ ] Update `decide_post_appeal` in `supabase/admin_portal.sql` to review appeals whose original post is `rejected` or `removed`; approval republishes, rejection leaves the original moderation state unchanged. Existing row uniqueness and decided-status checks remain the server-side final-decision enforcement.
- [ ] Re-run the focused mobile tests and verify GREEN.

---

## Task 7A: Inline the appeal form and clarify System detail hierarchy

**Files:**
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart`
- Modify: `Project_Overview.md`

- [x] Rewrite the detail widget tests first so every System notification shows an `Admin:` label immediately above its white reason-only container, including a non-report creator notification.
- [x] Add a failing layout assertion for the appeal status location; Task 7B supersedes the original timestamp placement with status inside the lower appeal section.
- [x] Replace the bottom-sheet interaction test with a failing inline-form test: the reason field and Submit appeal action render directly in the detail page, a valid submission immediately changes status to `Appeal submitted`, and the reason field disappears after submission.
- [x] Retain failure coverage proving an unsuccessful inline submission preserves the typed reason and displays retry feedback.
- [x] Run `flutter test test/chat_widgets_test.dart --reporter compact` from `apps/mobile` and verify the new assertions fail because the status is still near the bottom, `Admin:` is absent, and the form still requires a bottom sheet.
- [x] Refactor `PostAppealForm` to notify its parent through an `onSubmitted` callback instead of calling `Navigator.pop`; remove sheet-only SafeArea, keyboard-inset, Cancel, and autofocus behavior so it is a normal inline section.
- [x] Remove `showModalBottomSheet` and the standalone Appeal decision launcher from `SystemNotificationDetailPage`; render `PostAppealForm` directly for eligible notifications whose state is `none`, and set state to Pending from `onSubmitted`.
- [x] Remove the timestamp-level appeal banner. Task 7B keeps Pending, Approved, and Rejected/final read-only inside the lower appeal section immediately above a disabled action.
- [x] Add `Admin:` above `_SystemDecisionCard` for every System detail and keep the card body limited to `_moderationReason ?? notification.systemDecisionMessage`.
- [x] Reserve, in documentation only, the section after the administrator reason/post link and before the inline form for a future Gemini moderation evidence panel containing risk score plus `ai_moderation_reason` / flag evidence. Do not render placeholder UI or invent values before the real moderation workflow exists.
- [x] Run the focused widget test again and verify GREEN, then format both Flutter files and run the full mobile tests plus `flutter analyze`.

---

## Task 7B: Correct appeal presentation and recover administrator reasons

**Files:**
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/test/chat_repository_test.dart`
- Modify: `apps/mobile/test/chat_sql_migration_test.dart`
- Modify: `services/api/src/admin/adminSql.test.ts`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `supabase/admin_portal.sql`
- Modify: `Project_Overview.md`

- [x] Add failing widget tests requiring a gavel icon beside `Send an appeal`, no pre-submission status, `Appeal submitted` after a successful submission, final approved/rejected status where applicable, and status placement in the lower appeal section immediately above its disabled action.
- [x] Add a failing widget geometry assertion requiring the `0 / 500` counter's right edge to align with the appeal input border's right edge.
- [x] Add failing detail tests proving a generic creator award and creator-status removal replace fallback copy with a reason returned by the notification-reason loader.
- [x] Add failing repository/SQL contract tests for an owner-checked `fetch_system_notification_reason(p_notification_id)` RPC and structured `decision_message` payloads on account-status and creator-status notifications.
- [x] Run the focused Flutter, API SQL-contract, and widget tests and verify RED for the missing icon, incorrect status behavior/position, default counter layout, missing generic reason loader, and missing SQL resolver/payloads.
- [x] Add `ChatRepository.fetchSystemNotificationReason(notificationId)` and load it for every System detail whose payload lacks `decision_message`; keep the payload message as the first choice and fallback copy only when recovery returns no reason.
- [x] Add `fetch_system_notification_reason` as a `security definer` RPC that requires authentication, verifies the notification belongs to `auth.uid()`, and recovers only that notification's reason from creator requests, posts/comments, post appeals, or matching user-targeted administrator audit records.
- [x] Persist `template_type`, `brief`, and `decision_message: v_reason` when account status or creator status changes create new notifications, so the RPC is primarily a legacy compatibility path.
- [x] Revise the inline appeal section: gavel icon header; explicit right-aligned full-width counter; no status for `none`/loading; `Appeal submitted` for pending; approved/rejected final status above a disabled submit action.
- [x] Re-run focused tests to verify GREEN, format Dart code, update `Project_Overview.md`, then run full mobile tests, Flutter analysis, API tests/build, and `git diff --check`.

---

## Task 7C: Correct rejected-post link hierarchy

- [x] Add a failing widget assertion that the rejected-post action reads `View post`, never displays the post title, and appears above `Admin:`.
- [x] Replace the title-based inline link label with fixed `View post` copy and move it between the notification brief and `Admin:`.
- [x] Preserve the area after the administrator reason card for future risk score and `ai_moderation_reason` / flag evidence, then run the full mobile suite and analyzer.

---

## Task 7D: Align post-publication success details

- [x] Add failing model and widget tests requiring `Your post has completed moderation review.` as the explanatory brief and the publication result alone in the shared white card.
- [x] Add a failing SQL contract requiring structured `brief` and `decision_message` fields on new `post_approved` notifications.
- [x] Split legacy post-approved bodies in the mobile model, normalize previously stored greeting-only briefs, and persist the two fields separately for new notifications.
- [x] Run the full mobile suite, Flutter analysis, API tests/build, and `git diff --check`.

---

## Task 8: Documentation, formatting, and complete verification

- [x] Update `Project_Overview.md` to record:
  - foreground realtime Activity/System/New Followers badge/list updates;
  - compact System list/detail structure and structured admin feedback;
  - one final appeal for administrator-rejected AI-flagged or report-removed posts only;
  - the unchanged FCM and live SQL deployment gaps;
  - the verified eligibility threshold remains unenforced until pre-deployment.
- [ ] Format production and test code:

  ```powershell
  # repository root
  dart format apps/mobile/lib apps/mobile/test
  ```

- [x] Run the complete mobile verification from `apps/mobile`:

  ```powershell
  flutter test --reporter compact
  flutter analyze
  ```

- [x] Run the complete admin verification from `apps/admin`:

  ```powershell
  npm test
  npm run typecheck
  npm run build
  ```

- [x] Run the complete API verification from `services/api`:

  ```powershell
  npm test
  npm run typecheck
  npm run build
  ```

- [ ] Perform visual QA against the supplied references at matching narrow mobile and wide admin viewport states. Compare reference and implementation side-by-side, specifically checking card height, gray/white surfaces, image edge gaps, footer wrapping, title truncation, date alignment, and appeal-button disabled states. Use the user's selected browser/device surface before calling visual verification complete.
- [x] Review `git diff --check` and `git diff --stat`; preserve all unrelated existing working-tree changes.

---

## Acceptance checklist

- [ ] A newly inserted Activity, System, or New Followers notification updates the bottom badge without first visiting Messages or that section.
- [ ] An open notification section updates while the app is foregrounded.
- [ ] Creator Requests uses the exact Users post placeholder/card/detail interaction.
- [ ] No post-card media region has an inline white strip.
- [ ] Admin validation error and count share a row when space allows and wrap safely when it does not.
- [ ] Verified Badge count is pinned to the input's bottom-right edge.
- [ ] System cards are compact, with View more and date in one footer row.
- [ ] Detail pages use gray background plus a white decision/congratulations container.
- [ ] The old creator-award “We appreciate the time...” copy is not shown.
- [ ] Verified approval is titled `Verification Application` and shows administrator-authored feedback when available.
- [ ] Only administrator-rejected AI-flagged and report-removed posts expose appeal state/action.
- [ ] Pending, approved, and rejected appeals cannot be submitted again; rejected is labelled final.
- [ ] Full mobile, admin, and API test/build/analyze commands pass before completion is reported.
