# Mobile Layout and Post Ordering Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct Parent Supervision and Create Post spacing around the floating navigation, and make Profile, Saved, Liked, and Following ordering follow the approved rules without changing the main Feed.

**Architecture:** Extend the existing navigation-clearance helper instead of duplicating inset calculations. Put deterministic post ordering in pure functions, preserve like/save interaction order in repository queries, and let Home distinguish an initial Following load from a user refresh.

**Tech Stack:** Flutter, Dart, Supabase/PostgREST, flutter_test

---

## File Responsibilities

- `apps/mobile/lib/src/core/widgets/navigation_clearance.dart`: calculate overlay-safe padding with optional breathing room.
- `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`: use semantic background tokens.
- `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart`: apply shared page and navigation insets.
- `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`: remove nested-grid padding and protect the Post button.
- `apps/mobile/lib/src/features/posts/data/post_collection_order.dart`: pure Profile and Home ordering rules.
- `apps/mobile/lib/src/features/posts/data/posts_repository.dart`: stable database ordering for Following, Saved, and Liked.
- `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`: normalize owner-post order after fetch, cache restoration, and updates.
- `apps/mobile/lib/src/features/posts/presentation/home_feed_page.dart`: rearrange Following only after a user refresh.

## Task 1: Extend Shared Navigation Clearance

**Files:**

- Modify: `apps/mobile/test/navigation_clearance_test.dart`
- Modify: `apps/mobile/lib/src/core/widgets/navigation_clearance.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that injects 86 pixels of bottom `MediaQuery` padding, passes `additionalBottom: AppSpacing.lg`, and expects a 102-pixel bottom inset while preserving the supplied side insets.

- [ ] **Step 2: Run the test to verify it fails**

Run `flutter test test/navigation_clearance_test.dart` from `apps/mobile`.

Expected: compilation fails because `additionalBottom` is not defined.

- [ ] **Step 3: Implement the minimum helper change**

Use this signature and calculation:

```dart
EdgeInsets withNavigationClearance(
  BuildContext context,
  EdgeInsets insets, {
  double additionalBottom = 0,
}) {
  return insets.copyWith(
    bottom: math.max(
      insets.bottom,
      MediaQuery.paddingOf(context).bottom + additionalBottom,
    ),
  );
}
```

- [ ] **Step 4: Run the focused test**

Run `flutter test test/navigation_clearance_test.dart`.

Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/core/widgets/navigation_clearance.dart apps/mobile/test/navigation_clearance_test.dart
git commit -m "refactor(mobile): support navigation breathing room"
```

## Task 2: Correct Parent Supervision and Create Post Layouts

**Files:**

- Modify: `apps/mobile/test/parent_supervision_page_test.dart`
- Modify: `apps/mobile/test/create_post_validation_test.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`

- [ ] **Step 1: Write failing layout assertions**

Update the supervision test to expect `AppColors.background`, a 20-pixel first-card left edge, and 102 pixels of bottom padding when the shell exposes 86 pixels. Extend the Create Post regression test to require `padding: EdgeInsets.zero` inside `_ModernImageGrid`, `AppSpacing.section` after the grid, and navigation clearance with `additionalBottom: AppSpacing.lg` around the outer scroll padding.

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/parent_supervision_page_test.dart test/create_post_validation_test.dart
```

Expected: assertions fail against the old grey background, 8-pixel inset, automatic grid padding, and fixed bottom padding.

- [ ] **Step 3: Apply semantic tokens and safe scrolling**

Set the Parent Supervision scaffold and app bar to `AppColors.background`. Use `AppSpacing.page` on both sides of the dashboard list and call `withNavigationClearance` with `additionalBottom: AppSpacing.lg`.

In Create Post, wrap the scroll padding with `withNavigationClearance`, add `additionalBottom: AppSpacing.lg`, replace the Images-to-Title gap with `AppSpacing.section`, and set the nested image grid padding to `EdgeInsets.zero`.

- [ ] **Step 4: Format and verify**

Run:

```powershell
dart format lib/src/features/parent_child/presentation/parent_child_page.dart lib/src/features/parent_child/presentation/supervision_dashboards.dart lib/src/features/posts/presentation/create_post_page.dart test/parent_supervision_page_test.dart test/create_post_validation_test.dart
flutter test test/parent_supervision_page_test.dart test/create_post_validation_test.dart test/navigation_clearance_test.dart
flutter analyze lib/src/features/parent_child/presentation lib/src/features/posts/presentation/create_post_page.dart
```

Expected: formatting succeeds, focused tests pass, and analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart apps/mobile/lib/src/features/posts/presentation/create_post_page.dart apps/mobile/test/parent_supervision_page_test.dart apps/mobile/test/create_post_validation_test.dart
git commit -m "fix(mobile): align supervision and post form spacing"
```

## Task 3: Make Profile and Repository Ordering Deterministic

**Files:**

- Create: `apps/mobile/lib/src/features/posts/data/post_collection_order.dart`
- Create: `apps/mobile/test/post_collection_order_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/data/posts_repository.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`

- [ ] **Step 1: Write failing pure ordering tests**

