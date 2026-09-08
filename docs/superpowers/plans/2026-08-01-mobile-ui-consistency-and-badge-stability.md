# Mobile UI Consistency and Badge Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Standardize every mobile confirmation dialog, align moderation badges across post-card types, stabilize the Messages unread badge, and share a live password checklist between registration and password change.

**Architecture:** Add two focused reusable widgets under `core/widgets`: one owns the approved confirmation-dialog presentation and one owns password-rule presentation. Existing screens retain their business operations and error handling, while `MainShell` stops treating tab selection or refresh failure as evidence of zero unread items and `FeedCard` positions text status relative to the whole card.

**Tech Stack:** Flutter/Dart, Supabase Flutter, Flutter widget tests, existing CyanZone theme and repositories.

---

## File Structure

### New files

- `apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart` — shared confirmation route helper and fixed Delete Post-style dialog widget.
- `apps/mobile/lib/src/core/widgets/password_checklist.dart` — shared live password-policy checklist.
- `apps/mobile/test/app_confirmation_dialog_test.dart` — shared-dialog behavior and all-screen migration invariant.

### Modified production files

- `apps/mobile/lib/src/core/security/password_policy.dart` — updated example copy only.
- `apps/mobile/lib/src/features/auth/presentation/auth_page.dart` — registration policy state and shared checklist.
- `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart` — use shared checklist.
- `apps/mobile/lib/src/features/profile/presentation/settings_page.dart` — shared logout confirmation.
- `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart` — shared post-update confirmation.
- `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart` — shared post-delete confirmation.
- `apps/mobile/lib/src/features/posts/presentation/feed_card.dart` — common top-left status placement.
- `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart` — shared message delete/unsend confirmation.
- `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart` — shared clear/exit confirmation.
- `apps/mobile/lib/src/features/chat/presentation/chat_group_pages.dart` — shared member-removal confirmation.
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart` — shared notification-delete confirmation.
- `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart` — shared notification-delete confirmation.
- `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart` — shared SOS confirmation.
- `apps/mobile/lib/src/features/shell/presentation/main_shell.dart` — preserve last-known badge state.

### Modified tests and documentation

- `apps/mobile/test/settings_page_test.dart`
- `apps/mobile/test/feed_card_test.dart`
- `apps/mobile/test/chat_repository_test.dart`
- `apps/mobile/test/password_policy_test.dart`
- `apps/mobile/test/set_password_page_test.dart`
- `apps/mobile/test/widget_test.dart`
- `Project_Overview.md`

---

### Task 1: Create the shared confirmation dialog

**Files:**
- Create: `apps/mobile/test/app_confirmation_dialog_test.dart`
- Create: `apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart`

- [ ] **Step 1: Write the failing shared-dialog widget tests**

Create tests that pump a button which awaits `showAppConfirmationDialog`, then assert the fixed structure and both results:

```dart
import 'package:cyanzone_mobile/src/core/widgets/app_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    ValueChanged<bool?> onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              onResult(await showAppConfirmationDialog(
                context: context,
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBackgroundColor: const Color(0xFFFEE2E2),
                title: 'Delete this item?',
                message: 'This action cannot be undone.',
                primaryLabel: 'Delete item',
                primaryColor: const Color(0xFFDC2626),
                primaryActionKey: const ValueKey('confirm-delete-item'),
              ));
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('uses the standard icon, message, primary, and cancel layout',
      (tester) async {
    bool? result;
    await openDialog(tester, (value) => result = value);

    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.text('Delete this item?'), findsOneWidget);
    expect(find.text('This action cannot be undone.'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-delete-item')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('returns true from the primary action', (tester) async {
    bool? result;
    await openDialog(tester, (value) => result = value);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-item')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run from `apps/mobile`:

```powershell
flutter test test/app_confirmation_dialog_test.dart --reporter compact
```

Expected: FAIL because `app_confirmation_dialog.dart`, `AppConfirmationDialog`, and `showAppConfirmationDialog` do not exist.

- [ ] **Step 3: Implement the minimal shared dialog**

Create a public helper and widget with the approved fixed layout:

```dart
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required Color iconBackgroundColor,
  required String title,
  required String message,
  required String primaryLabel,
  required Color primaryColor,
  Key? primaryActionKey,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => AppConfirmationDialog(
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: primaryColor,
      primaryActionKey: primaryActionKey,
    ),
  );
}
```

`AppConfirmationDialog.build` must reproduce the existing Delete Post geometry exactly: transparent `Dialog`, 28 horizontal inset, white 22-radius container, 58 circular icon, centered 20-point heavy title, centered 14-point message, 48-point full-width primary action, and 42-point full-width Cancel action below it. Both actions pop `true` or `false` respectively.

- [ ] **Step 4: Run the focused test and verify GREEN**

```powershell
flutter test test/app_confirmation_dialog_test.dart --reporter compact
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit the shared component**

```powershell
git add apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart apps/mobile/test/app_confirmation_dialog_test.dart
git commit -m "feat: add shared mobile confirmation dialog"
```

---

### Task 2: Migrate every existing mobile confirmation

**Files:**
- Modify: `apps/mobile/test/app_confirmation_dialog_test.dart`
- Modify: `apps/mobile/test/settings_page_test.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_group_pages.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/system_notification_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`

- [ ] **Step 1: Write a failing migration-invariant test**

Add a `dart:io` test that reads the ten presentation files and asserts none still contains `AlertDialog(` or a locally constructed confirmation `showDialog<bool>`:

```dart
test('all mobile confirmation surfaces use the shared dialog', () {
  const files = [
    'lib/src/features/profile/presentation/settings_page.dart',
    'lib/src/features/posts/presentation/create_post_page.dart',
    'lib/src/features/posts/presentation/post_detail_page.dart',
    'lib/src/features/chat/presentation/chat_room_page.dart',
    'lib/src/features/chat/presentation/chat_details_page.dart',
    'lib/src/features/chat/presentation/chat_group_pages.dart',
    'lib/src/features/chat/presentation/notification_sections_page.dart',
    'lib/src/features/chat/presentation/system_notification_detail_page.dart',
    'lib/src/features/parent_child/presentation/parent_child_page.dart',
  ];

  for (final path in files) {
    final source = File(path).readAsStringSync();
    expect(source, isNot(contains('AlertDialog(')), reason: path);
    expect(source, contains('showAppConfirmationDialog('), reason: path);
  }
});
```

Update logout tests to expect `AppConfirmationDialog` instead of `AlertDialog`, preserving the existing cancellation, one-call confirmation, and failure behavior assertions.

- [ ] **Step 2: Run the focused tests and verify RED**

```powershell
flutter test test/app_confirmation_dialog_test.dart test/settings_page_test.dart --reporter compact
```

Expected: FAIL because current screens still contain local dialogs and logout still pumps `AlertDialog`.

- [ ] **Step 3: Replace local dialogs with the shared helper**

Import `app_confirmation_dialog.dart` from each affected feature. Replace local dialog builders with calls shaped like:

```dart
return showAppConfirmationDialog(
  context: context,
  icon: icon,
  iconColor: const Color(0xFFDC2626),
  iconBackgroundColor: const Color(0xFFFEE2E2),
  title: title,
  message: message,
  primaryLabel: actionLabel,
  primaryColor: const Color(0xFFDC2626),
);
```

Use the existing action copy and these action-specific presentations:

- Logout: `Icons.logout_rounded`, red tone, `Log out`.
- Update post: `Icons.edit_note_rounded`, cyan icon surface, navy primary, `Update post`.
- Delete post: existing delete icon/colors/copy, `Delete post`.
- Delete-for-me: `Icons.delete_outline_rounded`, red tone, `Delete`.
- Unsend: `Icons.undo_rounded`, red tone, `Unsend`.
- Clear chat: `Icons.cleaning_services_rounded`, red tone, `Clear`.
- Exit group: `Icons.logout_rounded`, red tone, `Exit`.
- Remove member: `Icons.person_remove_rounded`, red tone, `Remove`.
- Delete notification: `Icons.delete_outline_rounded`, red tone, `Delete`, retaining `confirm-delete-system-notification` and `confirm-delete-system-detail` keys.
- SOS: `Icons.sos_rounded`, red tone, `Send SOS`.

Delete `_showPostDecisionDialog`, `_showEditConfirmation`'s duplicated layout, `_confirmMessageAction`'s local `AlertDialog`, `_confirmDangerAction`'s local `Dialog`, and the duplicated group-member dialog body after their callers use the shared helper. For SOS, await the boolean result first, then perform the existing repository call and snackbar outside the dialog.

- [ ] **Step 4: Run confirmation and existing chat/settings regressions**

```powershell
flutter test test/app_confirmation_dialog_test.dart test/settings_page_test.dart test/chat_widgets_test.dart --reporter compact
```

Expected: PASS; the shared migration invariant passes and existing destructive actions retain their confirmation behavior.

- [ ] **Step 5: Confirm no legacy confirmation layout remains**

```powershell
rg -n "AlertDialog\(|showDialog<bool>\(" lib/src/features
```

Expected: no feature-level confirmation builders; only non-confirmation modal surfaces may remain.

- [ ] **Step 6: Commit the migration**

```powershell
git add apps/mobile/lib/src apps/mobile/test/app_confirmation_dialog_test.dart apps/mobile/test/settings_page_test.dart
git commit -m "refactor: standardize mobile confirmations"
```

---

### Task 3: Share the live password checklist with registration

**Files:**
- Create: `apps/mobile/lib/src/core/widgets/password_checklist.dart`
- Modify: `apps/mobile/lib/src/core/security/password_policy.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`
- Modify: `apps/mobile/test/password_policy_test.dart`
- Modify: `apps/mobile/test/set_password_page_test.dart`
- Modify: `apps/mobile/test/widget_test.dart`

- [ ] **Step 1: Update tests first for the new shared behavior**

Change the expected validation message and checklist label to:

```dart
'Use at least 12 characters with uppercase, lowercase, a number, '
'and a symbol such as !, @, #, $, %, or &.'
```

and:

```dart
'Contains a symbol such as !, @, #, $, %, or &'
```

Add a registration widget test that switches to Create account mode, expects all five rules, enters `StrongPass12!`, and verifies the five completed `Icons.check_circle_rounded` icons. Keep the existing unit test proving `StrongPass12.` and `StrongPass12_` remain valid.

- [ ] **Step 2: Run password and auth tests and verify RED**

```powershell
flutter test test/password_policy_test.dart test/set_password_page_test.dart test/widget_test.dart --reporter compact
```

Expected: FAIL because the old example copy remains and registration has no live checklist.

- [ ] **Step 3: Create the shared checklist widget**

Move `_PasswordChecklist` and `_PasswordRule` from `set_password_page.dart` into `PasswordChecklist` and its private row widget in `core/widgets/password_checklist.dart`. Preserve the current container, border, spacing, completed green, incomplete grey, and icon behavior. Use the five approved labels exactly.

- [ ] **Step 4: Wire both password screens to the shared widget**

In Change Password, import the shared widget, replace `_PasswordChecklist(status: _passwordStatus)` with `PasswordChecklist(status: _passwordStatus)`, and delete the two local widget classes.

In `_AuthPageState`, add:

```dart
PasswordPolicyResult _passwordStatus = PasswordPolicy.evaluate('');
```

Reset it when switching modes and pass it plus an `onPasswordChanged` callback into `_AuthPanel`. In the registration password field, update state on every keystroke and insert:

```dart
if (isRegistering) ...[
  const SizedBox(height: 10),
  PasswordChecklist(status: passwordStatus),
],
```

Do not show the checklist in login mode.

- [ ] **Step 5: Update guidance without restricting symbols**

Change only `PasswordPolicy.validationMessage`. Keep this expression unchanged:

```dart
hasSymbol: RegExp(r'[^A-Za-z0-9\s]').hasMatch(value),
```

- [ ] **Step 6: Run focused password/auth tests and verify GREEN**

```powershell
flutter test test/password_policy_test.dart test/set_password_page_test.dart test/widget_test.dart --reporter compact
```

Expected: PASS, including live registration updates and period/underscore acceptance.

- [ ] **Step 7: Commit the password checklist change**

```powershell
git add apps/mobile/lib/src/core apps/mobile/lib/src/features/auth/presentation/auth_page.dart apps/mobile/lib/src/features/profile/presentation/set_password_page.dart apps/mobile/test/password_policy_test.dart apps/mobile/test/set_password_page_test.dart apps/mobile/test/widget_test.dart
git commit -m "feat: share live password checklist"
```

---

### Task 4: Align text-post status badges with image posts

**Files:**
- Modify: `apps/mobile/test/feed_card_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/feed_card.dart`

- [ ] **Step 1: Replace the old placement regression with a failing geometry test**

Pump a pending text-only post, measure the `FeedCard`, `Pending` pill, and title rectangles, then assert:

```dart
expect(badgeRect.left - cardRect.left, closeTo(8, 1));
expect(badgeRect.top - cardRect.top, closeTo(8, 1));
expect(badgeRect.overlaps(titleRect), isFalse);
```

Add the same left/top inset assertion for a pending image post so both card variants enforce one contract.

- [ ] **Step 2: Run the feed-card test and verify RED**

```powershell
flutter test test/feed_card_test.dart --reporter compact
```

Expected: FAIL because the text badge is currently positioned inside the content surface below the title.

- [ ] **Step 3: Move text status positioning to the complete card**

Wrap the text-only card's complete `Column` in a `Stack`. Place `_buildStatusBadge()` with `top: 8` and `left: 8`, matching `_buildImageCard`. When a status exists, add enough top padding before the title for the pill height plus spacing. Remove the status pill and minimum-height compensation from the inner `text_post_content_surface` stack. Preserve approved-card height and text truncation behavior.

- [ ] **Step 4: Run feed-card and waterfall tests and verify GREEN**

```powershell
flutter test test/feed_card_test.dart test/post_waterfall_layout_test.dart --reporter compact
```

Expected: PASS with no text overlap or waterfall estimate regression.

- [ ] **Step 5: Commit the badge alignment**

```powershell
git add apps/mobile/lib/src/features/posts/presentation/feed_card.dart apps/mobile/test/feed_card_test.dart
git commit -m "fix: align post status badges"
```

---

### Task 5: Preserve the Messages badge while entering the tab

**Files:**
- Modify: `apps/mobile/test/chat_repository_test.dart`
- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`

- [ ] **Step 1: Write the failing root-cause regression**

Extend the existing shell source regression to isolate the navigation callback and `_refreshChatBadge` method so the legitimate initial value of zero is not mistaken for the bug:

```dart
final navigationStart = shellSource.indexOf('onTap: (value)');
final navigationEnd = shellSource.indexOf(
  'chatBadgeCount: _chatBadgeCount',
  navigationStart,
);
final navigationSource = shellSource.substring(
  navigationStart,
  navigationEnd,
);
expect(navigationSource, isNot(contains('_chatBadgeCount = 0')));

final refreshStart = shellSource.indexOf('Future<void> _refreshChatBadge()');
final refreshEnd = shellSource.indexOf(
  'void _handleChatBadgeCountChanged',
  refreshStart,
);
final refreshSource = shellSource.substring(refreshStart, refreshEnd);
expect(
  refreshSource,
  isNot(contains('setState(() => _chatBadgeCount = 0)')),
);
```

Keep the existing assertion that `fetchUnreadChatTabBadgeCount` is the source of the combined badge.

- [ ] **Step 2: Run the chat repository regression and verify RED**

```powershell
flutter test test/chat_repository_test.dart --reporter compact
```

Expected: FAIL on both zero-reset assertions.

- [ ] **Step 3: Remove false zero transitions**

In `MainShell`:

- remove `_chatBadgeCount = 0` from the `value == 3` navigation branch;
- keep `_refreshChatBadge()` when Messages opens;
- change `_refreshChatBadge`'s catch block to preserve the current value and return without `setState`.

Successful loader results and `ChatPage.onBadgeCountChanged` remain the only badge mutations.

- [ ] **Step 4: Run chat badge and widget regressions and verify GREEN**

```powershell
flutter test test/chat_repository_test.dart test/chat_widgets_test.dart --reporter compact
```

Expected: PASS; opening Messages no longer creates a temporary zero count.

- [ ] **Step 5: Commit the badge-state fix**

```powershell
git add apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/test/chat_repository_test.dart
git commit -m "fix: preserve messages unread badge"
```

---

### Task 6: Format, verify, and update project truth

**Files:**
- Modify: `Project_Overview.md`
- Modify: any Dart files changed mechanically by formatting

- [ ] **Step 1: Format all changed Dart files**

Run from `apps/mobile` with the explicit changed-file list:

```powershell
dart format lib/src/core/widgets/app_confirmation_dialog.dart lib/src/core/widgets/password_checklist.dart lib/src/core/security/password_policy.dart lib/src/features/auth/presentation/auth_page.dart lib/src/features/profile/presentation/set_password_page.dart lib/src/features/profile/presentation/settings_page.dart lib/src/features/posts/presentation/create_post_page.dart lib/src/features/posts/presentation/post_detail_page.dart lib/src/features/posts/presentation/feed_card.dart lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/chat_details_page.dart lib/src/features/chat/presentation/chat_group_pages.dart lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/chat/presentation/system_notification_detail_page.dart lib/src/features/parent_child/presentation/parent_child_page.dart lib/src/features/shell/presentation/main_shell.dart test/app_confirmation_dialog_test.dart test/settings_page_test.dart test/feed_card_test.dart test/chat_repository_test.dart test/password_policy_test.dart test/set_password_page_test.dart test/widget_test.dart
```

Expected: formatter exits 0.

- [ ] **Step 2: Run the complete Flutter test suite**

```powershell
flutter test --reporter compact
```

Expected: all tests pass with zero failures. Record the actual test count rather than assuming the previous 184-test count.

- [ ] **Step 3: Run the Flutter analyzer**

```powershell
flutter analyze
```

Expected: `No issues found!` and exit code 0.

- [ ] **Step 4: Update the canonical handover**

Add concise implemented bullets under the mobile implementation and verification sections covering:

- shared mobile confirmation presentation;
- common top-left moderation badge placement;
- stable last-known Messages badge behavior;
- shared registration/change-password checklist and new example copy;
- the fresh test count and analyzer result from Steps 2–3.

- [ ] **Step 5: Verify the final diff**

```powershell
git diff --check --
git status --short
git diff --stat --
```

Expected: no whitespace errors; only planned mobile, test, documentation, spec, and plan files are changed or committed.

- [ ] **Step 6: Commit documentation and any final formatting**

```powershell
git add Project_Overview.md apps/mobile
git commit -m "docs: record mobile consistency refinements"
```

- [ ] **Step 7: Final post-commit verification**

```powershell
git status --short --branch
git log -6 --oneline
```

Expected: clean worktree and the planned task commits at the branch tip.
