# Mobile-Wide Consistency Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Phase 6 by routing all temporary mobile feedback through the shared white `AppFeedback` surface, preventing raw service and database exceptions from reaching users, and applying only proven low-risk consistency improvements.

**Architecture:** `AppFeedback` remains the single presentation Facade around Flutter snackbars. Feature pages keep their current workflows and map caught failures to safe, operation-specific text before calling the Facade; technical exception details remain available only through debug logging. A source-level regression contract enforces that no production presentation code constructs its own snackbar or interpolates caught exceptions into visible messages.

**Tech Stack:** Flutter/Dart, existing `AppFeedback`, `friendly_error.dart`, CyanZone design tokens, Flutter widget tests, and source-structure regression tests.

---

## Execution Constraints

- Work on `refactor/mobile-architecture-optimization` in the original CyanZone directory.
- Do not create a Git worktree and do not change branches during implementation.
- Run terminal commands from `apps/mobile` unless a step states otherwise.
- Follow red-green-refactor: observe the relevant regression fail before changing production code.
- Preserve all business rules, repository calls, navigation, database/API contracts, notification routing, message wording that is already safe, and existing Undo/Retry callbacks.
- Do not modify SQL, Supabase policies, Gemini moderation, Firebase delivery, the Administration Portal, or package dependencies.
- Do not mechanically replace raw colours, padding, radii, or opacity values.
- Do not add a shared component unless at least two current consumers have the same structure and behaviour.
- Do not perform physical-device testing in this phase; the user will run the combined Android test after the automated gate passes.

## Planned File Structure

- `core/widgets/app_feedback.dart`: the only production owner of `ScaffoldMessenger` and `SnackBar`, plus semantic success, warning, error, and action entry points.
- `core/errors/friendly_error.dart`: existing generic error mapping; unchanged unless a focused test proves a missing reusable mapping.
- Feature presentation files: keep workflow ownership and call only semantic feedback methods with safe text.
- `mobile_feedback_consistency_test.dart`: source-level contract against direct snackbars and visible raw exception interpolation.
- Existing widget and feature tests: retain functional and callback behaviour.

## Message Classification

Use these mappings consistently during migration:

| Situation | Facade entry point | Preserve text/behaviour |
| --- | --- | --- |
| Completed operation | `AppFeedback.showSuccess` | `Copied`, `Photo downloaded`, `Post sent.`, delete/pin confirmations |
| Caution or unavailable state | `AppFeedback.showWarning` | notification/post/comment unavailable, limits, permission guidance |
| Recoverable failure | `AppFeedback.showError` | network/media/action failure using safe text only |
| Existing Undo or Retry action | `AppFeedback.show` with `AppFeedbackAction` | same label, callback, and extended action duration |

---

### Task 1: Establish the Phase 6 structural regression gate

**Files:**

- Create: `apps/mobile/test/mobile_feedback_consistency_test.dart`
- Verify: `apps/mobile/lib/src/core/widgets/app_feedback.dart`
- Verify: `apps/mobile/lib/src/features/**/*.dart`

- [ ] **Step 1: Confirm the clean baseline**

Run from the repository root:

```powershell
git branch --show-current
git status --short
```

Then run from `apps/mobile`:

```powershell
flutter test test/app_feedback_test.dart test/chat_widgets_test.dart test/post_comment_test.dart --no-pub --reporter expanded
flutter analyze --no-pub
```

Expected: the refactor branch is active, only the approved plan/spec documentation is changed or Git is clean after its commit, the selected tests pass, and analysis reports no issues.

- [ ] **Step 2: Add the failing source-level contract**

