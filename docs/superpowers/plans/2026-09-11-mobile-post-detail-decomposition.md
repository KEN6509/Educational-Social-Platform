# Mobile Post Detail Decomposition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the oversized mobile Post Detail presentation file into cohesive feature-local units without changing user-visible behavior or data access.

**Architecture:** Keep `post_detail_page.dart` as the owning Dart library and stateful coordinator. Move private media, share-sheet, comment, and visual-action widgets into `part` files so they remain encapsulated and can still use the library's private types. This is a structural checkpoint only: repository construction, Supabase calls, moderation, navigation, and interaction rules remain unchanged.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test

---

## Scope and constraints

- Work only in `apps/mobile` and the related plan document.
- Run commands from the user's original CyanZone folder; do not create a worktree.
- Preserve every existing public constructor and route.
- Preserve the exact widget bodies while moving them. Do not redesign Post Detail in this checkpoint.
- Do not add Riverpod, another state package, or any dependency.
- Do not change `PostsRepository`, Supabase SQL, the API, Admin, chat behavior, or moderation behavior.
- Keep `_PostDetailPageState` in `post_detail_page.dart`; it remains the coordinator for loading, mutations, navigation, and callbacks.
- Use `part` files as an incremental encapsulation step. Do not make internal widgets public merely to move them.

## Target file responsibilities

- `post_detail_page.dart`: public page, page state, data loading, interaction orchestration, navigation, and the main widget tree.
- `post_detail_media.dart`: cached detail image, full-screen preview, zoom/pan behavior, download action, preview header, and image failure state.
- `post_share_sheet.dart`: recent chat loading, contact search/selection, adaptive sheet sizing, native share action, report/edit/delete action grid, and contact avatar.
- `post_detail_comments.dart`: comments error state, comment composer modal, reply visibility control, comment row, comment metadata/content, comment actions, and comment-like button.
- `post_detail_actions.dart`: small reusable visual action and follow buttons used by the Post Detail tree.
- `post_detail_decomposition_test.dart`: structural contracts proving responsibilities remain outside the owning coordinator file.

### Task 1: Extract the media-viewer responsibility

**Files:**
- Create: `apps/mobile/lib/src/features/posts/presentation/post_detail_media.dart`
- Create: `apps/mobile/test/post_detail_decomposition_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write the failing media boundary test**

Create `post_detail_decomposition_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const presentationPath = 'lib/src/features/posts/presentation';

  test('post detail media lives in its feature-local part', () {
    final page = File('$presentationPath/post_detail_page.dart')
        .readAsStringSync();
    final mediaFile = File('$presentationPath/post_detail_media.dart');

    expect(page, contains("part 'post_detail_media.dart';"));
    expect(mediaFile.existsSync(), isTrue);
    if (!mediaFile.existsSync()) return;

    final media = mediaFile.readAsStringSync();
    expect(media, startsWith("part of 'post_detail_page.dart';"));
    expect(media, contains('class _PostDetailNetworkImage'));
    expect(media, contains('class _PostDetailImagePreviewPage'));
    expect(media, contains('class _PostDetailZoomablePreviewImage'));
    expect(media, contains('class _PostDetailPreviewHeader'));
    expect(media, contains('class _PostDetailImageLoadError'));
    expect(page, isNot(contains('class _PostDetailImagePreviewPage')));
  });
}
```

- [ ] **Step 2: Run the test and verify the absent part fails**

Run: `flutter test test/post_detail_decomposition_test.dart --plain-name "post detail media lives in its feature-local part" --reporter expanded`

Expected: FAIL because the part directive and media file do not exist.

- [ ] **Step 3: Move the exact media classes into the part file**

Add this directive after the imports in `post_detail_page.dart`:

```dart
part 'post_detail_media.dart';
```

Create `post_detail_media.dart` with this first line:

```dart
part of 'post_detail_page.dart';
```

Move these complete declarations, without changing their bodies or names, from `post_detail_page.dart` into `post_detail_media.dart` in the same order:

```text
_PostDetailNetworkImage
_PostDetailNetworkImageState
_PostDetailImagePreviewPage
_PostDetailImagePreviewPageState
_PostDetailZoomablePreviewImage
_PostDetailZoomablePreviewImageState
_PostDetailPreviewHeader
_PostDetailPreviewHeaderButton
_PostDetailImageLoadError
```

Leave `_CommentsLoadError` and `_CommentInputModal` in `post_detail_page.dart` for Task 3.

- [ ] **Step 4: Point the existing preview source contract at both owning files**

In the `post detail image preview uses preview transition and download action` test, read the sources separately:

```dart
final pageSource =
    File('lib/src/features/posts/presentation/post_detail_page.dart')
        .readAsStringSync();
