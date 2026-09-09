# CyanZone Project Overview and SRS Delivery Handover

Last reviewed against the workspace: **September 7, 2026**. The SRS traceability
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

- Mobile: Flutter/Dart for Android, Supabase Flutter, SharedPreferences, `photo_manager`, `image_picker`, and `flutter_map`/OpenStreetMap for location display.
- Administration Portal: React, TypeScript, Vite, Tailwind, and Supabase JS.
- Privileged API: Node.js, Express, TypeScript, Zod, and the Supabase service role.
- Platform: Supabase Auth, PostgreSQL, Row Level Security (RLS), Storage, and Realtime.
- Required AI moderation: Google Gemini API for public text and image posts and public comments, server-side only.
- Required push delivery: Firebase Cloud Messaging (FCM) for supported Android notifications.
- Required deployment target: Vercel for the Administration Portal and Express API/Vercel Functions.
- Version control: Git with the GitHub `origin` repository.

The Gemini moderation workflow and authenticated Admin moderation queue are implemented in code. FCM push delivery and live Vercel/Supabase acceptance evidence remain pending. Private direct and group chat messages are intentionally excluded from AI moderation.

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
- The required software baseline is represented by the stack above: Flutter/Dart, React/Vite/TypeScript/Tailwind, Node/Express/TypeScript, Supabase/PostgreSQL/Auth/RLS/Storage/Realtime, FCM, Gemini, Git/GitHub, and Vercel. FCM and live deployment/acceptance evidence remain pending; Gemini is connected through the privileged API.

## SRS functional traceability

Status meanings:

- **Implemented**: the current repository contains the required end-to-end behavior and supporting controls.
- **Partial**: a meaningful part exists, but one or more SRS flows, rules, or integrations are missing.
- **Not implemented**: only planning, schema fields, placeholders, or no implementation exists.