Create `mobile_feedback_consistency_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/src';
const _feedbackFacade =
    'lib/src/core/widgets/app_feedback.dart';

Iterable<File> _productionDartFiles() => Directory(_sourceRoot)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

String _portablePath(File file) => file.path.replaceAll('\\', '/');

void main() {
  test('only AppFeedback constructs temporary message surfaces', () {
    final violations = <String>[];
    final directMessenger = RegExp(r'\bScaffoldMessenger\.of\s*\(');
    final directSnackBar = RegExp(r'\bSnackBar\s*\(');

    for (final file in _productionDartFiles()) {
      final path = _portablePath(file);
      if (path == _feedbackFacade) continue;
      final source = file.readAsStringSync();
      if (directMessenger.hasMatch(source) || directSnackBar.hasMatch(source)) {
        violations.add(path);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('visible failure messages do not interpolate caught exceptions', () {
    final violations = <String>[];
    final rawVisibleError = RegExp(
      r'''(?:Error:|Unable to [^'"\r\n]+:)\s*\$\{?(?:e|error|exception)\b''',
    );

    for (final file in _productionDartFiles()) {
      final source = file.readAsStringSync();
      if (rawVisibleError.hasMatch(source)) {
        violations.add(_portablePath(file));
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
```

- [ ] **Step 3: Observe the expected failure**

```powershell
flutter test test/mobile_feedback_consistency_test.dart --no-pub --reporter expanded
```

Expected: FAIL. The first contract lists the current direct snackbar files; the second lists shell, feed, report, profile, Check-In, family-link, or SOS presentation paths that still interpolate a caught exception.

- [ ] **Step 4: Commit the failing regression gate**

```powershell
git add apps/mobile/test/mobile_feedback_consistency_test.dart
git commit -m "test(mobile): guard shared feedback boundary"
```

---

### Task 2: Complete the semantic AppFeedback Facade

**Files:**

- Modify: `apps/mobile/test/app_feedback_test.dart`
- Modify: `apps/mobile/lib/src/core/widgets/app_feedback.dart`

- [ ] **Step 1: Add a failing warning-helper widget test**

Add to `app_feedback_test.dart`:

```dart
testWidgets('showWarning uses the shared warning presentation', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppFeedback.showWarning(
              context,
              'This item is no longer available.',
            ),
            child: const Text('Show'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Show'));
  await tester.pump();

  expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  expect(find.text('This item is no longer available.'), findsOneWidget);
  final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
  expect(snackBar.backgroundColor, AppColors.surface);
});
```

- [ ] **Step 2: Confirm the helper is absent**

```powershell
flutter test test/app_feedback_test.dart --no-pub --plain-name "showWarning uses the shared warning presentation"
```

Expected: FAIL to compile because `showWarning` does not exist yet.

- [ ] **Step 3: Add the smallest semantic wrapper**

Add beside `showSuccess` and `showError` in `app_feedback.dart`:

```dart
static void showWarning(BuildContext context, String message) {
  show(context, message: message, kind: AppFeedbackKind.warning);
}
```

Do not add a new visual implementation or dependency. `show` remains the only method that constructs the snackbar.

- [ ] **Step 4: Verify the Facade**

```powershell
dart format lib/src/core/widgets/app_feedback.dart test/app_feedback_test.dart
flutter test test/app_feedback_test.dart --no-pub --reporter expanded
```

Expected: all shared-feedback tests pass, including the existing action-duration and compact-screen tests.

- [ ] **Step 5: Commit the Facade extension**

```powershell
git add lib/src/core/widgets/app_feedback.dart test/app_feedback_test.dart
git commit -m "refactor(mobile): complete feedback facade"
```

---

### Task 3: Close every confirmed raw-error presentation leak

**Files:**

- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/feed_card.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/report_post_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`
- Modify or verify: related shell, feed, profile, and parent-child tests
- Verify: `apps/mobile/test/mobile_feedback_consistency_test.dart`

- [ ] **Step 1: Strengthen focused tests with safe user-facing messages**

Where an existing widget test injects a repository failure, assert that visible text contains the safe operation message and does not contain technical markers:

```dart
expect(find.textContaining('Please try again'), findsOneWidget);
expect(find.textContaining('PostgrestException'), findsNothing);
expect(find.textContaining('42703'), findsNothing);
```

Use the nearest existing test file for that workflow. Do not introduce a Supabase integration test merely to test presentation wording.

- [ ] **Step 2: Confirm at least one focused regression fails**

Run the affected focused test and the raw-error contract:

```powershell
flutter test test/feed_post_test.dart test/parent_supervision_flows_test.dart --no-pub --reporter expanded
flutter test test/mobile_feedback_consistency_test.dart --no-pub --plain-name "visible failure messages do not interpolate caught exceptions"
```

Expected: FAIL until raw exception interpolation is removed.

- [ ] **Step 3: Map failures before they reach visible widgets**

Use safe operation-specific messages:

```dart
AppFeedback.showError(
  context,
  'Unable to update follow status. Please try again.',
);
```

Apply the following mappings:

- shell and profile follow failures: `Unable to update follow status. Please try again.`
- feed interaction failures: use `friendlyErrorMessage(error)` through `AppFeedback.showError` where available; never prefix it with raw error text
- report failure: `Unable to submit this report. Please try again.`
- Check-In failure: `Unable to send Check-In. Please try again.`
- family-link request failure: `Unable to send link request. Please try again.`
- SOS confirmation failure stored in `_sendError`: `Unable to confirm SOS delivery. Please try again.`
- SOS acknowledge/resolve failure: `Unable to update SOS. Please try again.`

Keep technical diagnostics only inside assertions:

```dart
assert(() {
  debugPrint('Follow update failed: $error');
  return true;
}());
```

- [ ] **Step 4: Re-run safe-boundary tests and the targeted source scan**

```powershell
flutter test test/feed_post_test.dart test/parent_supervision_flows_test.dart test/profile_presentation_decomposition_test.dart --no-pub --reporter expanded
flutter test test/mobile_feedback_consistency_test.dart --no-pub --plain-name "visible failure messages do not interpolate caught exceptions"
rg -n 'Error: \$\{|Unable to .*\$(error|e)' lib/src -g '*.dart'
```

Expected: the raw-error contract passes; the first direct-feedback contract may still fail because later tasks have not migrated all snackbars. The `rg` command returns no visible interpolation matches; debug logging is allowed.

- [ ] **Step 5: Commit the safe error boundary**

```powershell
git add lib/src/features/shell/presentation/main_shell.dart lib/src/features/posts/presentation/feed_card.dart lib/src/features/posts/presentation/report_post_page.dart lib/src/features/profile/presentation/profile_page.dart lib/src/features/parent_child/presentation/check_in_page.dart lib/src/features/parent_child/presentation/link_candidates_page.dart lib/src/features/parent_child/presentation/sos_page.dart test/mobile_feedback_consistency_test.dart test/feed_post_test.dart test/parent_supervision_flows_test.dart test/profile_presentation_decomposition_test.dart
git commit -m "fix(mobile): hide internal errors from users"
```

---

### Task 4: Migrate shell, push, and simple chat feedback

**Files:**

- Modify: `apps/mobile/lib/src/features/notifications/presentation/push_destination_navigator.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_group_pages.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_section_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- Modify or verify: `apps/mobile/test/chat_widgets_test.dart`
- Verify: `apps/mobile/test/chat_presentation_decomposition_test.dart`

- [ ] **Step 1: Add a focused shared-surface assertion**

In `missing rejected post disables its link and appeal` in
`chat_widgets_test.dart`, assert the rendered temporary message uses the
Facade surface. Add the `app_design_tokens.dart` import and these assertions
after tapping the rejected-post link:

```dart
final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
expect(snackBar.behavior, SnackBarBehavior.floating);
expect(snackBar.backgroundColor, AppColors.surface);
```

Preserve the existing text assertion.

- [ ] **Step 2: Observe the current raw snackbar fail the assertion**

```powershell
flutter test test/chat_widgets_test.dart --no-pub --plain-name "missing rejected post disables its link and appeal"
```

Expected: FAIL because that path directly constructs the default snackbar.

- [ ] **Step 3: Replace direct construction with semantic calls**

Import `app_feedback.dart` in each affected library and apply these rules:

- `This notification is no longer available.` -> `AppFeedback.showWarning`
- known unavailable/deleted system records -> `AppFeedback.showWarning`
- `No internet connection` and operation failures -> `AppFeedback.showError`
- successful notification deletion or completed follow action -> `AppFeedback.showSuccess` only when a success message already exists
- create-group failures keep their current safe domain-specific mapping, but send the mapped `text` through `AppFeedback.showError`
- follow-required messages remain warning-level because they describe a rule, not a system failure

Representative replacement:

```dart
if (!context.mounted) return;
AppFeedback.showWarning(
  context,
  'This notification is no longer available.',
);
```

Do not move chat or notification logic into the Facade.

- [ ] **Step 4: Verify chat list/settings behaviour**

```powershell
dart format lib/src/features/notifications/presentation/push_destination_navigator.dart lib/src/features/chat/presentation/chat_details_page.dart lib/src/features/chat/presentation/chat_group_pages.dart lib/src/features/chat/presentation/chat_page.dart lib/src/features/chat/presentation/create_group_chat_page.dart lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/chat/presentation/notification_section_widgets.dart lib/src/features/chat/presentation/system_notification_detail_page.dart test/chat_widgets_test.dart
flutter test test/chat_widgets_test.dart test/chat_presentation_decomposition_test.dart test/push_notification_coordinator_test.dart --no-pub --reporter expanded
```

Expected: all selected tests pass; message text and navigation behaviour remain unchanged.

- [ ] **Step 5: Commit the simple chat migration**

```powershell
git add lib/src/features/notifications/presentation/push_destination_navigator.dart lib/src/features/chat/presentation test/chat_widgets_test.dart
git commit -m "refactor(mobile): standardize chat feedback"
```

---

### Task 5: Migrate chat-room and media feedback without losing actions

**Files:**

- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_message_media.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Verify: `apps/mobile/test/chat_realtime_lifecycle_test.dart`
- Verify: `apps/mobile/test/chat_refresh_coordinator_test.dart`

- [ ] **Step 1: Add an Undo action regression test**

Extend the nearest delete-for-me widget test so it taps `Undo` and verifies the existing restore callback still runs. Also assert the shared surface and six-second action duration:

```dart
final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
expect(snackBar.backgroundColor, AppColors.surface);
expect(snackBar.duration, const Duration(seconds: 6));
await tester.tap(find.text('Undo'));
await tester.pump();
expect(restoreCallCount, 1);
```

If the current test harness cannot reach the private delete action without extensive new setup, add the callback/duration coverage to `app_feedback_test.dart` and retain the structural contract for this page.

- [ ] **Step 2: Observe the selected regression fail before migration**

```powershell
flutter test test/chat_widgets_test.dart test/app_feedback_test.dart --no-pub --reporter expanded
```

Expected: the new shared-surface assertion fails on the direct chat-room snackbar, while existing chat tests continue to describe current behaviour.

- [ ] **Step 3: Migrate chat-room outcomes**

Use:

```dart
AppFeedback.show(
  context,
  message: isPlural
      ? 'Messages deleted for me'
      : 'Message deleted for me',
  kind: AppFeedbackKind.success,
  actions: [
    AppFeedbackAction(
      label: 'Undo',
      onPressed: () => _restoreDeletedForMe(messages),
    ),
  ],
);
```

Map remaining room messages as follows:

- mapped send relationship/membership/limit text -> warning; generic send failure -> error
- image-send relationship text -> warning; network failure -> error
- `Copied` -> success
- unavailable shared post -> warning
- delete-for-me with Undo -> success plus the same callback
- photo cleanup/network/restore failures -> error
- existing safe error classification through `error.toString()` may remain internal, but the exception string must never become the displayed text

- [ ] **Step 4: Migrate chat media outcomes**

- `Photo could not load` -> error
- photo permission guidance -> warning
- `Photo downloaded` -> success

Preserve permission navigation, download operations, and mounted checks.

- [ ] **Step 5: Verify room, media, and realtime regression suites**

```powershell
dart format lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_message_media.dart test/chat_widgets_test.dart
flutter test test/chat_widgets_test.dart test/chat_realtime_lifecycle_test.dart test/chat_refresh_coordinator_test.dart test/app_feedback_test.dart --no-pub --reporter expanded
```

