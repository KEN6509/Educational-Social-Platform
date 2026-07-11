# CyanZone Current Worktree Handover

Last reviewed against the workspace: **July 11, 2026**

This is the canonical starting point for a new developer or AI session. The worktree contains substantial uncommitted and untracked implementation. Preserve it. When this document differs from source code, tests, or SQL, treat those files as authoritative.

## Product and architecture

CyanZone is a mobile-first, parent-supervised educational social platform for teenagers.

- Mobile: Flutter/Dart, Supabase Flutter, SharedPreferences, `photo_manager`, `image_picker`.
- Admin: React, TypeScript, Vite, Tailwind, Supabase JS.
- API: Node.js, Express, TypeScript, Zod, Supabase service role.
- Platform: Supabase Auth, PostgreSQL, RLS, Storage, Realtime.
- Planned AI moderation: Gemini for text and images, server-side only.

Perspective API is not used. Gemini moderation is not implemented yet and chat is intentionally excluded from AI moderation. External device push notifications are also not implemented yet; current notifications are Supabase-backed in-app data and badges.

## Stable product rules

- Registration creates a normal user and never asks for a role.
- Parent/child status comes from `parent_child_links`.
- Creator badges require an approved creator request.
- Admin accounts are separate web-dashboard operators.
- Supabase anon keys are client-safe; service-role and future Gemini keys are backend-only.
- Posts/comments currently use prototype moderation defaults until Gemini and the admin review queue are ready together.

## Repository map

```text
apps/mobile/                    Flutter application
apps/admin/                     React admin dashboard
services/api/                   Express privileged API
supabase/                       Base schema and incremental SQL
docs/setup.md                   Local and database setup
docs/superpowers/specs/         Approved/historical designs
docs/superpowers/plans/         Historical implementation plans
```

## Branch and milestone naming

Use app-surface prefixes for future milestone branches/worktrees:

- `mobile-v0.1.0-auth-and-feed`
- `mobile-v0.2.0-chat`
- `mobile-v0.3.0-parent-supervision`
- `mobile-v0.4.0-ai-moderation`
- `admin-v0.1.0-moderation-dashboard`

Keep Git names lowercase and hyphenated. Treat mobile and admin dashboard versions as separate release lines once the admin surface becomes active, because they ship different user experiences even when they share Supabase/API work.

Important mobile entry points:

```text
apps/mobile/lib/main.dart
apps/mobile/lib/src/features/shell/presentation/main_shell.dart
apps/mobile/lib/src/features/chat/
apps/mobile/lib/src/features/posts/
apps/mobile/lib/src/features/profile/
apps/mobile/lib/src/features/parent_child/
```

## Current mobile implementation

### Foundation, auth, shell, profile, feed, and search

Implemented:

- Supabase session/auth gate, registration/login validation, password update, logout.
- Five-tab shell: Home, Parent-Child, Create, Chats, Profile.
- Waterfall feed with Feeds/Following/Saves, filtering, refresh, image and text posts.
- Search across posts and profiles with local/server history.
- Own/other profiles, follow graph, avatar editing/caching, post grids, settings.
- Post creation/editing with up to nine images, custom picker/camera, tags, storage cleanup.
- Post details, likes/dislikes/saves/shares, comments/replies/mentions, comment likes, pinning, reporting, editing, and soft removal.
- Cached media/aspect ratios and weak-network presentation paths.

### Chat module

The Chats tab is fully implemented, not a placeholder.

Implemented chat home:

- Activity, System, and New Followers shortcuts with unread counts.
- Search by user/group/chat name, including cached offline chat-history search.
- All, Unread, Groups, and Requests filters.
- Messenger/WhatsApp-style conversation rows, last-message preview, timestamps, and unread badges.
- Message requests are separated from accepted/recent chats and expire from display after 30 days.
- Bottom navigation badge combines unread chat rows with notification-section sources.

Implemented conversations:

- Direct and group chat creation.
- Stranger direct-message cap of three messages.
- Realtime refresh and local cache of recent conversation/message history.
- Text and multi-image messages.
- Multiple-image WhatsApp-style grids and full-screen preview/download.
- Shared posts rendered as compact post cards that navigate to post details.
- Message selection, multi-select, copy text, delete-for-me with Undo, and unsend within ten minutes.
- Message ordering, unread divider, latest/unread entry positioning, keyboard-safe scrolling, and jump-to-bottom control.
- Current-user-only clear chat.
- Group rename, add/remove members, member search, admin display, exit group, and cleanup when the final member exits.
- Group-chat member mentions with `@` autocomplete, repeated tappable dark-green mention spans, stable profile targets, and admin-only `@all`.
- Chat rows show an `@` indicator for unvisited mentions; room entry and the floating `@` button traverse mentioned messages oldest first.
- Storage cleanup for unsent/deleted chat images and deleted empty groups.