| ID | SRS level | Feature | Status | Current evidence and remaining boundary |
| --- | --- | --- | --- | --- |
| F001 / REQ_F001 | Basic | User Authentication | **Implemented** | Mobile and administrator login, authenticated sessions, confirmation-based mobile and Administration Portal logout, and mobile password change with current-password reauthentication are implemented. New mobile registration passwords, changed passwords, and administrator bootstrap passwords require at least 12 characters with uppercase, lowercase, number, and non-whitespace symbol; `.` and `_` are accepted symbols. Existing passwords remain valid for login until changed. |
| F002 / REQ_F002 | Basic | User Registration | **Partial** | The repository now contains required Terms and Privacy consent, version/timestamp metadata, one combined in-app legal page, centered six-cell email OTP verification/resend, an inline borderless Back action for wrong-email correction, pending-email recovery, confirmed-session activation gating, deferred public-profile creation, and confirmation-time rejection of missing current consent metadata. The user has confirmed real six-digit email delivery and verification through hosted Supabase/Brevo; the new migration and hosted activation state still require independent live verification. |
| F003 / REQ_F003 | Basic | User Profile Management | **Implemented** | Own/other public profiles, own-profile editing, follow/unfollow, follower/following lists, public creator badge display, and database protection against self-following are present. Administrator assignment/removal of creator status remains under F011. |
| F004 / REQ_F004 | Intermediate | Social Feed | **Partial** | Feed browsing, search, create/edit/soft-delete, selection of one to five predefined tags, `Others` fallback, image and text posts, profiles, saves/following views, media flows, and server-side Gemini moderation for new/edited posts are implemented. The API is deployed and the first live migration was applied; the current enum-cast correction must be reapplied before final 20-second device acceptance. UC004 must state one to five predefined tags, not exactly one tag. |
| F005 / REQ_F005 | Intermediate | Post Engagement | **Partial** | Comments/replies, likes, saves, chat sharing, private 14-day dislike hiding, and server-side Gemini moderation for public comments are implemented. The deployed moderation stack needs the current SQL/API correction and final device acceptance evidence. |
| F006 / REQ_F006 | Intermediate | Content Reporting | **Implemented** | Users submit reason-only reports for public posts and comments. The repository report lifecycle is `pending_review` to `resolved` (Remove) or `dismissed` (Retain), with no separate Open/Reviewing state or reporter description. The Administration Portal groups cases by target, shows total/unique counts in a reason pie chart and legend, keeps two-line queue previews, and opens complete post evidence through the shared Post Detail viewer. `REPORT_REVIEW_THRESHOLD=1` is a testing convenience only and must be changed to `1000` before deployment. The destructive `report_flow_simplification.sql` migration is committed but has not been applied to the live Supabase project. |
| F007 / REQ_F007 | Advanced | AI-Assisted Content Moderation | **Partial** | The privileged API performs structured Gemini text/image moderation for posts, edits, and public comments; persists revisioned results, exact submitted-content snapshots, risk scores, evidence, model/version, timestamps, and decision source; switches once to the fallback model for explicit 429/503 responses; keeps content unpublished on failure; and routes 40%-60% cases to the authenticated Admin review queue. Mobile retryable failures are retained across restarts against the same record ID. The API and Admin clients are deployed and the Gemini key/models are live. The current enum-cast SQL correction, 15-second provider timeout deployment value, redeployment, and final 20-second/device acceptance evidence remain required. |
| F008 / REQ_F008 | Advanced | Parent Supervision | **Partial** | Server-authoritative parent/child linking, role enforcement, role dashboards, foreground CyanZone screen-time tracking and threshold events, location-aware Check-In, foreground-only 10-second live SOS location, OpenStreetMap detail maps, multi-parent acknowledgement/timeline/resolution, safety records, dedicated realtime supervision notifications, and two-party unlink request/accept/reject flows are implemented in the repository. The updated `parent_supervision.sql` must be rerun on Supabase. Password reauthentication for unlink, former-link historical-record authorization, remote inspection, and multi-account/physical-device acceptance remain incomplete or unverified. |
| F009 / REQ_F009 | Intermediate | Real-Time Communication | **Partial** | Direct/group realtime chat, group administration, text/image/shared-post messages, read state, clear chat, and member-only access are implemented. Message requests are intentionally hidden from active mobile loading and UI while their existing data and backend foundation remain dormant. Active direct-chat entry and every new direct-message send require a current follow relationship in either direction, and group-member candidates/validation are limited to Followers and Following. Existing accepted conversations and history remain readable after both users unfollow, but their composer is blocked. The user applied the previous `chat.sql`; the updated follow-only functions still require live reapplication and verification. |
| F010 / REQ_F010 | Intermediate | Notifications | **Partial** | Activity, New Followers, and System notification rows/counts refresh through foreground Supabase Realtime even before their section is opened. Per-section/conversation unread counts, the total Messaging-tab badge, notification preferences, compact structured System details, notification-side one-final-appeal handling, and Gemini moderation outcome foundations are implemented. FCM background/closed-app delivery and final live moderation acceptance remain missing. Retaining reported content intentionally sends no author notification. |
| F011 / REQ_F011 | Advanced | Administration Portal | **Partial** | The deployed functional portal includes Overview, Users, Creator Requests, grouped Reports, Appeals, and an authenticated API-backed AI-Flagged Content queue/detail/decision workflow. Assign Creator, Retain Content, and AI Approve do not require manual reasons; Creator Request rejection, Remove Creator, Remove Content, AI Reject, and both Appeal actions require 10-500 characters. Reason-free persisted actions receive stable internal audit text. Users excludes administrator profiles at the API query boundary. Final browser/device acceptance evidence remains pending. |

## Current mobile implementation

### Foundation, profile, feed, search, and engagement

Implemented:

- Supabase auth/session gate, login and registration validation, confirmation-based logout, and password update with current-password reauthentication.
- New registration consent and activation flow: one aligned checkbox/agreement row, one combined inline legal link and page for the concise Terms and Privacy content, required combined consent, stored policy versions/timestamp, a centered six-cell email OTP input with an inline borderless Back action, 60-second resend recovery, wrong-email correction, restart recovery, an unverified-login OTP path, visible registration failures, and database rejection when a normal confirmation lacks current consent metadata.
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

