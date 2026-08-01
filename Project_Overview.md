# CyanZone Project Overview and SRS Delivery Handover

Last reviewed against the workspace and **Software Requirement Specification.docx**: **August 1, 2026**

This is the canonical starting point for a developer or AI session. Source code, tests, and SQL remain authoritative for what is implemented. The Software Requirement Specification (SRS) is authoritative for what CyanZone must deliver.

## Delivery rule

- Every functional and non-functional requirement in the reviewed SRS is a delivery obligation.
- A requirement marked **Partial**, **Not implemented**, or **Unverified** below remains in the backlog until implementation and acceptance evidence exist.
- Do not treat an implemented UI shell, database table, or placeholder as a completed end-to-end feature.
- If the product scope changes, revise the SRS and this traceability section together instead of silently dropping the requirement.
- The repository uses `is_content_creator` for the SRS concept named `is_verified_creator`. Treat these as the same business status unless the schema and SRS are deliberately renamed together.

## Product and architecture

CyanZone is a mobile-first, parent-supervised educational and interest-based social platform for teenagers, parents, and content creators.

- Mobile: Flutter/Dart for Android, Supabase Flutter, SharedPreferences, `photo_manager`, and `image_picker`.
- Administration Portal: React, TypeScript, Vite, Tailwind, and Supabase JS.
- Privileged API: Node.js, Express, TypeScript, Zod, and the Supabase service role.
- Platform: Supabase Auth, PostgreSQL, Row Level Security (RLS), Storage, and Realtime.
- Required AI moderation: Google Gemini API for public text and image posts and public comments, server-side only.
- Required push delivery: Firebase Cloud Messaging (FCM) for supported Android notifications.
- Required deployment target: Vercel for the Administration Portal and Express API/Vercel Functions.
- Version control: Git with the GitHub `origin` repository.

Gemini moderation, FCM push delivery, and verified Vercel deployment are not implemented yet. Private direct and group chat messages are intentionally excluded from AI moderation.

## Stable product rules

- Public registration creates a normal user; it must never assign administrator or verified creator status.
- Parent/child capabilities come only from an accepted `parent_child_links` relationship.
- A user may hold only one parent-supervision role at a time while links are active.
- Creator badges require administrator-controlled verified creator status.
- Administrator accounts are separate web-portal operators.
- Supabase anon keys are client-safe; service-role, Gemini, FCM server, and bootstrap secrets are backend-only.
- Public posts, edited posts, and public comments must remain unpublished until the SRS moderation outcome is known.
- Private chat is not submitted to Gemini.

## Repository map

```text
apps/mobile/                    Flutter Android application
apps/admin/                     React Administration Portal
services/api/                   Express privileged API
supabase/                       Base schema and incremental SQL
docs/setup.md                   Local and database setup
docs/superpowers/specs/         Approved/historical designs
docs/superpowers/plans/         Historical implementation plans
```

Important mobile entry points:

```text
apps/mobile/lib/main.dart
apps/mobile/lib/src/features/auth/
apps/mobile/lib/src/features/shell/presentation/main_shell.dart
apps/mobile/lib/src/features/chat/
apps/mobile/lib/src/features/posts/
apps/mobile/lib/src/features/profile/
apps/mobile/lib/src/features/parent_child/
```

## SRS roles and development baseline

- Normal users include teenagers, parents, and content creators. Teenagers are the primary audience; parent-only access begins after successful linking; verified creators remain normal users.
- System Administrators operate the web Administration Portal and require moderation procedures and basic data-management knowledge, not an advanced technical background.
- The documented development/test baseline is Windows 10/11 with Visual Studio Code, an Intel Core i5 or equivalent, 8 GB RAM, 256 GB SSD, an Android test phone, and stable internet access.
- The required software baseline is represented by the stack above: Flutter/Dart, React/Vite/TypeScript/Tailwind, Node/Express/TypeScript, Supabase/PostgreSQL/Auth/RLS/Storage/Realtime, FCM, Gemini, Git/GitHub, and Vercel. FCM, Gemini, and Vercel remain pending as stated above.

## SRS functional traceability