final mediaSource =
    File('lib/src/features/posts/presentation/post_detail_media.dart')
        .readAsStringSync();
final source = '$pageSource\n$mediaSource';
final carouselStart = pageSource.indexOf('PageView.builder');
final carouselEnd =
    pageSource.indexOf('if (visibleImageUrls.length > 1)');
```

Build `carouselSource` from `pageSource`; keep the remaining existing assertions against the combined `source` so the behavior contract survives the move.

- [ ] **Step 5: Format and verify the media extraction**

Run: `dart format lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_media.dart test/post_detail_decomposition_test.dart test/chat_widgets_test.dart`

Run: `flutter analyze lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_media.dart test/post_detail_decomposition_test.dart`

Run: `flutter test test/post_detail_decomposition_test.dart test/chat_widgets_test.dart --reporter compact`

Expected: analysis exits with no issues and all selected tests pass.

- [ ] **Step 6: Commit the media extraction**

```bash
git add apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart apps/mobile/lib/src/features/posts/presentation/post_detail_media.dart apps/mobile/test/post_detail_decomposition_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): extract post detail media"
```

### Task 2: Extract the share-sheet responsibility

**Files:**
- Create: `apps/mobile/lib/src/features/posts/presentation/post_share_sheet.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/test/post_detail_decomposition_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add the failing share-sheet boundary test**

Append inside `main()` in `post_detail_decomposition_test.dart`:

```dart
test('post share sheet lives in its feature-local part', () {
  final page = File('$presentationPath/post_detail_page.dart')
      .readAsStringSync();
  final shareFile = File('$presentationPath/post_share_sheet.dart');

  expect(page, contains("part 'post_share_sheet.dart';"));
  expect(shareFile.existsSync(), isTrue);
  if (!shareFile.existsSync()) return;

  final share = shareFile.readAsStringSync();
  expect(share, startsWith("part of 'post_detail_page.dart';"));
  expect(share, contains('class _ShareSheet'));
  expect(share, contains('class _ShareContactAvatar'));
  expect(share, contains('class _ActionGridItem'));
  expect(page, isNot(contains('class _ShareSheet')));
});
```

- [ ] **Step 2: Run the test and verify the absent part fails**

Run: `flutter test test/post_detail_decomposition_test.dart --plain-name "post share sheet lives in its feature-local part" --reporter expanded`

Expected: FAIL because the part directive and share file do not exist.

- [ ] **Step 3: Move the exact share-sheet classes into the part file**

Add this directive beside the media part directive:

```dart
part 'post_share_sheet.dart';
```

Create `post_share_sheet.dart` beginning with:

```dart
part of 'post_detail_page.dart';
```

Move these complete declarations without changing their bodies or names:

```text
_ShareSheet
_ShareSheetState
_ShareContactAvatar
_ActionGridItem
```

- [ ] **Step 4: Update the existing share-sheet source contract**

In `share sheet reuses Message page group avatar styling`, replace the source path with:

```dart
final source =
    File('lib/src/features/posts/presentation/post_share_sheet.dart')
        .readAsStringSync();
```

Keep all existing assertions unchanged.

- [ ] **Step 5: Format and verify the share extraction**

Run: `dart format lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_share_sheet.dart test/post_detail_decomposition_test.dart test/chat_widgets_test.dart`

Run: `flutter analyze lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_share_sheet.dart test/post_detail_decomposition_test.dart`

Run: `flutter test test/post_detail_decomposition_test.dart test/chat_widgets_test.dart --reporter compact`

Expected: analysis exits with no issues and all selected tests pass.

- [ ] **Step 6: Commit the share-sheet extraction**