- New and edited public posts and public comments now go through the server-side Gemini workflow before publication. Private chat is excluded.
- Live Supabase migration/application, API deployment, and final acceptance evidence are still separate release steps.
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
- Existing accepted direct conversations remain available from Messages after both users unfollow, preserving established history. Their empty preview and room show `Follow this user to continue chatting.`, and text/image sending remains blocked until a follow relationship exists again.
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
- Real Gemini evidence is persisted against the exact target revision and is shown in the authenticated Admin moderation case. Mobile System details continue to show only real persisted decision/reason data; they never invent placeholder risk values.
- Verified creator award notifications are titled `Verification Application`, use concise brief copy, and show the administrator's creator-request message when available. Rejections show administrator feedback without the previous hard-coded creator-programme paragraph.
- Post-publication success notifications use the same System detail hierarchy: `Your post has completed moderation review.` briefly explains why the notification was received, while the publication result appears alone in the white reason card. New rows persist both fields separately, and the mobile model normalizes legacy greeting-only briefs.
- A dedicated Settings > General > Notification page contains the master in-app control and the existing chat, activity, System, and new-follower switches in grouped cards.

Still required:

- Live verification of Pending Administrator Review feedback and automatic
  moderation notifications against the deployed Gemini/Supabase workflow.
  Creator status, rejected posts, Pending-to-Approved publication,
  reported-content removal, and both appeal outcomes have in-app notification
  foundations; retaining reported content intentionally sends none.
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
- Child-only Safety Check-In with a required message and optional location; available Check-In coordinates retain their detail row and add a fixed OpenStreetMap pin below it.
- SOS performs a mandatory initial location attempt, safely sends when location is unavailable, and then updates one server-authoritative latest-location row approximately every 10 seconds while CyanZone remains visible. Tracking pauses when the app is minimized, locked, or terminated, resumes the newest unresolved alert on foreground/relaunch, and stops after resolution.
- SOS detail keeps coordinates visible, adds a moving OpenStreetMap pin, reports live/stale freshness, and refreshes the status, location, and chronological triggered/acknowledged/resolved timeline through focused Supabase Realtime subscriptions.
- Multiple linked parents may each acknowledge once. A parent sees one bottom action: Acknowledge first, then Resolve only after their own acknowledgement. Resolve requires confirmation, is server-enforced/idempotent, and applies to all linked parents; the child cannot resolve.
- Merged Check-In/SOS history, typed detail navigation, and a separate latest-ten realtime Supervision Notifications feed.
- Two-party unlink requests: either participant may request; only the other participant may approve or reject; approval revokes the active link.
- Repository/base-schema parity for the current Parent Supervision tables, RPCs, RLS foundations, grants, and Realtime publication entries. The SOS implementation applies GoF Facade (`SosTrackingCoordinator`), Observer (app lifecycle, coordinator listeners, and Supabase Realtime), State (SOS lifecycle/action rules), and Adapter (GPS/live-location conversion to the shared app location model) patterns without Riverpod.

Still required or unverified:

- Password reauthentication before sending an unlink request if the reviewed SRS requirement remains unchanged.
- The exact former-link history rule: approved unlink stops new sharing, but retained historical-record access for the former linked pair still needs an explicit authorization implementation and acceptance test.
- Rerunning the complete updated `supabase/parent_supervision.sql` on the intended live Supabase project and completing multi-account, 10-second movement, foreground/background/resume, location-permission, Realtime, map-tile failure, concurrent acknowledgement, resolution, and physical-device acceptance.

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
GET  /admin/moderation-cases
GET  /admin/moderation-cases/:caseId
POST /admin/moderation-cases/:caseId/decision
POST /moderation/posts/:postId
POST /moderation/comments/:commentId
```

All `/admin/*` casework routes require a valid bearer session belonging to an
active administrator. Administrator decisions require a 10-500 character
reason. Administrator bootstrap rejects passwords that do not meet the same
12-character uppercase/lowercase/number/symbol policy used by the mobile app.

`GEMINI_API_KEY` is read only by the privileged Express API. `GEMINI_MODEL`,
`GEMINI_FALLBACK_MODEL`, and `GEMINI_TIMEOUT_MS` control the moderation model
chain and bounded request timeout. The default chain uses
`gemini-3.5-flash-lite` first, then one `gemini-3.8-flash` fallback for HTTP
429/503. Other retryable transport failures return to the caller without a
duplicate provider call; safety and permanent failures stop immediately. Each
provider call has a 15-second timeout, while mobile allows 30 seconds for the
complete API request.
The API validates structured Gemini output, sends trusted post images as
multimodal inputs, retries transient provider failures once, and records the
revisioned moderation result before publication. The key must never be placed
in Flutter, React, Supabase client configuration, or the repository.

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
- AI-Flagged Content uses the authenticated API-backed queue/detail/status/score/decision workflow, count-free queue tabs, and confirmation dialogs. Approve requires no manual reason; Reject requires a 10-500 character reason. Decisions are persisted through the service-role API and feed the existing moderation notification foundations.

Reason-free persisted Assign Creator and Retain Content requests are converted by
the API service to stable internal audit reasons before the existing non-null SQL
audit boundary. The real moderation foundation also creates a publication-success
System notification only when a post changes specifically from `pending` to
`approved`, avoiding duplicate generic messages for approved appeals.

The temporary AI preview files were removed. The remaining reusable UI/types are
connected to the authenticated Admin API and real moderation records.

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
supabase/ai_moderation.sql
```

The `images` bucket stores post and chat images. Writes and deletes are scoped
to each authenticated user's post folder or `chat/<user-id>/...` folder, and
shared objects are immutable. Deleted posts, unsent image messages, and
final-member group deletion should clean up related objects.

Before relying on a live Supabase project, apply and verify the current SQL in the documented order. Repository SQL does not prove the remote database is current, and notification triggers do not backfill historical events.

For an existing project, run `supabase/ai_moderation.sql` after
`admin_portal.sql`. Fresh projects receive the matching base objects from
`schema.sql`; still run the incremental script so RPCs, RLS, and indexes are
present. The API cannot moderate successfully until this migration and the
server-only Gemini environment variables are configured.
Each new moderation case stores the submitted title, content, tags, and image
metadata in `target_snapshot`; the Admin queue prefers that snapshot so a later
edit cannot be displayed beside an earlier Gemini decision.

## Required implementation to-do list

Complete these items against the exact SRS flows and rules. Check an item only after implementation, automated tests, and relevant integration/device acceptance evidence exist.

### 1. Authentication and registration

- [x] Add mobile and Administration Portal logout confirmation dialogs with Cancel and Log out outcomes.
- [x] Require current-password verification before accepting a new mobile password.
- [x] Enforce the 12-character uppercase/lowercase/number/symbol policy on mobile registration, mobile password change, and administrator bootstrap without invalidating existing login passwords.
- [x] Display Terms and Conditions and Privacy Policy during registration and require explicit consent before submission.
- [x] Implement the email OTP entry, validation, resend/error states, and account-activation gate in the repository; live Supabase configuration remains pending.
- [ ] Verify inactive/unverified normal users cannot enter protected mobile functions.
- [ ] Add widget/integration tests for all F001/F002 main and alternate flows.

### 2. AI moderation and public-content publication

- [x] Allow one to five predefined tags on post creation/editing and use `Others` when no listed topic fits; predefined tag administration remains out of scope.
- [x] Define the versioned moderation request/response schema for text, images, combined posts, and comments.
- [x] Implement server-side Gemini calls; never expose the Gemini key to Flutter or React.
- [x] Enforce SRS thresholds: below 40% approve, 40%-60% inclusive queue for administrator review, and above 60% reject.
- [x] Keep new posts, edited posts, and public comments unpublished until moderation finishes.
- [x] Complete the initial assessment within a bounded timeout; on timeout/failure keep content unpublished and show retry/error feedback.
- [x] Add bounded retry handling and idempotency so repeated submissions do not duplicate content or decisions.
- [x] Persist risk score, evidence/reason, status, timestamps, model/version, and decision source for audit.
- [x] Connect the implemented Approved/Rejected notification foundations and Pending Administrator Review feedback through the real Gemini workflow.
- [x] Add text, image, combined-content, comment, timeout, quota, malformed-response, and retry tests.
- [x] Apply the initial live Supabase migration and deploy the API/Admin clients.
- [ ] Reapply the current enum-cast migration correction, deploy the timeout correction, and capture final 20-second/device acceptance evidence.

### 3. Reporting, appeals, and Administration Portal

- [x] Prevent the same user from creating multiple unresolved reports for the same post/comment in repository SQL.
- [x] Group the queue by post/comment target without automatic removal; use `REPORT_REVIEW_THRESHOLD=1` only for functional testing and change it to `1000` before deployment.
- [x] Simplify report storage to reason-only `pending_review`, `resolved`, and `dismissed` records; commit the manual migration without applying it remotely.
- [x] Replace the temporary AI-Flagged Content mock adapter/data with Gemini-backed moderation records and authenticated API reads/decisions.
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
- [x] Track an unresolved child SOS approximately every 10 seconds while CyanZone remains in the foreground, persist only its latest point, pause outside the foreground, resume after return/relaunch, and stop after parent resolution.
- [x] Add reusable OpenStreetMap detail maps: a moving SOS pin and a fixed Check-In pin below the retained latitude/longitude row.
- [x] Add the live SOS event timeline and per-parent Acknowledge-to-Resolve action replacement with resolve confirmation and server-side enforcement.
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
- [x] Recheck the current follow relationship for every direct-message send, and block the Messages preview and room composer when neither user follows the other while preserving history.
- [x] Restrict group member choices and repository SQL validation to Followers and Following as required by the SRS.
- [x] Keep existing direct/group member authorization, sender/timestamp display, group-admin removal, member rename, and current-user-only clear-chat behavior covered by regression tests.
- [ ] Rerun the updated complete `supabase/chat.sql`, then verify direct-chat entry, direct-send revocation after the final unfollow, and group-member rejection with live test accounts. The previously applied script does not contain `can_send_chat_message` or these latest function definitions.

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

Focused direct-chat relationship regression run directly in the user's
PowerShell environment on **September 3, 2026**:

```powershell
cd apps/mobile
flutter test test/chat_sql_migration_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_models_test.dart
flutter analyze lib/src/features/chat test/chat_sql_migration_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart test/chat_models_test.dart
```

Observed:

- Focused chat SQL/repository/widget/model verification: **141 tests passed**.
- Focused Flutter analyzer: **no issues found**.
- The complete mobile suite was not rerun for this focused bug fix at the user's request; the latest complete-suite evidence remains the September 2 run below.
- Direct-send enforcement is implemented through `515d5c6` (`fix: persist direct chat send permission`).

Latest focused Parent Supervision verification run directly in the user's
PowerShell environment on **September 3, 2026**:

```powershell
cd apps/mobile
flutter test test/app_location_map_test.dart test/location_service_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart test/parent_child_repository_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
flutter analyze lib/src/core/widgets/app_location_map.dart lib/src/features/parent_child test/app_location_map_test.dart test/location_service_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart test/parent_child_repository_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
```

Observed:

- Focused Parent Supervision, SOS, location, map, repository, lifecycle, UI, and SQL verification: **80 tests passed**.
- Focused Flutter analyzer: **no issues found**.
- The complete mobile suite was not rerun for this feature at the user's request; the latest complete-suite evidence remains the September 2 run below.

Latest focused registration consent and email OTP verification run directly in
the user's PowerShell environment on **September 6, 2026**:

```powershell
cd apps/mobile
flutter test test/features/auth test/widget_test.dart test/registration_consent_sql_test.dart
flutter analyze lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/features/auth test/registration_consent_sql_test.dart test/support/fake_auth_gateway.dart test/support/fake_pending_registration_store.dart test/widget_test.dart
```

Observed:

- Focused authentication, consent, OTP, persistence, and app-composition tests:
  **45 tests passed**, including the centered six-cell OTP component, numeric
  filtering and length enforcement, complete-only submission, focused-cell
  styling, the inline Back/heading arrangement, registration-error display,
  confirmation-time consent enforcement, consent-row alignment, and combined
  legal-page navigation regressions.
- Focused Flutter analyzer: **no issues found**.
- The updated debug build installed successfully on the connected Android 16
  device. The user has confirmed real six-digit email delivery and verification
  through the configured Supabase/Brevo flow. Independent hosted migration and
  activation-state verification remain pending. Physical OTP pixel comparison
  remains pending because the device was locked during the automated capture.

Latest mobile verification run directly in the user's PowerShell environment
on **September 2, 2026**:

```powershell
cd apps/mobile
flutter test
flutter analyze
```

Observed:

- Focused Parent Supervision verification: **75 tests passed**.
- Focused chat/profile/SQL verification: **134 tests passed**.
- Complete mobile test suite: **286 tests passed**.
- Flutter analyzer: **no issues found**.
- The verified Parent Supervision change set is committed as `2223b10` (`feat: complete parent supervision unlink and records`).
- The hidden-request and relationship-conformance implementation is committed through `8396096` (`docs: record active chat relationship rules`).

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

Latest Gemini moderation verification was run directly in the user's
PowerShell environment on **September 7, 2026**:

```powershell
cd services/api
npm test
npm run typecheck
npm run build
npm audit --omit=dev

cd ../../apps/admin
npm test
npm run typecheck
npm run build
npm audit --omit=dev

cd ../mobile
flutter test --reporter compact
flutter analyze
```

Observed:

- Express API tests pass (107), with typecheck/build and a zero-vulnerability
  production dependency audit.
- Admin Portal tests pass (51), with a zero-vulnerability production dependency
  audit, clean typecheck, and successful production build. Vite reports only
  the existing large-chunk advisory.
- The complete Flutter suite passes (372), including the behavior-level report
  payload and moderation retry regressions, and the full analyzer reports no
  issues.

Not covered by this verification:

- Live Supabase migration/application state. The user reports that the previous
  `parent_supervision.sql`, `chat.sql`, and `admin_portal.sql` were applied, but
  remote objects were not inspected in this workspace. The newly updated
  `parent_supervision.sql` and `chat.sql` must be rerun. Local SQL contract regressions validate
  repository text and behavior contracts but do not prove that hosted tables,
  functions, triggers, grants, RLS policies, and Realtime publication match it.
- Live Gemini/Supabase configuration, Vercel deployment, FCM, or final device
  acceptance. The API code and client integrations are implemented, but hosted
  configuration and acceptance evidence are still required.
- Android physical-device location, background/terminated notification, or full screen-size acceptance. The latest OTP build was installed on the Android 16 device, but its pixel comparison remains pending because the device was locked during capture.
- Latest Chrome and Edge acceptance outside the in-app browser.
- Vercel deployment.
- SRS performance, concurrency, usability, reliability, recovery, and security acceptance.

## Next-chat handoff

- Start by reading this file; it is the canonical project and SRS-delivery handover. Use `docs/superpowers/plans/2026-08-02-realtime-system-notifications-and-appeals.md` for the detailed history of the completed notification/admin revisions.
- Parent Supervision now includes foreground-only 10-second live SOS tracking, latest-point storage, multi-parent acknowledgement events, the live SOS timeline, per-parent Acknowledge-to-Resolve actions, resolve confirmation, and reusable OpenStreetMap views for SOS and Check-In details. The repository implementation is on `feature/AI-Moderation`; rerun the complete updated `supabase/parent_supervision.sql` before live testing.
- The Gemini moderation implementation has been hardened: database inserts cannot self-approve, shared image writes are owner-scoped, provider safety blocks are separated from ordinary errors, CORS/Vercel entry configuration is explicit, mobile retains same-record retries across restarts, and Admin cases show immutable submitted snapshots. The API uses `gemini-3.5-flash-lite` as primary with one bounded `gemini-3.8-flash` fallback for HTTP 429/503. Request-level SDK retries are disabled, other network timeouts are not duplicated, each provider call allows 15 seconds, and mobile allows 30 seconds for the complete request. The API and Admin portal are deployed on Vercel, and a live primary-model smoke test passed on September 8, 2026. The updated `ai_moderation.sql` enum-cast fix and API timeout configuration still require redeployment and live verification.
- The user reports that the previous `supabase/parent_supervision.sql`, `supabase/chat.sql`, and `supabase/admin_portal.sql` were applied. Before live acceptance, rerun the newly updated complete `supabase/parent_supervision.sql` and `supabase/chat.sql`; repository files and local tests alone do not update or verify Supabase.
- Message requests are now hidden/dormant. The Messages screen does not load or show them, and active profile/search/follower actions use `open_direct_conversation`, which requires a follow row in either direction. Existing accepted chat history remains readable after both users unfollow, while the Messages preview and chat-room composer become follow-required and `send_chat_message` rejects new direct messages.
- The creator-application UI still says 10,000 followers and does not enforce the threshold. The approved MVP/UAT target is 2 followers; update the mobile copy and authoritative submission enforcement in a later implementation slice, align the source SRS when it is available, then revisit the production threshold after UAT.
- Registration consent/OTP is implemented in the repository, including the combined legal page, centered six-cell OTP input, inline borderless Back action, and the existing resend/recovery behavior. The user has confirmed real six-digit Supabase/Brevo email delivery and verification. The remaining F002 boundary is running/verifying `supabase/registration_consent_otp.sql`, independently checking hosted activation state, and completing the OTP screen pixel comparison after the device is unlocked. The approved 2-follower MVP/UAT creator gate and live Gemini/Vercel acceptance remain pending. Do not report any unverified boundary as complete.
- The user will perform the final non-functional acceptance evidence after all implementation work is complete.
- Run all terminal commands directly in the user's PowerShell environment outside the Codex sandbox and use `apply_patch` for manual edits.

## Recommended implementation order

Immediate implementation sequence updated on September 7, 2026:

1. Create the Gemini API key, apply the revised `ai_moderation.sql`, and deploy/configure the API and Admin Portal on Vercel.
2. Verify the implemented F007 Gemini workflow with real-provider post, image, comment, admin-review, rejection, and same-record retry paths.
3. Add FCM push delivery, notification preferences, and safe deep links.

Before MVP/UAT completion:

4. Replace the displayed 10,000-follower creator requirement with 2 followers and enforce the same MVP/UAT threshold at the authoritative backend boundary; revisit the production value after UAT.
5. Rerun the updated complete `supabase/parent_supervision.sql` and `supabase/chat.sql`, then verify the SOS lifecycle/location rules, direct-chat entry/send revocation, and group-member relationship checks with live accounts. Dormant message-request rows and functions remain stored.
6. Verify the remaining repository SQL against the intended Supabase project, then verify the Administration Portal/API deployment and cross-surface flows.
7. Hand the completed build to the user for the final non-functional acceptance evidence pass.

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
API_BASE_URL
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
GEMINI_MODEL
GEMINI_FALLBACK_MODEL
GEMINI_TIMEOUT_MS
CORS_ALLOWED_ORIGINS
```

Set `REPORT_REVIEW_THRESHOLD=1` only while performing functional tests with the current small user population. Set it to `1000` before any deployment.

FCM server credentials and any Vercel-specific environment values must be added through secure deployment configuration when those features are implemented; never commit them.