Status meanings:

- **Implemented**: the current repository contains the required end-to-end behavior and supporting controls.
- **Partial**: a meaningful part exists, but one or more SRS flows, rules, or integrations are missing.
- **Not implemented**: only planning, schema fields, placeholders, or no implementation exists.

| ID | SRS level | Feature | Status | Current evidence and remaining boundary |
| --- | --- | --- | --- | --- |
| F001 / REQ_F001 | Basic | User Authentication | **Implemented** | Mobile and administrator login, authenticated sessions, confirmation-based mobile and Administration Portal logout, and mobile password change with current-password reauthentication are implemented. New mobile registration passwords, changed passwords, and administrator bootstrap passwords require at least 12 characters with uppercase, lowercase, number, and non-whitespace symbol; `.` and `_` are accepted symbols. Existing passwords remain valid for login until changed. |
| F002 / REQ_F002 | Basic | User Registration | **Partial** | Email/password/name registration and strong-password validation exist. The registration UI does not display and require acceptance of Terms and Conditions and Privacy Policy, and it does not provide the specified OTP entry/verification flow and explicit activation gate. |
| F003 / REQ_F003 | Basic | User Profile Management | **Implemented** | Own/other public profiles, own-profile editing, follow/unfollow, follower/following lists, public creator badge display, and database protection against self-following are present. Administrator assignment/removal of creator status remains under F011. |
| F004 / REQ_F004 | Intermediate | Social Feed | **Partial** | Feed browsing, search, create/edit/soft-delete, selection of one to five predefined tags, `Others` fallback, image and text posts, profiles, saves/following views, and media flows are implemented. New and edited posts are not yet processed by the required Gemini publication workflow. UC004 must state one to five predefined tags, not exactly one tag. |
| F005 / REQ_F005 | Intermediate | Post Engagement | **Partial** | Comments/replies, likes, saves, chat sharing, and private 14-day dislike hiding are implemented. Public comments are still missing Gemini moderation before publication. |
| F006 / REQ_F006 | Intermediate | Content Reporting | **Implemented** | Users submit reason-only reports for public posts and comments. The repository report lifecycle is `pending_review` to `resolved` (Remove) or `dismissed` (Retain), with no separate Open/Reviewing state or reporter description. The Administration Portal groups cases by target, shows total/unique counts in a reason pie chart and legend, keeps two-line queue previews, and opens complete post evidence through the shared Post Detail viewer. `REPORT_REVIEW_THRESHOLD=1` is a testing convenience only and must be changed to `1000` before deployment. The destructive `report_flow_simplification.sql` migration is committed but has not been applied to the live Supabase project. |
| F007 / REQ_F007 | Advanced | AI-Assisted Content Moderation | **Not implemented** | Moderation fields, pending/rejected UI states, post-appeal storage, rejected-post notifications, and a Pending-to-Approved publication-success notification foundation exist, but there is no Gemini route or worker. The below-40% approve, 40%-60% administrator review, above-60% reject, 20-second timeout, retry/failure behavior, and post/comment integration remain required. |
| F008 / REQ_F008 | Advanced | Parent Supervision | **Partial** | Link retrieval/status display, basic repository methods, screen-time table access, a family page, and basic SOS record creation exist. Linking acceptance/rejection, role rules, usage tracking/alerts, check-ins, location, linked-parent alerts, records, and two-party unlinking are incomplete. |
| F009 / REQ_F009 | Intermediate | Real-Time Communication | **Partial** | Direct/group realtime chat, group administration, text/image/shared-post messages, read state, clear chat, and member-only access are implemented. Message-request database/repository foundations exist and a sender is capped at three messages while a request is pending, but the recipient Accept action is not exposed in the mobile UI and the complete request flow has not been verified end to end. Do not claim message requests are complete yet. Group-member eligibility also accepts users from accepted recent chats, while the current SRS limits selection to Followers and Following; this rule still needs a product decision or SRS revision. |
| F010 / REQ_F010 | Intermediate | Notifications | **Partial** | Activity, New Followers, System lists, per-section/conversation unread counts, total Messaging-tab badge, preferences, rejected-post details, appeal submission, verified creator assignment/removal, rejected posts, Pending-to-Approved publication, reported-content removal, and both appeal-outcome notification foundations exist. Retaining reported content intentionally sends no author notification. FCM background/closed-app delivery, Pending Administrator Review feedback, and real Gemini moderation integration remain missing. |
| F011 / REQ_F011 | Advanced | Administration Portal | **Partial** | The functional portal includes Overview, Users, Creator Requests, grouped Reports, Appeals, and a production-facing AI-Flagged Content workflow with confirmations. Assign Creator, Retain Content, and AI Approve do not require manual reasons; Remove Creator, Remove Content, AI Reject, and both Appeal actions require 10-500 characters. Reason-free persisted actions receive stable internal audit text. Users excludes administrator profiles at the API query boundary and currently exposes creator decisions only. AI-Flagged data is still isolated locally; Gemini and the real AI queue remain deferred. |

