# CyanZone Project Overview and SRS Delivery Handover

Last reviewed against the workspace: **September 2, 2026**. The SRS traceability
baseline was last reviewed against **Software Requirement Specification.docx**
on **August 2, 2026**.

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
- A user may hold only one parent-supervision role at a time while links are pending or active.
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
| F008 / REQ_F008 | Advanced | Parent Supervision | **Partial** | Server-authoritative parent/child linking, role enforcement, role dashboards, foreground CyanZone screen-time tracking and threshold events, location-aware Check-In/SOS, SOS acknowledgement/resolution, safety records, dedicated realtime supervision notifications, and two-party unlink request/accept/reject flows are implemented. The user reports that `parent_supervision.sql` was applied to Supabase. The user has one small SOS adjustment planned; password reauthentication for unlink, former-link historical-record authorization, remote inspection, and multi-account/device acceptance remain incomplete or unverified. |
| F009 / REQ_F009 | Intermediate | Real-Time Communication | **Partial** | Direct/group realtime chat, group administration, text/image/shared-post messages, read state, clear chat, and member-only access are implemented. Message requests are intentionally hidden from active mobile loading and UI while their existing data and backend foundation remain dormant. Active direct-chat entry requires a current follow relationship in either direction, and group-member candidates/validation are limited to Followers and Following. Existing accepted conversations, history, and realtime behavior remain unchanged. The user applied the previous `chat.sql`; the updated follow-only functions still require live reapplication and verification. |
| F010 / REQ_F010 | Intermediate | Notifications | **Partial** | Activity, New Followers, and System notification rows/counts refresh through foreground Supabase Realtime even before their section is opened. Per-section/conversation unread counts, the total Messaging-tab badge, preferences, compact structured System details, and notification-side one-final-appeal handling for administrator-rejected AI-flagged or report-removed posts are implemented. Verified creator assignment/removal, creator-request decisions with administrator feedback, Pending-to-Approved publication, reported-content removal, and appeal-outcome notification foundations exist. The current AI-Flagged portal queue is still isolated mock data and cannot create a real rejection notification until the Gemini/admin moderation integration replaces it. Retaining reported content intentionally sends no author notification. FCM background/closed-app delivery and Pending Administrator Review feedback remain missing. |
| F011 / REQ_F011 | Advanced | Administration Portal | **Partial** | The functional portal includes Overview, Users, Creator Requests, grouped Reports, Appeals, and a production-facing AI-Flagged Content workflow with confirmations. Assign Creator, Retain Content, and AI Approve do not require manual reasons; Creator Request rejection, Remove Creator, Remove Content, AI Reject, and both Appeal actions require 10-500 characters. Reason-free persisted actions receive stable internal audit text. Users excludes administrator profiles at the API query boundary and currently exposes creator decisions only. AI-Flagged data is still isolated locally; Gemini and the real AI queue remain deferred. |

## Current mobile implementation

### Foundation, profile, feed, search, and engagement

Implemented:

- Supabase auth/session gate, login and registration validation, confirmation-based logout, and password update with current-password reauthentication.
- A shared mobile confirmation dialog standard covers logout, post update/deletion, chat message and group danger actions, notification deletion, and SOS submission.
- A shared mobile strong-password policy and live checklist are used by registration and password change: 12 or more characters with uppercase, lowercase, number, and any non-whitespace symbol. The checklist examples are `!`, `@`, `#`, `$`, `%`, and `&`; other symbols including `.` and `_` remain accepted.
- Five-tab shell: Home, Parent-Child, Create, Chats, and Profile.
- Waterfall feed with Feeds, Following, and Saves modes, refresh, filtering, and image/text posts; moderation-status badges use the same top-left card placement for both post types.
- Search across posts and profiles with local/server history.
- Own/other profiles, follow graph, avatar editing/caching, post grids, and settings.
- Settings includes a Verified Badge page with eligibility requirements, an application statement, direct submission through the existing protected creator-request table, and pending, rejected/reapply, and verified states. The current UI still displays an informational 10,000-follower threshold and does not enforce it. For the MVP/UAT population, the approved temporary target is **2 followers**; update both the display and authoritative submission enforcement before UAT. Rejected applicants are directed to System notifications for the administrator's reason.
- Verified creator identity uses the same CyanZone-cyan rosette with a white tick across mobile profile, follow, and search surfaces.
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
- All, Unread, and Groups filters. Message requests are not loaded or displayed.
- Conversation previews, timestamps, and unread badges.
- Bottom navigation badge combining unread messages and notification-section sources; the persistent shell owns foreground notification-table realtime refresh and resume refresh, while preserving the last confirmed count during loading or temporary failure.