Expected: all tests pass, including Undo/action coverage and realtime lifecycle behaviour.

- [ ] **Step 6: Commit the action-preserving migration**

```powershell
git add lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_message_media.dart test/chat_widgets_test.dart test/app_feedback_test.dart
git commit -m "refactor(mobile): preserve chat feedback actions"
```

---

### Task 6: Migrate all remaining post feedback

**Files:**

- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/filter_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/pending_moderation_retry_banner.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_comments.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_media.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_share_sheet.dart`
- Verify: `apps/mobile/lib/src/features/posts/presentation/post_feedback_snackbar.dart`
- Modify or verify: `apps/mobile/test/create_post_validation_test.dart`
- Modify or verify: `apps/mobile/test/pending_moderation_retry_banner_test.dart`
- Modify or verify: `apps/mobile/test/post_comment_test.dart`
- Modify or verify: `apps/mobile/test/post_detail_decomposition_test.dart`
- Modify or verify: `apps/mobile/test/feed_post_test.dart`

- [ ] **Step 1: Add focused assertions for post warning and action feedback**

Cover at least:

- create-post image limit uses the white warning surface;
- moderation retry retains the `Retry now` callback and action duration;
- comment deletion uses success feedback;
- share success uses the shared surface rather than its local custom snackbar.

Use existing test harnesses where possible. A representative assertion is:

```dart
final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
expect(snackBar.backgroundColor, AppColors.surface);
expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
```

- [ ] **Step 2: Confirm the new shared-surface assertions fail**

```powershell
flutter test test/create_post_validation_test.dart test/pending_moderation_retry_banner_test.dart test/post_comment_test.dart --no-pub --reporter expanded
```

Expected: at least one new assertion fails because its production path still constructs a snackbar directly.

- [ ] **Step 3: Migrate create, filter, and retry feedback**

- maximum-image validation -> warning
- picked-image or form failure -> error using the existing safe mapped message
- filter validation -> warning
- pending moderation failure -> `AppFeedback.show` with warning kind and the same `Retry now` action
- pending moderation success -> success

Do not change validation order, moderation calls, or retry-store state.

- [ ] **Step 4: Migrate post detail and comment feedback**

- unavailable/deleted comment or unavailable rejected/pending actions -> warning
- network and unexpected action failures -> error through `friendlyErrorMessage`
- comment submitted for moderation -> retain the existing neutral/warning message and any action
- comment deleted and pinned/unpinned -> success
- photo load failure -> error; permission guidance -> warning; photo downloaded -> success

Replace `_showNoInternetMessage` and `_showActionError` internals with `AppFeedback` calls rather than changing their callers:

```dart
void _showNoInternetMessage() {
  AppFeedback.showError(context, 'No internet connection');
}