## Current mobile implementation

### Foundation, profile, feed, search, and engagement

Implemented:

- Supabase auth/session gate, login and registration validation, confirmation-based logout, and password update with current-password reauthentication.
- A shared mobile strong-password policy for registration and password change: 12 or more characters with uppercase, lowercase, number, and any non-whitespace symbol; `.` and `_` are accepted.
- Five-tab shell: Home, Parent-Child, Create, Chats, and Profile.
- Waterfall feed with Feeds, Following, and Saves modes, refresh, filtering, and image/text posts.
- Search across posts and profiles with local/server history.
- Own/other profiles, follow graph, avatar editing/caching, post grids, and settings.
- Post creation/editing with up to nine images, custom picker/camera, tags, and storage cleanup.
- Post detail, like/dislike/save/share, comments/replies/mentions, comment likes, pinning, reporting, editing, and soft removal.
- A dislike hides the post from that user's discovery surfaces for 14 days and does not create a public product-facing dislike effect.
- Cached media/aspect ratios and weak-network presentation paths.

Important SRS boundary:

- Current post/comment schema defaults and client operations are prototype foundations, not completed AI moderation.
- Registration consent and OTP UX remain required under F002.

### Chat module

Implemented chat home:

- Activity, System, and New Followers shortcuts with unread counts.
- Search by user, group, or chat name, including cached offline chat-history search.
- All, Unread, Groups, and Requests filters.
- Conversation previews, timestamps, unread badges, and 30-day request display behavior.
- Bottom navigation badge combining unread messages and notification-section sources.

Implemented conversations:

- Direct and group creation, realtime refresh, and recent local cache.
- Message-request foundations and a sender-side cap of three messages while the request remains pending.
- Text, multi-image, and shared-post messages.
- Multiple-image grids and full-screen preview/download.
- Message selection, multi-select, copy, delete-for-me with Undo, and ten-minute unsend.
- Unread divider, entry positioning, keyboard-safe scrolling, and jump-to-bottom control.
- Current-user-only clear chat.
- Group rename, add/remove members, admin display, exit, and final-member cleanup.
- Group mentions, repeated tappable mention spans, admin-only `@all`, unvisited mention indicators, and mention traversal.
- Storage cleanup for unsent/deleted chat images and deleted empty groups.

Chat constraints:

- Cloud-centric Supabase chat; no end-to-end encryption in this prototype.
- No AI moderation or administrator review of private chat.
- No calls, audio messages, stickers, or reactions.
- The recipient-side Accept action and a live end-to-end message-request acceptance test are still missing; the three-message rule is a pending-request send cap, not three individually accepted messages.
- Group member selection must be narrowed to the SRS Followers/Following rule unless the SRS is formally revised.

### Activity, New Followers, and System Notifications

Implemented:

- Activity events for likes, saves, comments, replies, comment likes, and mentions.
- Category filtering, target previews, post/comment navigation, and unavailable-target feedback.
- New Followers limited to the latest 30 days and deduplicated to the latest relevant event.
- Profile navigation plus Follow Back and Message actions.
- Per-row unread dots, read-on-exit behavior, resume refresh, and `99+` badge capping.
- System notification list/card/detail UI, read state, confirmation-based notification deletion, and missing-post handling.
- Rejected-post evidence display and owner-only appeal submission.
- Verified creator award System notification foundation.
- In-app notification preference controls.