Implemented conversations:

- Relationship-gated direct and group creation, realtime refresh, and recent local cache.
- Dormant message-request tables, models, RPCs, stored rows, and sender-side pending cap are retained for possible future restoration; active Flutter flows cannot create or open requests.
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
- Tapping Message on another profile checks the server-authoritative follow relationship in either direction. Without one, the profile remains open and shows `Follow this user before sending a message.`
- Existing accepted direct conversations remain available from Messages even after an unfollow, preserving established history.
- Group member selection and server validation use Followers and Following only; accepted direct-chat history and parent-child linkage alone do not qualify a candidate.
- Message-request acceptance is outside the active MVP scope. Request SQL is retained rather than commented out because comments would not disable objects already installed in Supabase.

### Activity, New Followers, and System Notifications

Implemented:

- Activity events for likes, saves, comments, replies, comment likes, and mentions.
- Category filtering, target previews, post/comment navigation, and unavailable-target feedback.
- New Followers limited to the latest 30 days and deduplicated to the latest relevant event.
- Profile navigation plus Follow Back and Message actions.
- Per-row unread dots, read-on-exit behavior, foreground realtime section refresh, resume refresh, and `99+` badge capping.
- Compact System cards use a shared View more/date footer; details retain the white app bar and use a light-gray page where every notification shows `Admin:` above a white reason-only container, plus read state, confirmation-based deletion, and missing-post handling. New decision notifications persist the administrator's reason in structured payloads; an owner-checked RPC recovers missing reasons for legacy creator, account, moderation, report-removal, and appeal notifications.
- Administrator-rejected AI-flagged and report-removed posts expose one server-enforced owner appeal. Their fixed `View post` link appears above `Admin:` and never exposes the post title in the notification detail. Before submission, the inline section shows a gavel-labelled `Send an appeal` form with a counter aligned to the input's right edge and no empty status. After submission, Pending, Approved, or Rejected/final status appears immediately above a disabled Submit appeal action. Removed comments and appeal-outcome notifications do not expose another appeal. Legacy report-removal notifications recover their post ID from `action_payload`.
- When the real Gemini moderation workflow is connected, insert a moderation-evidence section between the administrator reason card and inline appeal form. It must show the persisted risk score and `ai_moderation_reason` / flag evidence; no placeholder UI or invented moderation values are rendered before that integration.
- Verified creator award notifications are titled `Verification Application`, use concise brief copy, and show the administrator's creator-request message when available. Rejections show administrator feedback without the previous hard-coded creator-programme paragraph.
- Post-publication success notifications use the same System detail hierarchy: `Your post has completed moderation review.` briefly explains why the notification was received, while the publication result appears alone in the white reason card. New rows persist both fields separately, and the mobile model normalizes legacy greeting-only briefs.
- A dedicated Settings > General > Notification page contains the master in-app control and the existing chat, activity, System, and new-follower switches in grouped cards.

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

### Parent Supervision

Implemented:

- Server-authoritative link requests, acceptance, rejection, cancellation, duplicate prevention, and one-role-at-a-time enforcement for parent and child accounts.
- Followers/Following candidate selection, responsive unlinked/child/parent dashboards, profile navigation, and parent-only linked-child screen-time summaries.
- Persisted foreground CyanZone screen-time sessions, idempotent synchronization, and three-hour plus subsequent hourly threshold events.
- Child-only Safety Check-In with a required message and optional location, plus SOS with a mandatory location attempt and a safe Location unavailable fallback.
- Parent SOS acknowledgement/resolution, merged Check-In/SOS history, typed detail navigation, and a separate latest-ten realtime Supervision Notifications feed.
- Two-party unlink requests: either participant may request; only the other participant may approve or reject; approval revokes the active link.
- Repository/base-schema parity for the current Parent Supervision tables, RPCs, RLS foundations, grants, and Realtime publication entries.