Build mixed pending, rejected, and approved posts. Assert that `orderProfilePosts` puts all non-approved posts first, orders each approval group by `createdAt` descending, and uses post ID descending when timestamps tie. Add source-level assertions that Saved and Liked order their interaction rows by `created_at` then `post_id`, both descending.

- [ ] **Step 2: Run the tests to verify they fail**

Run `flutter test test/post_collection_order_test.dart`.

Expected: compilation fails because the ordering helper does not exist.

- [ ] **Step 3: Implement pure ordering**

Create:

```dart
List<FeedPost> orderNewestPosts(Iterable<FeedPost> posts) {
  return posts.toList()
    ..sort((a, b) {
      final dateOrder = b.createdAt.compareTo(a.createdAt);
      return dateOrder != 0 ? dateOrder : b.id.compareTo(a.id);
    });
}

List<FeedPost> orderProfilePosts(Iterable<FeedPost> posts) {
  return posts.toList()
    ..sort((a, b) {
      final approvalOrder =
          (a.isApproved ? 1 : 0).compareTo(b.isApproved ? 1 : 0);
      if (approvalOrder != 0) return approvalOrder;
      final dateOrder = b.createdAt.compareTo(a.createdAt);
      return dateOrder != 0 ? dateOrder : b.id.compareTo(a.id);
    });
}
```

Apply `orderProfilePosts` only to the posted Profile grid whenever it accepts fetched, cached, or updated posts. Keep Liked and Saved in repository interaction order. Add `post_id` as the secondary descending key to both interaction queries, and normalize Following results with `orderNewestPosts` after mapping.

- [ ] **Step 4: Format and verify**

Run:

```powershell
dart format lib/src/features/posts/data/post_collection_order.dart lib/src/features/posts/data/posts_repository.dart lib/src/features/profile/presentation/profile_page.dart test/post_collection_order_test.dart
flutter test test/post_collection_order_test.dart test/post_interaction_sync_test.dart
flutter analyze lib/src/features/posts/data lib/src/features/profile/presentation/profile_page.dart
```

Expected: focused tests pass and analyzer reports no issues.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/posts/data/post_collection_order.dart apps/mobile/lib/src/features/posts/data/posts_repository.dart apps/mobile/lib/src/features/profile/presentation/profile_page.dart apps/mobile/test/post_collection_order_test.dart
git commit -m "fix(mobile): stabilize profile post ordering"
```

## Task 4: Rearrange Following Only on User Refresh

**Files:**

- Modify: `apps/mobile/lib/src/features/posts/data/post_collection_order.dart`
- Modify: `apps/mobile/test/post_collection_order_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/home_feed_page.dart`

- [ ] **Step 1: Write failing Home arrangement tests**

With a seeded `Random`, assert that Saves preserves repository order, Following preserves newest-first input when `rearrangeFollowing` is false, Following may shuffle when it is true, and Feeds keeps its existing shuffle behavior.

- [ ] **Step 2: Run the test to verify it fails**

Run `flutter test test/post_collection_order_test.dart`.

Expected: compilation fails because `arrangeHomePosts` does not exist.

- [ ] **Step 3: Implement explicit arrangement**

Add:

```dart
List<FeedPost> arrangeHomePosts(
  Iterable<FeedPost> posts, {
  required FeedMode mode,
  required bool rearrangeFollowing,
  Random? random,
}) {
  final arranged = posts.toList();
  if (mode == FeedMode.feeds ||
      (mode == FeedMode.following && rearrangeFollowing)) {
    arranged.shuffle(random);
  }
  return arranged;
}
```

Change `_fetchPosts` to accept `rearrangeFollowing = false`. A user refresh passes `true`; `initState` and `didUpdateWidget` pass `false`. Replace the direct Feed shuffle with this helper so the main Feed condition stays unchanged.

- [ ] **Step 4: Run final verification**

Run:

```powershell
dart format lib/src/features/posts/data/post_collection_order.dart lib/src/features/posts/presentation/home_feed_page.dart test/post_collection_order_test.dart
flutter test test/post_collection_order_test.dart test/navigation_clearance_test.dart test/parent_supervision_page_test.dart test/create_post_validation_test.dart test/cyanzone_bottom_navigation_test.dart
flutter analyze
flutter test --reporter compact
git diff --check
```

Expected: focused and complete tests pass, analyzer reports no issues, and Git reports no whitespace errors.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/posts/data/post_collection_order.dart apps/mobile/lib/src/features/posts/presentation/home_feed_page.dart apps/mobile/test/post_collection_order_test.dart
git commit -m "fix(mobile): control following refresh order"
```

## Manual Checkpoint

- Parent Supervision uses the Social Feed background and 20-pixel side insets.
- The last supervision notification scrolls above the floating navigation.
- Create Post has a normal Images-to-Title gap and the Post button scrolls at least 16 pixels above navigation.
- Profile non-approved posts stay above approved posts after refresh.
- Profile Liked/Saved and Home Saves show the most recently liked/saved items first.
- Following opens newest-first and can rearrange after pull-to-refresh.
- Feeds behaves exactly as before.