Still required:

- Pending Administrator Review feedback and the remaining automatic moderation
  notifications once the real Gemini workflow exists. Creator status,
  rejected posts, Pending-to-Approved publication, reported-content removal,
  and both appeal outcomes already have in-app notification foundations;
  retaining reported content intentionally sends none.
- FCM token registration, Android runtime notification permission, secure server-side delivery, background/terminated handling, deep links, retries, and device tests.

### Sharing and post image preview

Implemented:

- Post-detail share sheet with recent chat contacts and shared-post messages.
- Adaptive/expandable share-sheet height.
- Native text selection for post title/content.
- Black full-screen preview with counter, download, paging, zoom, pan, and gesture close.
- Carousel synchronization after returning from preview.
- Offline detail behavior limited to the cached first image.

### Parent Supervision foundation

Implemented foundation:

- `parent_child_links`, `screen_time_logs`, `check_ins`, and `sos_alerts` schema/RLS foundations.
- Link retrieval and parent/child/status display.
- Repository methods for invite creation, link status update, screen-time retrieval, and SOS creation.
- Basic Safety Center and confirmation-based SOS submission.

This is not yet an SRS-complete supervision module. The detailed backlog below is required.

## Backend, database, and Administration Portal

### Express API

Implemented routes:

```text
GET  /health
POST /admin/bootstrap
GET  /admin/overview
GET  /admin/users
GET  /admin/users/:userId
GET  /admin/users/:userId/posts
GET  /admin/posts/:postId
POST /admin/users/:userId/account-status
POST /admin/users/:userId/creator-status
GET  /admin/creator-requests
GET  /admin/creator-requests/:requestId
POST /admin/creator-requests/:requestId/decision
GET  /admin/report-cases
GET  /admin/report-cases/:targetType/:targetId
POST /admin/report-cases/:targetType/:targetId/decision
GET  /admin/appeals
GET  /admin/appeals/:appealId
POST /admin/appeals/:appealId/decision
```

All `/admin/*` casework routes require a valid bearer session belonging to an
active administrator. Administrator decisions require a 10-500 character
reason. Administrator bootstrap rejects passwords that do not meet the same
12-character uppercase/lowercase/number/symbol policy used by the mobile app.

`GEMINI_API_KEY` is optional in the current code only because moderation routes do not exist. SRS completion requires server-side Gemini credentials and moderation endpoints/workers with structured validation, timeouts, retries, and audit logging.

### Administration Portal

Implemented:

- Supabase administrator login and session handling.
- `is_admin` and active-account authorization check.
- Responsive Casework Desk navigation and accessible confirmation-based logout with cancel, progress, and failure states.
- Operational Overview shortcuts and the latest 15 audited decisions in an internally scrollable panel.
- User search/filter/detail and confirmed assign/remove creator controls. Assigning creator access requires no manual reason and automatically uses the existing creator-award notification trigger; removal requires a 10-500 character reason and sends the removal notification. Administrator profiles are excluded from Users rows and totals by the API repository. Suspend/Reactivate is hidden from the current Users scope, while its API/RPC foundation remains available. Permanent user deletion is intentionally unavailable. Creator identity uses the same blue circular check as the mobile app; **Approved** remains a content-moderation status and is not an identity badge.
- User detail exposes a latest-five horizontal post carousel whose side controls appear only on real overflow. Cards use an explicit top-aligned column layout, cover media fills the image region edge-to-edge with `object-cover`, and hover clearance keeps the lifted border visible. The filter-free four-column **See All** modal reuses a large Post Detail viewer whose stage-bounded `object-contain` images remain fully visible, with side Previous/Next controls, bottom dots, title, full content, tags, publication date, moderation status, and approved comments/replies.
- Creator Request Pending/Approved/Rejected queues with profile evidence and confirmed approval/rejection.
- Grouped Report queues for Pending Review, Resolved, and Dismissed with two-line target previews, visibility evidence, a horizontal report-reason pie chart/legend, post-only **View Post >** access to the shared Post Detail viewer, inline comment evidence, and confirmed Retain/Remove decisions. Retain requires no manual reason and sends no author notification; Remove requires a 10-500 character reason and sends the existing removal notification. The current `REPORT_REVIEW_THRESHOLD=1` is for functional testing; set it to `1000` before deployment.
- Appeal Pending/Approved/Rejected queues with rejected content, original moderation evidence, owner-only mobile appeal submission, and confirmed approval/rejection. Both administrator actions require a 10-500 character reason and send their existing outcome notification. The mobile submission and administrator decision paths are functionally testable now.
- AI-Flagged Content uses normal production-facing queue/detail/status/score/decision wording, count-free queue tabs, and confirmation dialogs. Approve requires no manual reason; Reject requires a 10-500 character reason. Its six-case adapter/data remains isolated locally and does not create real notifications.

