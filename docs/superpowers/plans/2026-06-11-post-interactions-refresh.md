# Post Interactions Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dislike/report/comment reply flows production-like while keeping post detail actions synced with Supabase.

**Architecture:** Keep Supabase as the source of truth. Use `likes.reaction_type = 'dislike'` plus a 14-day `hidden_until` column for feed/search hiding, add a dedicated mobile report page, and use `comments.parent_comment_id` for one-level replies.

**Tech Stack:** Flutter, Dart, Supabase JS/PostgREST via `supabase_flutter`, PostgreSQL SQL migration.

---

### Task 1: Data Contracts And SQL

**Files:**
- Create: `supabase/post_interactions_phase4.sql`
- Modify: `apps/mobile/lib/src/features/posts/data/feed_post.dart`
- Modify: `apps/mobile/lib/src/features/posts/data/post_comment.dart`
- Test: `apps/mobile/test/feed_post_test.dart`
- Test: `apps/mobile/test/post_comment_test.dart`

- [x] Add tests for active dislike hiding and reply parsing.
- [x] Add SQL for `likes.hidden_until`, active dislike indexes, report reason constraint compatibility, and comment reply index.
- [x] Parse active dislike timestamps in `FeedPost`.
- [x] Keep `PostComment.parentCommentId` as the reply relationship.

### Task 2: Repository Persistence

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/data/posts_repository.dart`
- Test: `apps/mobile/test/posts_repository_test.dart`

- [x] Add tests for select columns and discovery filtering helpers.
- [x] Add `fetchPostById`, `createReport`, and `createComment(..., parentCommentId)`.
- [x] Make dislike insert/update set `hidden_until = now() + 14 days`.
- [x] Filter active disliked posts from Home, Following, and Search.

### Task 3: Card And Detail UI

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/presentation/feed_card.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Create: `apps/mobile/lib/src/features/posts/presentation/report_post_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`

- [x] Remove Report from card quick action and make the one-button overlay responsive.
- [x] Remove quick action overlay from Profile cards.
- [x] Move share count into the post detail bottom bar and remove dislike count from that bar.
- [x] Keep dislike only in post card quick action and post detail share sheet.
- [x] Show custom dislike snackbar with Cancel and Report.
- [x] Add Instagram-style report reason page with thank-you state.
- [x] Add Reply under comments and post replies with `parent_comment_id`.
- [x] Refresh detail state from Supabase after like/save/dislike/share/comment changes.

### Task 4: Verification

**Files:**
- Run: `apps/mobile`

- [x] Run focused Flutter tests.
- [x] Run `flutter analyze`.
- [x] Run `flutter test`.
