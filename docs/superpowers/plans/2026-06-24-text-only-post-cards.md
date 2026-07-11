# Text-Only Post Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render posts without images as readable fixed-ratio text cards and keep card/detail presentation synchronized after editing images.

**Architecture:** Add a model-level text-only classification and branch only the feed card body. Image posts retain their existing media-first layout; text-only posts use a dedicated 3:4 content layout with a bottom-anchored shared author row. Post detail already derives its media section from the image list, so refreshed post data remains the presentation source of truth.

**Tech Stack:** Flutter, Dart, flutter_test

---

### Task 1: Define And Test Text-Only Classification

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/data/feed_post.dart`
- Test: `apps/mobile/test/feed_post_test.dart`

- [x] Add a failing test asserting an empty image list is text-only and a non-empty image list is not.
- [x] Run `flutter test test/feed_post_test.dart` and confirm the new getter is missing.
- [x] Add `bool get isTextOnly => imageUrls.isEmpty`.
- [x] Re-run the focused test and confirm it passes.

### Task 2: Render The 3:4 Text Card

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/presentation/feed_card.dart`
- Create: `apps/mobile/test/feed_card_test.dart`

- [x] Add a widget test that pumps a text-only card in a constrained width.
- [x] Assert its height follows a 3:4 ratio, title/content/author are visible, and the image placeholder icon is absent.
- [x] Run the widget test and confirm it fails with the current placeholder layout.
- [x] Branch the card body on `post.isTextOnly`.
- [x] Build the text-only body with full title, flexible truncated content, and the existing author/like row anchored at the bottom.
- [x] Re-run the widget test and confirm it passes.

### Task 3: Keep Waterfall Estimates Accurate

**Files:**
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_waterfall_layout.dart`
- Test: `apps/mobile/test/post_waterfall_layout_test.dart`

- [x] Add a failing test asserting a text-only card is estimated as `cardWidth / 0.75`.
- [x] Update the estimator to use the complete fixed 3:4 card height for text-only posts.
- [x] Run the focused waterfall tests and confirm they pass.

### Task 4: Document Handover And Verify

**Files:**
- Modify: `Project_Overview.md`

- [x] Document text-only creation/card/detail/edit-switch behavior.
- [x] Document that skeletons are immediate loading indicators only and never an artificial delay.
- [x] Correct stale handover notes that contradict the implemented reply comments, moderation statuses, follow logic, and current test count.
- [x] Run `dart format` on modified Dart files.
- [x] Run `flutter analyze`.
- [x] Run `flutter test`.
