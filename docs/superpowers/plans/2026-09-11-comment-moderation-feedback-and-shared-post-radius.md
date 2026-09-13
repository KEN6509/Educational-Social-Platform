# Comment Moderation Feedback and Shared-Post Radius Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every submitted comment immediate AI-moderation feedback and correct the nested corner radius of shared-post chat cards.

**Architecture:** Keep comment persistence and moderation sequencing inside `PostDetailPage`, but route its user-visible moderation states through the reusable `AppFeedback` component so each newer state replaces the earlier one. Preserve the existing chat bubble geometry and change only the nested shared-post `Card` radius from 8 dp to 12 dp.

**Tech Stack:** Flutter, Dart, Material widgets, existing `AppFeedback`, Flutter widget tests

---

### Task 0: Preserve the verified interaction and share fixes

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_share_sheet.dart`
- Modify: `apps/mobile/test/chat_repository_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/test/push_runtime_contract_test.dart`
- Modify: `supabase/fcm_push_notifications.sql`

- [ ] **Step 1: Confirm the verified changes are the only existing working-tree changes**

Run from the repository root:

```powershell
git status --short
git diff --check
```

Expected: only the six files listed above are modified, and `git diff --check` reports no errors.

- [ ] **Step 2: Commit the already phone-verified fixes**

```powershell
git add -- apps/mobile/lib/src/features/chat/data/chat_repository.dart apps/mobile/lib/src/features/posts/presentation/post_share_sheet.dart apps/mobile/test/chat_repository_test.dart apps/mobile/test/chat_widgets_test.dart apps/mobile/test/push_runtime_contract_test.dart supabase/fcm_push_notifications.sql
git commit -m "fix(mobile): restore interactions and secure post sharing"
```

Expected: one commit containing the live notification-trigger correction and fresh share-recipient enforcement.

### Task 1: Show and replace comment moderation feedback

**Files:**
- Modify: `apps/mobile/test/post_comment_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`

- [ ] **Step 1: Write the failing submission-order regression test**

Append this test to `apps/mobile/test/post_comment_test.dart`:

```dart
test('comment submission shows pending feedback before moderation', () {
  final source = File(
    'lib/src/features/posts/presentation/post_detail_page.dart',
  ).readAsStringSync();

  final createIndex = source.indexOf('final commentId = await repo.createComment');
  final pendingIndex = source.indexOf(
    'Comment submitted. AI moderation is checking it.',
    createIndex,
  );
  final moderateIndex = source.indexOf(
    'await _moderateComment(commentId',
    createIndex,
  );

  expect(createIndex, greaterThanOrEqualTo(0));
  expect(pendingIndex, greaterThan(createIndex));
  expect(moderateIndex, greaterThan(pendingIndex));
  expect(source, contains('AppFeedback.show(pageContext'));
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run from `apps/mobile`:

```powershell
flutter test test/post_comment_test.dart
```

Expected: FAIL because the pending feedback text and `AppFeedback.show(pageContext` call do not exist.

- [ ] **Step 3: Show the pending feedback after persistence succeeds**

In `post_detail_page.dart`, import the shared feedback component:

```dart
import '../../../core/widgets/app_feedback.dart';
```

At the start of the send callback, capture the page context before closing the bottom sheet:

```dart
final pageContext = this.context;
final navigator = Navigator.of(context);
```

Immediately after `createComment` returns and before `_moderateComment` starts, add:

```dart
if (!mounted) return;
AppFeedback.show(
  pageContext,
  message: 'Comment submitted. AI moderation is checking it.',
  kind: AppFeedbackKind.warning,
);
await _moderateComment(commentId);
```

The shared callback is used by top-level comments and replies, so both paths receive the same feedback.

- [ ] **Step 4: Make every final moderation state replace pending feedback**

Change `_moderateComment` to accept only `commentId`, then use `AppFeedback` for each result. The important branch mapping is:

```dart
case ContentModerationState.approved:
  AppFeedback.showSuccess(context, 'Comment posted!');
  await _refreshPostState(updateCommentCount: false);
  await _fetchComments();
case ContentModerationState.adminReview:
  AppFeedback.show(
    context,
    message: 'Comment sent for administrator review.',
    kind: AppFeedbackKind.warning,
  );
case ContentModerationState.processing:
  AppFeedback.show(
    context,
    message: 'Comment moderation is still processing.',
    kind: AppFeedbackKind.warning,
  );
case ContentModerationState.rejected:
  AppFeedback.showError(
    context,
    result.reason ?? 'Comment was not posted.',
  );
case ContentModerationState.superseded:
  AppFeedback.show(
    context,
    message: 'This comment changed. Please submit it again.',
    kind: AppFeedbackKind.warning,
  );
case ContentModerationState.failed:
  _showCommentModerationRetry(commentId);
```

Implement retry feedback with the same component so its action also replaces the current snackbar:

```dart
void _showCommentModerationRetry(String commentId) {
  AppFeedback.show(
    context,
    message: 'Comment moderation could not complete.',
    kind: AppFeedbackKind.error,
    actions: [
      AppFeedbackAction(
        label: 'Retry moderation',
        onPressed: () => _moderateComment(commentId),
      ),
    ],
  );
}
```

Use `AppFeedback.showError(context, error.message)` for a non-retryable `ContentModerationFailure`.

- [ ] **Step 5: Run the focused test and verify GREEN**

```powershell
dart format lib/src/features/posts/presentation/post_detail_page.dart test/post_comment_test.dart
flutter test test/post_comment_test.dart
```

Expected: all tests in `post_comment_test.dart` pass.

- [ ] **Step 6: Commit the comment feedback change**

```powershell
git add -- apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart apps/mobile/test/post_comment_test.dart
git commit -m "fix(mobile): explain pending comment moderation"
```

### Task 2: Correct nested shared-post card corners

**Files:**
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`

- [ ] **Step 1: Extend the existing shared-post widget test**

After pumping the shared-post message in `ChatMessageBubble renders shared posts as compact post cards`, add:

```dart
final bubble = tester.widget<Container>(
  find.byKey(const ValueKey('chat-message-bubble')),
);
final bubbleDecoration = bubble.decoration! as BoxDecoration;
final bubbleRadius = bubbleDecoration.borderRadius! as BorderRadius;
expect(bubbleRadius.topLeft, const Radius.circular(16));

final card = tester.widget<Card>(find.byType(Card));
final cardShape = card.shape! as RoundedRectangleBorder;
final cardRadius = cardShape.borderRadius.resolve(TextDirection.ltr);
expect(cardRadius.topLeft, const Radius.circular(12));
expect(cardRadius.topRight, const Radius.circular(12));
```

- [ ] **Step 2: Run the widget test and verify RED**

```powershell
flutter test test/chat_widgets_test.dart --plain-name "ChatMessageBubble renders shared posts as compact post cards"
```

Expected: FAIL because the current inner card radius is 8 dp instead of 12 dp.

- [ ] **Step 3: Apply the geometric radius correction**

In `_SharedPostBubbleContent`, change only the card shape:

```dart
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  side: const BorderSide(color: Color(0xFFE6F0F1)),
),
```

Keep the outer message radius and rich-content padding unchanged.

- [ ] **Step 4: Run the focused widget test and verify GREEN**

```powershell
dart format lib/src/features/chat/presentation/chat_widgets.dart test/chat_widgets_test.dart
flutter test test/chat_widgets_test.dart --plain-name "ChatMessageBubble renders shared posts as compact post cards"
```

Expected: the shared-post widget test passes.

- [ ] **Step 5: Commit the shared-post UI correction**

```powershell
git add -- apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix(mobile): align shared post card corners"
```

### Task 3: Focused verification

**Files:**
- Verify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Verify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Verify: related tests

- [ ] **Step 1: Run the related regression tests**

Run from `apps/mobile`:

```powershell
flutter test test/post_comment_test.dart test/chat_widgets_test.dart test/content_moderation_scope_test.dart test/moderation_submission_coordinator_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Run static analysis**

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Check repository cleanliness and recent commits**

Run from the repository root:

```powershell
git diff --check
git status --short --branch
git log -4 --oneline
```

Expected: no uncommitted implementation changes and three focused commits after the design commit.