Reason-free persisted Assign Creator and Retain Content requests are converted by
the API service to stable internal audit reasons before the existing non-null SQL
audit boundary. The real moderation foundation also creates a publication-success
System notification only when a post changes specifically from `pending` to
`approved`, avoiding duplicate generic messages for approved appeals.

The AI preview must be replaced, not extended, when Gemini integration begins.
Delete or replace these temporary files:

```text
apps/admin/src/features/aiFlagged/aiFlaggedMockData.ts
apps/admin/src/features/aiFlagged/aiFlaggedMockAdapter.ts
```

Keep the reusable UI/types only after reconnecting them to the authenticated
Admin API and real moderation records.

### Supabase

The base schema and incremental scripts cover profiles, posts/interactions, follows, tags/search, parent-child foundations, chat, in-app notifications, System notification templates, appeals, and storage.

Important scripts:

```text
supabase/storage.sql
supabase/schema.sql
supabase/auth.sql
supabase/search.sql
supabase/tags.sql
supabase/follow.sql
supabase/post_interactions.sql
supabase/post_editing.sql
supabase/comment_moderation.sql
supabase/comment_mentions.sql
supabase/chat.sql
supabase/admin_portal.sql
```

The `images` bucket stores post and chat images. Deleted posts, unsent image messages, and final-member group deletion should clean up related objects.

Before relying on a live Supabase project, apply and verify the current SQL in the documented order. Repository SQL does not prove the remote database is current, and notification triggers do not backfill historical events.

## Required implementation to-do list

Complete these items against the exact SRS flows and rules. Check an item only after implementation, automated tests, and relevant integration/device acceptance evidence exist.

### 1. Authentication and registration

- [x] Add mobile and Administration Portal logout confirmation dialogs with Cancel and Log out outcomes.
- [x] Require current-password verification before accepting a new mobile password.
- [x] Enforce the 12-character uppercase/lowercase/number/symbol policy on mobile registration, mobile password change, and administrator bootstrap without invalidating existing login passwords.
- [ ] Display Terms and Conditions and Privacy Policy during registration and require explicit consent before submission.
- [ ] Implement the email OTP entry, validation, resend/error states, and account-activation gate.
- [ ] Verify inactive/unverified normal users cannot enter protected mobile functions.
- [ ] Add widget/integration tests for all F001/F002 main and alternate flows.

### 2. AI moderation and public-content publication

- [x] Allow one to five predefined tags on post creation/editing and use `Others` when no listed topic fits; predefined tag administration remains out of scope.
- [ ] Define the versioned moderation request/response schema for text, images, combined posts, and comments.
- [ ] Implement server-side Gemini calls; never expose the Gemini key to Flutter or React.
- [ ] Enforce SRS thresholds: below 40% approve, 40%-60% inclusive queue for administrator review, and above 60% reject.
- [ ] Keep new posts, edited posts, and public comments unpublished until moderation finishes.
- [ ] Complete the initial assessment within 20 seconds under normal conditions; on timeout/failure keep content unpublished and show retry/error feedback.
- [ ] Add bounded retry handling and idempotency so repeated submissions do not duplicate content or decisions.
- [ ] Persist risk score, evidence/reason, status, timestamps, model/version, and decision source for audit.
- [ ] Connect the implemented Approved/Rejected notification foundations and add Pending Administrator Review feedback through the real Gemini workflow.
- [ ] Add text, image, combined-content, comment, timeout, quota, malformed-response, and retry tests.