Still required or unverified:

- The user-requested small SOS adjustment.
- Password reauthentication before sending an unlink request if the reviewed SRS requirement remains unchanged.
- The exact former-link history rule: approved unlink stops new sharing, but retained historical-record access for the former linked pair still needs an explicit authorization implementation and acceptance test.
- Applying `supabase/parent_supervision.sql` to the intended live Supabase project and completing multi-account, location-permission, Realtime, and physical-device acceptance.

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
- User search/filter/detail and confirmed assign/remove creator controls. Assigning creator access requires no manual reason and automatically uses the existing creator-award notification trigger; removal requires a 10-500 character reason and sends the removal notification. Administrator profiles are excluded from Users rows and totals by the API repository. Suspend/Reactivate is hidden from the current Users scope, while its API/RPC foundation remains available. Permanent user deletion is intentionally unavailable. Creator identity uses the same CyanZone-cyan rosette with a white tick as the mobile app; **Approved** remains a content-moderation status and is not an identity badge.
- User detail exposes a latest-five horizontal post carousel whose side controls appear only on real overflow. Cards and the filter-free four-column **See All** grid use explicit top-aligned columns and block-level media regions so `object-cover` thumbnails fill edge-to-edge without inline white gaps. The large Post Detail viewer keeps stage-bounded `object-contain` images fully visible, with side Previous/Next controls, bottom dots, title, full content, tags, publication date, moderation status, and approved comments/replies.
- Creator Request Pending/Approved/Rejected queues reuse the exact Users recent-post carousel, placeholder, and Post Detail viewer alongside profile evidence and confirmed approval/rejection. Administrator decision text is carried into the applicant's structured verification notification.
- Grouped Report queues for Pending Review, Resolved, and Dismissed with two-line target previews, visibility evidence, a horizontal report-reason pie chart/legend, post-only **View Post >** access to the shared Post Detail viewer, inline comment evidence, and confirmed Retain/Remove decisions. Retain requires no manual reason and sends no author notification; Remove requires a 10-500 character reason and sends the existing removal notification. The current `REPORT_REVIEW_THRESHOLD=1` is for functional testing; set it to `1000` before deployment.
- Appeal Pending/Approved/Rejected queues support administrator-rejected AI-flagged and report-removed posts, preserve original moderation evidence, allow one owner-only mobile submission, and enforce the administrator outcome as final. Both administrator actions require a 10-500 character reason and send an outcome notification; only the original eligible moderation notification shows appeal status/action.
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
- [ ] Replace the current informational 10,000-follower creator requirement with the approved **2-follower MVP/UAT threshold** and enforce it at the authoritative submission boundary as well as in the mobile copy. Revisit the production threshold after UAT rather than hard-coding 2 as a permanent policy.
- [x] Record creator assignment/removal, creator-request rejection with the administrator's reason, rejected-post, Pending-to-Approved publication, reported-content removal, and both appeal-outcome notifications; Retain intentionally sends none.
- [x] Replace placeholder dashboard links/metrics with functional SRS pages; advanced analytics remain out of scope.
- [x] Add administrator authorization, RLS, API, audit, component, and responsive browser workflow tests.
- [ ] Inspect and verify `supabase/admin_portal.sql` against the live Supabase project before acceptance or deployment. The user reports that the current script was applied, but repository tests do not prove the hosted object state.

### 4. Parent Supervision