Chat design decisions:

- Cloud-centric Supabase chat; no end-to-end encryption in this prototype.
- No AI moderation or admin report-review flow for private chat.
- No calls, video calls, audio, stickers, or reactions.
- External FCM/APNs delivery is deferred.

### Activity and New Followers

Implemented:

- Activity types for likes, favorites/saves, comments, replies, comment likes, and mentions.
- Distinct activity icons/colors and category filtering.
- Activity target preview using post image or author avatar for text-only posts.
- Navigation to approved posts/comments and a missing/unavailable snackbar otherwise.
- New Followers limited to the latest 30 days and deduplicated to the latest relevant follow event.
- Profile navigation and Follow Back/Message actions.
- Per-row unread dots, section read-on-exit behavior, automatic refresh on entry/resume, and `99+` badge capping.
- Correct unread chat counts and bottom-bar badge refresh after reading.

System Notifications currently has the shared page/read/badge foundation, but its moderation failure/edit/delete/appeal product content is intentionally deferred.

### Sharing and post image preview

Implemented:

- Existing post-detail share sheet uses recent chat contacts and sends shared-post messages.
- Share-sheet height adapts to recent-contact rows and supports drag expansion below the status bar.
- Post-detail title/content use native text selection.
- Post image preview is black full-screen with transparent header, image counter, download action, paging, and zoom.
- Tap and two-finger gesture on a post image both open the same standard preview.
- Preview return synchronizes the post carousel image and dot to the final viewed index.
- At 1x the preview image remains centered and cannot be dragged; above 1x it can be panned.
- Pinching below 1x closes preview; zoom may elastically reach 4.8x and settles to 4x while preserving the viewed point.
- Offline post detail shows only the cached first image and blocks preview/switching.

### Parent-Child

Partially implemented:

- Family link retrieval and role/status display.
- SOS creation and basic safety-center presentation.
- Repository support for links and screen-time data.

Still incomplete and intended for the next module pass:

- Invite/link creation and acceptance/rejection UX.
- Complete Add Family Member flow.
- Screen-time UI integration.
- Check-ins.
- Parent SOS acknowledgement/resolution.

## Backend and database

### Express API

Implemented routes:

```text
GET  /health
POST /admin/bootstrap
```

`GEMINI_API_KEY` is optional. Existing API routes run without it. Gemini moderation routes, structured results, retries, and admin review UI remain future work.

### Supabase

The base schema plus incremental scripts cover auth/profile data, posts/interactions, follows, tags/search, parent-child data, chat, notifications, and storage.

Important scripts include:

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
```

The storage bucket is named `images`; it stores post and chat images. Deleted posts, unsent image messages, and deleted final-member groups should remove their related storage objects.

Apply `follow.sql`, `comment_mentions.sql`, and the latest `chat.sql` to the live project. The July 12 `chat.sql` update is required for group mentions. Notification trigger changes do not backfill historical events automatically.

## Verification state

Most recent verification for the final post-preview/chat-widget pass on July 11, 2026:

```powershell
cd apps/mobile
flutter test test/chat_widgets_test.dart
flutter analyze
```

Observed result:

- `chat_widgets_test.dart`: 49 tests passed.
- `flutter analyze`: no issues.

Run broader tests again in a new implementation session before claiming the entire worktree is green.

## Next planned work

The next chat/session should focus on two modules:

1. **App notifications**
   - Define notification categories and user permission/settings behavior.
   - Decide local/in-app versus external device-push boundaries.
   - If external push is included, design FCM/APNs integration without replacing Supabase as the data source.
   - Keep System Notifications content and moderation/appeal workflows coordinated with the future admin/moderation design.
2. **Parent-Child module**
   - Complete linking/invite/acceptance flows.
   - Connect screen time, check-ins, SOS handling, and parent supervision UI.

Do not restart chat, post details, sharing, feed, profile, search, or media picking from scratch. Extend the current implementation.

## Risks and conventions

- The worktree is dirty; preserve unrelated edits and untracked files.
- `post_detail_page.dart`, chat presentation files, and `main_shell.dart` are large and tightly coupled. Prefer focused changes and regression tests.
- Remote Supabase schema/policies may differ from repository SQL; inspect before rerunning scripts.
- Keep service-role and Gemini secrets out of Flutter, React, docs, screenshots, and commits.
- Use Supabase directly for normal authenticated operations; use Express for secrets and privileged workflows.
- Run terminal commands directly in the user's PowerShell environment, as requested.
- Use `apply_patch` for manual file edits.

## Environment variables

Mobile:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Admin:

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
GEMINI_API_KEY # optional until Gemini moderation is implemented
```