### 3. Reporting, appeals, and Administration Portal

- [x] Prevent the same user from creating multiple unresolved reports for the same post/comment in repository SQL.
- [x] Group the queue by post/comment target without automatic removal; use `REPORT_REVIEW_THRESHOLD=1` only for functional testing and change it to `1000` before deployment.
- [x] Simplify report storage to reason-only `pending_review`, `resolved`, and `dismissed` records; commit the manual migration without applying it remotely.
- [ ] Replace the temporary AI-Flagged Content mock adapter/data with Gemini-backed moderation records and authenticated API reads/decisions.
- [x] Build the User-Reported Content queue with total/unique counts, a reason pie chart/legend, two-line content previews, shared post evidence, inline comment evidence, and Retain/Remove actions.
- [x] Record moderator identity, decision, reason, and timestamps; update public visibility atomically.
- [x] Build the Content Appeals queue/detail and Approve/Reject workflow.
- [x] On approved appeal, publish the content; on rejected appeal, retain rejection; record an owner notification in both cases.
- [x] Build user listing/search/detail with public profile, true published-post counts, latest-five horizontal carousel, See All grid, complete post media/content/status, and approved comment/reply review.
- [x] Build confirmed assign/remove verified creator controls mapped consistently to `is_content_creator`.
- [x] Record creator assignment/removal, rejected-post, Pending-to-Approved publication, reported-content removal, and both appeal-outcome notifications; Retain intentionally sends none.
- [x] Replace placeholder dashboard links/metrics with functional SRS pages; advanced analytics remain out of scope.
- [x] Add administrator authorization, RLS, API, audit, component, and responsive browser workflow tests.
- [ ] Apply and verify `supabase/admin_portal.sql` against the live Supabase project before acceptance or deployment.

### 4. Parent Supervision

- [ ] Implement Link Parent Account and Link Child Account selection from the user's Following list.
- [ ] Implement pending link requests, recipient confirmation, accept/reject, duplicate prevention, and success/error messages.
- [ ] Enforce one supervision role per user while relationships exist.
- [ ] Track each user's CyanZone usage time and display their own current usage.
- [ ] Let linked parents view only their linked children's usage.
- [ ] Generate the first screen-time alert after three hours and another after every subsequent completed hour for the user and linked parent.
- [ ] Implement child-only Safety Check-In with a required short message and optional location.
- [ ] Request operating-system location permission only when needed; allow check-in/SOS without location and explain the fallback.
- [ ] Restrict SOS to a successfully linked child, record time/location availability, and immediately alert the linked parent.
- [ ] Build Safety Check-In and SOS history with type, date, time, message, and available location.
- [ ] Implement password-verified, two-party unlink requests with Pending, Approved, and Rejected outcomes.
- [ ] Stop new supervision sharing after approved unlink while preserving historical records for the former linked parent/child only.
- [ ] Add RLS and integration tests for every role, relationship state, permission outcome, and former-link history rule.

### 5. Notifications and FCM

- [ ] Add Firebase configuration and `firebase_messaging` for the Android app.
- [ ] Request Android notification permission and preserve in-app notifications when permission is denied.
- [ ] Register, refresh, revoke, and securely store per-device FCM tokens.
- [ ] Implement server-side push dispatch for supported messages, engagement, followers, moderation, appeal, creator, screen-time, check-in, and SOS events.
- [ ] Respect notification preferences and intended-recipient authorization.
- [ ] Handle foreground, background, and terminated app states with safe deep links to the correct conversation or notification detail.
- [ ] Add retry/deduplication/observability and Android device tests.

### 6. Chat conformance

- [ ] Add the recipient-side Accept action for pending message requests and verify the whole request flow against a live test database.
- [ ] Keep the sender-side three-message cap while a request remains pending; acceptance applies to the conversation, not to three individual messages.
- [ ] Restrict group member choices and server validation to Followers and Following as required by the SRS.
- [ ] Keep existing direct/group member authorization, sender/timestamp display, group-admin removal, member rename, and current-user-only clear-chat behavior covered by regression tests.