- [x] Implement Link Parent Account and Link Child Account selection from the deduplicated Followers/Following union.
- [x] Implement pending link requests, recipient confirmation, accept/reject/cancel, duplicate prevention, and success/error messages.
- [x] Enforce one supervision role per user while pending or active relationships exist.
- [x] Track each user's CyanZone foreground usage and display their own current usage.
- [x] Let linked parents view only their linked children's usage.
- [x] Generate the first screen-time alert after three hours and another after every subsequent completed hour for the user and linked parents.
- [x] Implement child-only Safety Check-In with a required short message and optional location.
- [x] Request operating-system location permission only when needed for Check-In; always attempt it for SOS, allow either flow to continue safely without coordinates, and explain the fallback.
- [x] Restrict SOS to a successfully linked child, record location availability, alert linked parents, and support parent acknowledgement/resolution.
- [x] Build filtered Safety Check-In and SOS history with type, date, time, message, available location, and detail navigation.
- [x] Implement server-authoritative two-party unlink request, approval, and rejection outcomes.
- [ ] Add current-password reauthentication before an unlink request if the reviewed SRS password-verification requirement remains authoritative.
- [ ] Verify that approved unlink stops new supervision sharing and implement the required former-linked-pair access to preserved historical records.
- [ ] Inspect the applied Parent Supervision SQL and run RLS/integration/device acceptance for every role, relationship state, permission outcome, and former-link history rule. The user reports that `parent_supervision.sql` was applied, but live evidence has not been captured.

### 5. Notifications and FCM

- [ ] Add Firebase configuration and `firebase_messaging` for the Android app.
- [ ] Request Android notification permission and preserve in-app notifications when permission is denied.
- [ ] Register, refresh, revoke, and securely store per-device FCM tokens.
- [ ] Implement server-side push dispatch for supported messages, engagement, followers, moderation, appeal, creator, screen-time, check-in, and SOS events.
- [ ] Respect notification preferences and intended-recipient authorization.
- [ ] Handle foreground, background, and terminated app states with safe deep links to the correct conversation or notification detail.
- [ ] Add retry/deduplication/observability and Android device tests.

### 6. Chat conformance

- [x] Hide message requests from active mobile loading, filters, counts, and empty states while preserving dormant request data and backend foundations.
- [x] Route active profile, chat search, and New Followers message actions through the relationship-gated direct-chat RPC.
- [x] Restrict group member choices and repository SQL validation to Followers and Following as required by the SRS.
- [x] Keep existing direct/group member authorization, sender/timestamp display, group-admin removal, member rename, and current-user-only clear-chat behavior covered by regression tests.
- [ ] Rerun the updated complete `supabase/chat.sql`, then verify the relationship gate and group-member rejection with live test accounts. The previously applied script does not contain these latest function definitions.

### 7. Non-functional requirements and release evidence

The user will execute and record the final non-functional acceptance evidence
after the remaining implementation work is complete. Engineering changes needed
to satisfy these checks remain delivery work until that acceptance pass.

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

Latest mobile verification run directly in the user's PowerShell environment
on **September 2, 2026**:

```powershell
cd apps/mobile
flutter test --reporter compact
flutter analyze
```

Observed:

- Focused Parent Supervision verification: **75 tests passed**.
- Complete mobile test suite: **279 tests passed**.
- Flutter analyzer: **no issues found**.
- The verified Parent Supervision change set is committed as `2223b10` (`feat: complete parent supervision unlink and records`).

The most recent Administration Portal and Express API verification remains the
August 2, 2026 run:

```powershell
cd apps/admin
npm test
npm run build

cd ../../services/api
npm test
npm run build
```

- Administration Portal: **51 tests passed** across 14 test files; TypeScript compilation and Vite production build passed. The build reports only the existing large-chunk advisory.
- Express API: **47 tests passed**; TypeScript production build passed.
- Mobile notification regressions cover foreground realtime source ownership, structured System cards/details, current and legacy report-removal appeal eligibility, immediate pending state, and final approved/rejected appeal states.
- Earlier in-app-browser acceptance: approved Creator Requests visual compared side by side at
  **1510 x 1075**; narrow list/detail, Back action, navigation drawer, decision
  validation, and confirmation verified at **390 x 844** with no horizontal
  overflow.
- Current in-app-browser acceptance: verified the Users queue excludes administrators;
  a single-card carousel hides its controls; the card media fills its region and keeps
  eight pixels of hover clearance; and the shared Post Detail viewer contains media
  inside its stage and includes comments. The newer cyan rosette creator badge has
  automated mobile and portal coverage but has not been re-captured in-browser.
  Assign Creator opens confirmation without a reason, while Remove Creator validates a
  10-500 character reason before confirmation. Reports loaded three live Pending Review
  cases with the horizontal reason chart and shared **View Post >** dialog; Retain opens
  confirmation without a reason, while Remove validates its reason first. AI-Flagged
  Content uses count-free tabs and production-facing copy; Approve opens confirmation
  without a reason, while Reject validates its reason first. No browser console errors
  were recorded. The live database had no pending appeal to exercise non-destructively;
  both reason-required Appeal actions are covered by the passing component regression.
