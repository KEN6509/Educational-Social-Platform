# Smooth Media Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove visible image/avatar reloads across cards, post detail, and profiles while correcting text-card composition and create/edit validation.

**Architecture:** Extend the existing disk caches with process-memory values and shared in-flight requests so screens reuse the same resolved media. Show cached profile/post state immediately and revalidate silently. Start ratio and multi-image preloads in the background instead of awaiting them before rendering fetched data.

**Tech Stack:** Flutter, Dart, SharedPreferences, application documents cache, flutter_test

---

### Task 1: Shared Warm Media Cache

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/data/post_image_disk_cache.dart`
- Modify: `apps/mobile/lib/src/features/profile/data/profile_avatar_cache.dart`
- Test: `apps/mobile/test/media_cache_test.dart`

- [x] Test that memory values can be synchronously retrieved after being warmed.
- [x] Add shared in-flight futures so duplicate URL requests reuse one download.
- [x] Add memory maps, synchronous peek APIs, and in-flight future maps.
- [x] Keep disk persistence and network fallback unchanged.

### Task 2: Text Card And Create/Edit Corrections

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/presentation/feed_card.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_waterfall_layout.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`
- Create: `apps/mobile/lib/src/features/posts/presentation/create_post_validation.dart`
- Test: `apps/mobile/test/feed_card_test.dart`
- Test: `apps/mobile/test/create_post_validation_test.dart`

- [x] Test that only the text content surface is 3:4 and the normal title/author footer remains below it.
- [x] Test that Pending/Rejected appears inside the 3:4 surface.
- [x] Test that content or at least one image satisfies post body validation.
- [x] Render content in the replacement media area and retain normal footer truncation.
- [x] Use contained edit thumbnails on a neutral background.
- [x] Remove field-level required content validation and show one snackbar when both content and images are empty.

### Task 3: Smooth Card And Detail Transitions

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/presentation/feed_card.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`

- [x] Seed card image widgets from the synchronous warm-file cache.
- [x] Preserve displayed files while fresh post data is fetched after returning.
- [x] Pass already-loaded avatar bytes into Post Detail.
- [x] Preload all images for the selected post in the background.

### Task 4: Silent Feed/Profile Revalidation

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/presentation/home_feed_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`

- [x] Stop awaiting aspect-ratio preloading before rendering fetched Home posts.
- [x] Warm first images and bounded multi-image post media in the background.
- [x] Reuse profile and avatar memory synchronously on repeated navigation.
- [x] Keep cached posted cards visible while profile/posts revalidate.
- [x] Show skeletons only when no usable memory/disk data exists.

### Task 5: Documentation And Verification

**Files:**
- Modify: `Project_Overview.md`

- [x] Document warm-cache, background preload, stale-while-revalidate, and no-artificial-loader rules.
- [x] Run `dart format`.
- [x] Run focused tests.
- [x] Run `flutter analyze`.
- [x] Run the full `flutter test` suite.