### 7. Non-functional requirements and release evidence

- [ ] Create a traceable acceptance suite mapping every SRS requirement ID to an automated or manual test.
- [ ] Measure login and feed load within 3 seconds under normal network conditions.
- [ ] Measure message send/display within 5 seconds and moderation status within 20 seconds.
- [ ] Show a loading indicator whenever an operation exceeds 3 seconds.
- [ ] Run at least 10 concurrent-user prototype tests without major functional failure.
- [ ] Run at least 15 minutes of continuous standard mobile use without crashes.
- [ ] Validate the two five-minute first-user usability scenarios and the three-navigation-step rule.
- [ ] Audit readable text, consistent layout, contrast, Android screen-size adaptation, clear labels, confirmations, and English-only scope.
- [ ] Standardize user-friendly network/database/Gemini failures and retry non-critical API requests up to two times.
- [ ] Test restart and temporary-network recovery for stored posts, comments, messages, and supervision records.
- [ ] Verify users can re-login and continue after an unexpected restart.
- [ ] Verify availability during scheduled tests/demos except planned maintenance and third-party outages.
- [ ] Test database migrations, application updates, and restoration procedures without loss of existing stored data.
- [ ] Maintain module, database, API, and AI moderation documentation as implementation changes.
- [ ] Review extension and reuse seams for common authentication, UI, API, validation, recommendation, creator-analytics, and moderation components.
- [ ] Complete an RLS/security review for normal users, administrators, linked families, reports, moderation, appeals, and notifications.
- [ ] Validate untrusted inputs again at the API/database boundary, not only in client forms.
- [ ] Verify HTTPS and secret handling in deployed environments.
- [ ] Add and verify Vercel deployment configuration for the Administration Portal and API.
- [ ] Test the Administration Portal on the latest Chrome and Edge versions used for project testing.
- [ ] Test the mobile app on the supported Android devices and common smartphone screen sizes.
- [ ] Run end-to-end interoperability tests across mobile, API, Administration Portal, Supabase, Gemini, and FCM.

## Non-functional requirement status

Passing unit/widget tests and builds do not prove the SRS timing, concurrency, usability, reliability, security, browser, device, or deployment targets.

| SRS category | Current status | Required evidence |
| --- | --- | --- |
| Performance | **Unverified** | Timed login/feed/UI/message/moderation measurements, loading indicators, 10-user concurrency, and 15-minute stability run. |
| Usability | **Partial / Unverified** | Timed first-user tasks, three-step navigation audit, feedback-state coverage, accessibility/contrast review, and English-scope review. |
| Reliability | **Partial / Unverified** | Crash-free workflow run, consistent graceful failures, two-retry behavior, and restart/network recovery tests. |
| Maintainability | **Partial** | Component separation and environment configuration exist; API/AI workflow documentation, traceability, and broader reusable test coverage remain. |
| Security | **Partial** | Supabase Auth/RLS and server-only secret architecture exist; OTP, consent, location permission, final family RLS, moderation/admin authorization, and deployment review remain. |
| Portability | **Partial / Unverified** | Android device/screen tests, Chrome/Edge tests, Vercel deployment, environment-only configuration verification, and end-to-end interoperability tests remain. |

## Verification state

Verification run directly in the user's PowerShell environment on **August 1, 2026**:

```powershell
cd apps/mobile
flutter test
flutter analyze

cd ../admin
# TypeScript project build, then Vite production build

cd ../../services/api
# Password-policy tests, then TypeScript build
```

Observed:

- Mobile test suite: **184 tests passed**.
- Flutter analyzer: **no issues found**.
- Administration Portal: **48 tests passed** across 14 test files; TypeScript type-check and Vite production build passed. The build reports only the existing large-chunk advisory.
- Express API: **46 tests passed**; TypeScript type-check and production build passed.
- Mobile appeal regressions: owner appeal widget failure-state preservation and repository appeal actions both passed.
- Earlier in-app-browser acceptance: approved Creator Requests visual compared side by side at
  **1510 x 1075**; narrow list/detail, Back action, navigation drawer, decision
  validation, and confirmation verified at **390 x 844** with no horizontal
  overflow.