void _showActionError(Object error) {
  AppFeedback.showError(context, friendlyErrorMessage(error));
}
```

- [ ] **Step 5: Remove the share sheet's local snackbar template**

Delete `_showShareSnackBar` and call the shared Facade directly:

```dart
AppFeedback.showSuccess(context, 'Post sent.');
```

Relationship-required text remains a warning; send/network failures remain errors. This removes duplicated background, margin, radius, and icon styling automatically. Do not alter recipient filtering or send behaviour.

- [ ] **Step 6: Verify all focused post suites**

```powershell
dart format lib/src/features/posts/presentation test/create_post_validation_test.dart test/pending_moderation_retry_banner_test.dart test/post_comment_test.dart test/feed_post_test.dart
flutter test test/create_post_validation_test.dart test/pending_moderation_retry_banner_test.dart test/post_comment_test.dart test/post_detail_decomposition_test.dart test/feed_post_test.dart test/app_feedback_test.dart --no-pub --reporter expanded
```

Expected: all selected post tests pass with unchanged validation, moderation, share-recipient, and interaction behaviour.

- [ ] **Step 7: Commit the post migration**

```powershell
git add lib/src/features/posts/presentation test/create_post_validation_test.dart test/pending_moderation_retry_banner_test.dart test/post_comment_test.dart test/feed_post_test.dart
git commit -m "refactor(mobile): standardize post feedback"
```

---

### Task 7: Run the final conservative token/reuse audit and automated gate

**Files:**

- Modify only if an exact semantic match is found: files touched in Tasks 2-6
- Modify: `apps/mobile/test/mobile_feedback_consistency_test.dart` only if the contract needs a false-positive correction that does not weaken its boundary
- Verify: all `apps/mobile/lib/src/**/*.dart`
- Verify: all `apps/mobile/test/**/*.dart`

- [ ] **Step 1: Prove direct temporary-message construction is gone**

```powershell
rg -n 'ScaffoldMessenger\.of|\bSnackBar\s*\(' lib/src -g '*.dart'
flutter test test/mobile_feedback_consistency_test.dart --no-pub --reporter expanded
```

Expected: `rg` reports only `lib/src/core/widgets/app_feedback.dart`; both structural tests pass.

- [ ] **Step 2: Audit exception boundaries without banning diagnostic classification**

```powershell
rg -n 'Error: \$\{|Unable to .*\$(error|e)|Text\([^\n]*(e|error)\.toString\(\)' lib/src -g '*.dart'
rg -n '(e|error|exception)\.toString\(\)' lib/src/features -g '*.dart'
```

Expected: the first command returns no user-visible raw interpolation. The second may report safe internal classification such as relationship-required checks; inspect every result and confirm it is not passed to `Text`, `AppFeedback`, a dialog, banner, or persistent error label.

- [ ] **Step 3: Perform the exact-match token and duplication review**

Review only files changed in this phase:

```powershell
git diff --name-only f0adf32..HEAD -- apps/mobile/lib/src
rg -n 'Color\(0x|EdgeInsets\.(all|symmetric|only)\(|BorderRadius\.circular\(' lib/src/features -g '*.dart'
```

For each value in a changed block:

1. replace it only if an existing `AppColors`, `AppSpacing`, `AppInsets`, or `AppRadii` token has the exact value and same semantic purpose;
2. leave media overlays, status colours, opacity variants, and component geometry local;
3. do not create a token for a single literal; and
4. do not extract another shared widget unless two current consumers match in structure, interaction, accessibility, and lifecycle.

The expected reuse outcome is that snackbar duplication has been consolidated into `AppFeedback`. No additional shared component is required unless the inspection proves a second genuine duplicate.

- [ ] **Step 4: Run focused architecture and presentation gates**

```powershell
flutter test test/app_feedback_test.dart test/mobile_feedback_consistency_test.dart test/chat_presentation_decomposition_test.dart test/post_detail_decomposition_test.dart test/parent_child_presentation_decomposition_test.dart test/profile_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: all architecture and consistency tests pass.

- [ ] **Step 5: Run the complete mobile automated gate**

```powershell
flutter test --no-pub
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test
```

Expected: the complete test suite passes, analysis reports no issues, and format exits successfully without changing files.

- [ ] **Step 6: Check Git quality and intended scope**

Run from the repository root:

```powershell
git diff --check
git status --short
git diff --stat
```

Expected: no whitespace errors, no unexpected SQL/Admin/dependency changes, and only Phase 6 mobile source/tests plus approved plan/spec files are present.

- [ ] **Step 7: Commit final audit corrections if needed**

If Step 3 or later verification required a correction:

```powershell
git add apps/mobile/lib apps/mobile/test
git commit -m "fix(mobile): close consistency audit gaps"
```

If no correction was needed, do not create an empty commit.

---

## Completion Handoff

Phase 6 is complete only when:

- the structural gate confirms `AppFeedback` is the only production snackbar owner;
- no visible message contains raw PostgreSQL, Supabase, Firebase, HTTP, storage, or Dart exception text;
- existing Undo/Retry callbacks and safe message meaning are preserved;
- focused and full mobile automated gates pass;
- formatting, analysis, and Git checks are clean; and
- physical-device verification is clearly left to the user's combined manual Android test.

After that manual test, the remaining work is final architecture/project documentation and the separately scoped Administration Portal performance audit.