- The latest System-notification, Creator Request, card-media, validation-footer,
  and appeal-state changes have automated regression coverage but have not yet
  been re-captured side by side in the user's selected browser/device surface.

Not covered by this verification:

- Live Supabase migration/application state. The user reports that
  `parent_supervision.sql`, the previous `chat.sql`, and `admin_portal.sql` were
  applied, but remote objects were not inspected in this workspace. The newly
  updated `chat.sql` must be rerun. Local SQL contract regressions validate
  repository text and behavior contracts but do not prove that hosted tables,
  functions, triggers, grants, RLS policies, and Realtime publication match it.
- Gemini moderation or FCM, because they are not implemented.
- Android physical-device, location, background/terminated notification, or screen-size acceptance.
- Latest Chrome and Edge acceptance outside the in-app browser.
- Vercel deployment.
- SRS performance, concurrency, usability, reliability, recovery, and security acceptance.

## Next-chat handoff

- Start by reading this file; it is the canonical project and SRS-delivery handover. Use `docs/superpowers/plans/2026-08-02-realtime-system-notifications-and-appeals.md` for the detailed history of the completed notification/admin revisions.
- Parent Supervision is committed through responsive dashboards, family-link management, screen-time tracking, Check-In/SOS, records, realtime supervision notifications, and two-party unlink request/approval/rejection. Commit `2223b10` contains the latest implementation and passed 75 focused tests, all 279 mobile tests, and Flutter analysis on September 2, 2026.
- The latest local notification work is complete through the post-publication brief revision. `Your post has completed moderation review.` is the brief; the publication result is shown alone in the white System detail card. Rejected-post details use `View post` above `Admin:`, and future AI risk-score/evidence UI remains documentation-only.
- The user reports that `supabase/parent_supervision.sql`, the previous `supabase/chat.sql`, and `supabase/admin_portal.sql` were applied. Before live acceptance, inspect those hosted objects and rerun the newly updated complete `supabase/chat.sql`; repository files and local tests alone do not update or verify Supabase.
- Message requests are now hidden/dormant. The Messages screen does not load or show them, and active profile/search/follower actions use `open_direct_conversation`, which requires a follow row in either direction. Existing accepted chat history and realtime behavior are preserved.
- The creator-application UI still says 10,000 followers and does not enforce the threshold. The approved MVP/UAT target is 2 followers; update the mobile copy and authoritative submission enforcement in a later implementation slice, align the source SRS when it is available, then revisit the production threshold after UAT.
- The immediate planned work is a small SOS adjustment, registration consent/OTP, real Gemini moderation, and FCM push delivery. Do not report any of these as complete before implementation and fresh verification.
- The user will perform the final non-functional acceptance evidence after all implementation work is complete.
- Run all terminal commands directly in the user's PowerShell environment outside the Codex sandbox and use `apply_patch` for manual edits.

## Recommended implementation order

Immediate implementation sequence approved on September 2, 2026:

1. Complete the small user-requested SOS adjustment.
2. Complete F002 registration consent, email OTP, and activation conformance.
3. Implement F007 real Gemini moderation, replace the two AI mock files, and connect the real AI-flagged queue to the protected Admin API.
4. Add FCM push delivery, notification preferences, and safe deep links.

Before MVP/UAT completion:

5. Replace the displayed 10,000-follower creator requirement with 2 followers and enforce the same MVP/UAT threshold at the authoritative backend boundary; revisit the production value after UAT.
6. Rerun the updated complete `supabase/chat.sql` and verify that active direct-chat entry and group-member changes require a follow relationship in either direction. Dormant message-request rows and functions remain stored.
7. Apply and verify the repository SQL against the intended Supabase project, then verify the Administration Portal/API deployment and cross-surface flows.
8. Hand the completed build to the user for the final non-functional acceptance evidence pass.

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