- Current in-app-browser acceptance: verified the Users queue excludes administrators;
  a single-card carousel hides its controls; the card media fills its region and keeps
  eight pixels of hover clearance; creator verification uses the blue tick; and the
  shared Post Detail viewer contains media inside its stage and includes comments.
  Assign Creator opens confirmation without a reason, while Remove Creator validates a
  10-500 character reason before confirmation. Reports loaded three live Pending Review
  cases with the horizontal reason chart and shared **View Post >** dialog; Retain opens
  confirmation without a reason, while Remove validates its reason first. AI-Flagged
  Content uses count-free tabs and production-facing copy; Approve opens confirmation
  without a reason, while Reject validates its reason first. No browser console errors
  were recorded. The live database had no pending appeal to exercise non-destructively;
  both reason-required Appeal actions are covered by the passing component regression.

Not covered by this verification:

- Live Supabase migration/application state.
- Remote application of the latest `chat.sql` notification trigger remains required;
  the local SQL and static regressions verify the Pending-to-Approved transition rule.
- Gemini moderation or FCM, because they are not implemented.
- Android physical-device, location, background/terminated notification, or screen-size acceptance.
- Latest Chrome and Edge acceptance outside the in-app browser.
- Vercel deployment.
- SRS performance, concurrency, usability, reliability, recovery, and security acceptance.

## Recommended implementation order

1. Apply and verify `supabase/admin_portal.sql` against the live Supabase project and exercise the protected portal with a test administrator.
2. Complete parent supervision and location-aware safety flows.
3. Complete message-request acceptance, resolve the accepted-recent-chat group-member rule, and retain existing chat regressions.
4. Add FCM push delivery and notification deep links.
5. Complete F002 registration consent, OTP, and activation conformance.
6. Implement F007 Gemini moderation last, replace the two AI mock files, and connect the real AI-flagged queue to the protected Admin API.
7. Execute and record the complete non-functional acceptance suite and deployments.

## Risks and conventions

- Check `git status` before editing and preserve unrelated user changes.
- `post_detail_page.dart`, chat presentation files, and `main_shell.dart` are large and tightly coupled; prefer focused changes and regression tests.
- Remote Supabase schema/policies may differ from repository SQL; inspect before rerunning scripts.
- Do not confuse schema/UI foundations with end-to-end SRS completion.
- Keep service-role, Gemini, Firebase server, and bootstrap secrets out of Flutter, React, documentation examples, screenshots, and commits.
- Use Supabase directly for ordinary authenticated operations and Express for secrets and privileged workflows.
- Run every terminal command, test, analyzer, and build directly in the user's PowerShell environment outside the Codex sandbox. Request the required execution approval instead of silently falling back to sandboxed commands. This convention applies to every new chat.
- Use `apply_patch` for manual file edits.

## Branch and milestone naming

Use lowercase, hyphenated app-surface names for future milestone branches/worktrees:

- `mobile-v0.1.0-auth-and-feed`
- `mobile-v0.2.0-chat`
- `mobile-v0.3.0-parent-supervision`
- `mobile-v0.4.0-ai-moderation`
- `mobile-v0.5.0-fcm-notifications`
- `admin-v0.1.0-moderation-dashboard`

Treat mobile and Administration Portal versions as separate release lines because they ship different user experiences while sharing Supabase/API work.

## Environment variables

Mobile:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Administration Portal:

```text
VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY
VITE_API_BASE_URL
```

API:

```text
PORT
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
ADMIN_BOOTSTRAP_SECRET
REPORT_REVIEW_THRESHOLD
GEMINI_API_KEY
```

Set `REPORT_REVIEW_THRESHOLD=1` only while performing functional tests with the current small user population. Set it to `1000` before any deployment.

FCM server credentials and any Vercel-specific environment values must be added through secure deployment configuration when those features are implemented; never commit them.