```bash
git add apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart apps/mobile/lib/src/features/posts/presentation/post_share_sheet.dart apps/mobile/test/post_detail_decomposition_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "refactor(mobile): extract post share sheet"
```

### Task 3: Extract comment presentation widgets

**Files:**
- Create: `apps/mobile/lib/src/features/posts/presentation/post_detail_comments.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/test/post_detail_decomposition_test.dart`
- Modify: `apps/mobile/test/post_comment_test.dart`

- [ ] **Step 1: Add the failing comment boundary test**

Append inside `main()`:

```dart
test('post detail comment widgets live in their feature-local part', () {
  final page = File('$presentationPath/post_detail_page.dart')
      .readAsStringSync();
  final commentsFile = File('$presentationPath/post_detail_comments.dart');

  expect(page, contains("part 'post_detail_comments.dart';"));
  expect(commentsFile.existsSync(), isTrue);
  if (!commentsFile.existsSync()) return;

  final comments = commentsFile.readAsStringSync();
  expect(comments, startsWith("part of 'post_detail_page.dart';"));
  expect(comments, contains('class _CommentsLoadError'));
  expect(comments, contains('class _CommentInputModal'));
  expect(comments, contains('class _CommentItem'));
  expect(comments, contains('class _CommentLikeButton'));
  expect(page, isNot(contains('class _CommentItem')));
});
```

- [ ] **Step 2: Run the test and verify the absent part fails**

Run: `flutter test test/post_detail_decomposition_test.dart --plain-name "post detail comment widgets live in their feature-local part" --reporter expanded`

Expected: FAIL because the part directive and comment file do not exist.

- [ ] **Step 3: Move the exact comment widget declarations**

Add:

```dart
part 'post_detail_comments.dart';
```

Create `post_detail_comments.dart` beginning with:

```dart
part of 'post_detail_page.dart';
```

Move these complete declarations without changing their bodies or names:

```text
_CommentsLoadError
_CommentInputModal
_ViewRepliesButton
_CommentItem
_CommentItemState
_CommentMetaBadge
_CommentSecondaryMeta
_CommentContentText
_CommentActionTile
_CommentLikeButton
```

Keep comment fetching, moderation, action sheets, delete/pin/report/copy operations, expansion state, and comment keys in `_PostDetailPageState`.

- [ ] **Step 4: Preserve the initial-comment source contract across the split**

In `post_comment_test.dart`, combine the coordinator and comment-part sources:

```dart
final pageSource = File(
  'lib/src/features/posts/presentation/post_detail_page.dart',
).readAsStringSync();
final commentsSource = File(
  'lib/src/features/posts/presentation/post_detail_comments.dart',
).readAsStringSync();
final source = '$pageSource\n$commentsSource';
```

Keep the existing `initialCommentId`, focus, expansion, unavailable-message, and `Scrollable.ensureVisible` assertions unchanged.

- [ ] **Step 5: Format and verify the comment extraction**

Run: `dart format lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_comments.dart test/post_detail_decomposition_test.dart test/post_comment_test.dart`

Run: `flutter analyze lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_comments.dart test/post_detail_decomposition_test.dart test/post_comment_test.dart`

Run: `flutter test test/post_detail_decomposition_test.dart test/post_comment_test.dart test/chat_widgets_test.dart --reporter compact`

Expected: analysis exits with no issues and all selected tests pass.

- [ ] **Step 6: Commit the comment extraction**

```bash
git add apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart apps/mobile/lib/src/features/posts/presentation/post_detail_comments.dart apps/mobile/test/post_detail_decomposition_test.dart apps/mobile/test/post_comment_test.dart
git commit -m "refactor(mobile): extract post detail comments"
```

### Task 4: Extract the remaining visual action widgets

**Files:**
- Create: `apps/mobile/lib/src/features/posts/presentation/post_detail_actions.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/test/post_detail_decomposition_test.dart`

- [ ] **Step 1: Add the failing action-widget boundary test**

Append inside `main()`:

```dart
test('post detail visual actions live in their feature-local part', () {
  final page = File('$presentationPath/post_detail_page.dart')
      .readAsStringSync();
  final actionsFile = File('$presentationPath/post_detail_actions.dart');

  expect(page, contains("part 'post_detail_actions.dart';"));
  expect(actionsFile.existsSync(), isTrue);
  if (!actionsFile.existsSync()) return;

  final actions = actionsFile.readAsStringSync();
  expect(actions, startsWith("part of 'post_detail_page.dart';"));
  expect(actions, contains('class _ActionButton'));
  expect(actions, contains('class _FollowButton'));
  expect(page, isNot(contains('class _ActionButton')));
});
```

- [ ] **Step 2: Run the test and verify the absent part fails**

Run: `flutter test test/post_detail_decomposition_test.dart --plain-name "post detail visual actions live in their feature-local part" --reporter expanded`

Expected: FAIL because the part directive and action file do not exist.

- [ ] **Step 3: Move the exact visual action declarations**

Add:

```dart
part 'post_detail_actions.dart';
```

Create `post_detail_actions.dart` beginning with:

```dart
part of 'post_detail_page.dart';
```

Move `_ActionButton` and `_FollowButton` with their complete existing bodies. Keep their names private and do not alter callbacks, icon state, loading state, colours, dimensions, or labels.

- [ ] **Step 4: Format and verify the action extraction**

Run: `dart format lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_actions.dart test/post_detail_decomposition_test.dart`

Run: `flutter analyze lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_actions.dart test/post_detail_decomposition_test.dart`

Run: `flutter test test/post_detail_decomposition_test.dart test/post_comment_test.dart test/chat_widgets_test.dart --reporter compact`

Expected: analysis exits with no issues and all selected tests pass.

- [ ] **Step 5: Commit the action extraction**

```bash
git add apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart apps/mobile/lib/src/features/posts/presentation/post_detail_actions.dart apps/mobile/test/post_detail_decomposition_test.dart
git commit -m "refactor(mobile): extract post detail actions"
```

### Task 5: Complete the Posts decomposition checkpoint

**Files:**
- Modify only if verification exposes a regression in the files listed above.

- [ ] **Step 1: Verify the library structure**

Run: `flutter test test/post_detail_decomposition_test.dart --reporter expanded`

Expected: four tests pass. Confirm `post_detail_page.dart` contains no private widget class declarations other than `_PostDetailPageState`.

- [ ] **Step 2: Run related Posts and navigation tests**

Run: `flutter test test/post_comment_test.dart test/chat_widgets_test.dart test/feed_card_test.dart test/feed_post_test.dart test/posts_repository_test.dart test/post_interaction_sync_test.dart test/content_moderation_scope_test.dart --reporter compact`

Expected: all selected tests pass with zero failures.

- [ ] **Step 3: Run full static analysis**

Run: `flutter analyze`

Expected: exit code 0 with no issues.

- [ ] **Step 4: Run the full mobile suite at this major checkpoint**

Run: `flutter test --reporter compact`

Expected: exit code 0 and zero failed tests. This is the posts-stage checkpoint required by the approved refactor design; it is not repeated after every small extraction.

- [ ] **Step 5: Check formatting and whitespace**

Run: `dart format lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/post_detail_media.dart lib/src/features/posts/presentation/post_share_sheet.dart lib/src/features/posts/presentation/post_detail_comments.dart lib/src/features/posts/presentation/post_detail_actions.dart test/post_detail_decomposition_test.dart test/post_comment_test.dart test/chat_widgets_test.dart`

Run from repository root: `git diff --check`

Expected: formatter makes no further changes and Git reports no whitespace errors.

- [ ] **Step 6: Perform a focused Android smoke check**

On the available Android phone, verify one text post and one multi-image post:

- Post Detail opens and returns normally.
- Like, save, comment, reply, share, and owner actions behave as before.
- Full-screen images page, zoom, close, and return to the same carousel index.
- The Download action still reports success or a friendly failure.
- No action or final content is hidden behind the floating navigation.

Record any unavailable physical-device evidence in the handoff; do not expand this checkpoint to unrelated pages.

## Completion gate

This checkpoint is complete when all extracted widgets compile as one private Dart library, the structural and existing behavior contracts pass, full analysis and the full mobile test suite pass, the Android smoke check has no known blocker, and `git diff --check` is clean. The next stage may then address Post Detail dependency construction and item-level interaction updates with separate behavior tests; those runtime changes are intentionally excluded from this structural plan.
