# Mobile Design System and Shell Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish CyanZone's shared mobile design tokens, reusable dialog and snackbar facades, and a consistently floating bottom navigation bar without changing feature behaviour.

**Architecture:** This is phase one of the approved incremental mobile refactor. Shared visual values live in `core/theme`, application-wide feedback components live in `core/widgets`, and the shell owns one extracted bottom-navigation component. Existing public helpers remain compatible while feature call sites migrate gradually.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test

---

## Scope

This plan implements only the shared UI foundation and main shell. Posts,
chat, parent-child, profile, and authentication decomposition will use separate
plans after this checkpoint passes.

Run every command from `apps/mobile` in the user's original CyanZone folder.
Do not create a Git worktree and do not modify the Administration Portal, API,
or Supabase files.

### Task 1: Add shared mobile design tokens

**Files:**
- Create: `apps/mobile/lib/src/core/theme/app_design_tokens.dart`
- Create: `apps/mobile/test/app_design_tokens_test.dart`

- [ ] **Step 1: Write the failing token contract test**

```dart
import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CyanZone colour tokens keep the approved palette', () {
    expect(AppColors.cyan.toARGB32(), 0xFF4490AD);
    expect(AppColors.navy.toARGB32(), 0xFF0B1F3E);
    expect(AppColors.background.toARGB32(), 0xFFFAFCFC);
    expect(AppColors.surface.toARGB32(), 0xFFFFFFFF);
    expect(AppColors.textPrimary.toARGB32(), 0xFF0F172A);
    expect(AppColors.textSecondary.toARGB32(), 0xFF64748B);
    expect(AppColors.error.toARGB32(), 0xFFE11D48);
  });

  test('spacing and floating navigation tokens keep the approved geometry', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 12);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.page, 20);
    expect(AppSpacing.section, 24);
    expect(AppSpacing.xl, 32);
    expect(AppInsets.page.horizontal, 40);
    expect(AppRadii.dialog, 22);
    expect(AppRadii.navigation, 28);
    expect(AppLayout.floatingNavigationHeight, 62);
    expect(AppLayout.floatingNavigationClearance, 86);
  });
}
```

- [ ] **Step 2: Run the test and verify it fails because the token file does not exist**

Run: `flutter test test/app_design_tokens_test.dart`

Expected: FAIL with an import or undefined-name error for
`app_design_tokens.dart`.

- [ ] **Step 3: Implement the shared token file**

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const cyan = Color(0xFF4490AD);
  static const navy = Color(0xFF0B1F3E);
  static const mint = Color(0xFF58E1B5);
  static const background = Color(0xFFFAFCFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFE11D48);
  static const disabled = Color(0xFFB9C9D1);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const page = 20.0;
  static const section = 24.0;
  static const xl = 32.0;
}

abstract final class AppInsets {
  static const page = EdgeInsets.symmetric(horizontal: AppSpacing.page);
  static const compact = EdgeInsets.all(AppSpacing.md);
  static const component = EdgeInsets.all(AppSpacing.lg);
  static const snackbar = EdgeInsets.fromLTRB(16, 0, 16, 18);
}

abstract final class AppRadii {
  static const compact = 14.0;
  static const control = 18.0;
  static const dialog = 22.0;
  static const navigation = 28.0;
}

abstract final class AppLayout {
  static const floatingNavigationHeight = 62.0;
  static const floatingNavigationOuterMargin = 12.0;
  static const floatingNavigationClearance = 86.0;
}
```

- [ ] **Step 4: Format and rerun the token test**

Run: `dart format lib/src/core/theme/app_design_tokens.dart test/app_design_tokens_test.dart`

Run: `flutter test test/app_design_tokens_test.dart`

Expected: PASS, 2 tests and 0 failures.

- [ ] **Step 5: Commit the token foundation**

```bash
git add apps/mobile/lib/src/core/theme/app_design_tokens.dart apps/mobile/test/app_design_tokens_test.dart
git commit -m "refactor(mobile): add shared design tokens"
```

### Task 2: Apply tokens through AppTheme

**Files:**
- Modify: `apps/mobile/lib/src/core/theme/app_theme.dart`
- Modify: `apps/mobile/test/app_design_tokens_test.dart`

- [ ] **Step 1: Add a failing theme contract test**

Append inside `main()`:

```dart
test('AppTheme exposes CyanZone semantic component styling', () {
  final theme = AppTheme.light;

  expect(theme.colorScheme.primary, AppColors.cyan);
  expect(theme.colorScheme.surface, AppColors.background);
  expect(theme.scaffoldBackgroundColor, AppColors.background);
  expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
  expect(theme.snackBarTheme.backgroundColor, AppColors.surface);
  expect(theme.dialogTheme.backgroundColor, AppColors.surface);
});
```

Add these imports:

```dart
import 'package:cyanzone_mobile/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
```

- [ ] **Step 2: Run the test and verify the new assertions fail**

Run: `flutter test test/app_design_tokens_test.dart`

Expected: FAIL because the current snackbar and dialog themes are not defined.

- [ ] **Step 3: Refactor AppTheme to use the shared tokens**

Replace raw shared values in `AppTheme.light` and add the component themes:

```dart
import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colourScheme = ColorScheme.fromSeed(
      seedColor: AppColors.cyan,
      primary: AppColors.cyan,
      secondary: AppColors.mint,
      surface: AppColors.background,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        elevation: 10,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.compact),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
    );
  }
}
```

- [ ] **Step 4: Format, analyze the theme, and run the token test**

Run: `dart format lib/src/core/theme/app_theme.dart test/app_design_tokens_test.dart`

Run: `flutter analyze lib/src/core/theme test/app_design_tokens_test.dart`

Run: `flutter test test/app_design_tokens_test.dart`

Expected: analysis exits with no issues and all token/theme tests pass.

- [ ] **Step 5: Commit the themed components**

```bash
git add apps/mobile/lib/src/core/theme/app_theme.dart apps/mobile/test/app_design_tokens_test.dart
git commit -m "refactor(mobile): centralize component theme"
```

### Task 3: Turn the confirmation dialog into the shared dialog facade

**Files:**
- Modify: `apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart`
- Modify: `apps/mobile/lib/src/features/notifications/presentation/push_permission_prompt.dart`
- Modify: `apps/mobile/test/app_confirmation_dialog_test.dart`
- Create: `apps/mobile/test/push_permission_prompt_test.dart`

- [ ] **Step 1: Write failing dialog variant and permission prompt tests**

Add a test that calls the new facade:

```dart
testWidgets('permission variant uses the shared dialog and cannot barrier dismiss',
    (tester) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showAppDialog(
              context: context,
              variant: AppDialogVariant.permission,
              icon: Icons.notifications_active_outlined,
              title: 'Stay updated on CyanZone',
              message: 'Enable phone notifications.',
              primaryLabel: 'Enable',
              secondaryLabel: 'Not now',
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.byType(AppConfirmationDialog), findsOneWidget);

  await tester.tapAt(const Offset(2, 2));
  await tester.pumpAndSettle();
  expect(find.byType(AppConfirmationDialog), findsOneWidget);

  await tester.tap(find.text('Not now'));
  await tester.pumpAndSettle();
  expect(result, isFalse);
});
```

Create `push_permission_prompt_test.dart` with a host button that awaits
`PushPermissionPrompt.show(context)`, then assert that
`AppConfirmationDialog`, `Stay updated on CyanZone`, `Enable`, and `Not now`
are visible and that tapping Enable returns true.

- [ ] **Step 2: Run both dialog tests and verify the new facade test fails**

Run: `flutter test test/app_confirmation_dialog_test.dart test/push_permission_prompt_test.dart`

Expected: FAIL because `AppDialogVariant` and `showAppDialog` do not exist and
the push prompt still builds an `AlertDialog`.

- [ ] **Step 3: Add the typed shared dialog facade**

Add this API above `showAppConfirmationDialog`:

```dart
enum AppDialogVariant { information, confirmation, destructive, permission }

Future<bool?> showAppDialog({
  required BuildContext context,
  required AppDialogVariant variant,
  required IconData icon,
  required String title,
  required String message,
  required String primaryLabel,
  String? secondaryLabel,
  Key? primaryKey,
  Key? secondaryKey,
}) {
  final destructive = variant == AppDialogVariant.destructive;
  final information = variant == AppDialogVariant.information;
  return showDialog<bool>(
    context: context,
    barrierDismissible: information,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => AppConfirmationDialog(
      icon: icon,
      iconColor: destructive ? AppColors.error : AppColors.cyan,
      iconBackgroundColor:
          destructive ? const Color(0xFFFFE4E6) : const Color(0xFFE7F4F8),
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: destructive ? AppColors.error : AppColors.navy,
      secondaryLabel: secondaryLabel,
      primaryKey: primaryKey,
      cancelKey: secondaryKey,
    ),
  );
}
```

Import `app_design_tokens.dart`. Change `secondaryLabel` in
`AppConfirmationDialog` from non-nullable to nullable. Render the secondary
button only when the label is non-null. Replace the primary and secondary
`GestureDetector` controls with these semantic controls:

```dart
SizedBox(
  width: double.infinity,
  height: 48,
  child: FilledButton(
    key: primaryKey,
    style: FilledButton.styleFrom(backgroundColor: primaryColor),
    onPressed: () => Navigator.of(context).pop(true),
    child: Text(primaryLabel),
  ),
),
if (secondaryLabel case final label?) ...[
  const SizedBox(height: 6),
  SizedBox(
    width: double.infinity,
    height: 42,
    child: TextButton(
      key: cancelKey,
      onPressed: () => Navigator.of(context).pop(false),
      child: Text(label),
    ),
  ),
],
```

Keep `showAppConfirmationDialog` as a compatibility facade for current call
sites, but set `barrierDismissible: false` and continue forwarding every
existing icon, colour, label, and key.

- [ ] **Step 4: Migrate PushPermissionPrompt to the shared facade**

Keep its public type and static method so callers do not change:

```dart
abstract final class PushPermissionPrompt {
  static Future<bool?> show(BuildContext context) {
    return showAppDialog(
      context: context,
      variant: AppDialogVariant.permission,
      icon: Icons.notifications_active_outlined,
      title: 'Stay updated on CyanZone',
      message:
          'Enable phone notifications for chat, activity, family safety, and other important updates. You can change this anytime in Settings.',
      primaryLabel: 'Enable',
      secondaryLabel: 'Not now',
    );
  }
}
```

- [ ] **Step 5: Format, analyze, and run the dialog tests**

Run: `dart format lib/src/core/widgets/app_confirmation_dialog.dart lib/src/features/notifications/presentation/push_permission_prompt.dart test/app_confirmation_dialog_test.dart test/push_permission_prompt_test.dart`

Run: `flutter analyze lib/src/core/widgets/app_confirmation_dialog.dart lib/src/features/notifications/presentation/push_permission_prompt.dart`

Run: `flutter test test/app_confirmation_dialog_test.dart test/push_permission_prompt_test.dart`

Expected: analysis succeeds and all dialog tests pass.

- [ ] **Step 6: Commit the shared dialog facade**

```bash
git add apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart apps/mobile/lib/src/features/notifications/presentation/push_permission_prompt.dart apps/mobile/test/app_confirmation_dialog_test.dart apps/mobile/test/push_permission_prompt_test.dart
git commit -m "refactor(mobile): unify application dialogs"
```

### Task 4: Add the shared snackbar facade and migrate the existing baseline

**Files:**
- Create: `apps/mobile/lib/src/core/widgets/app_feedback.dart`
- Create: `apps/mobile/test/app_feedback_test.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/post_feedback_snackbar.dart`
- Modify: `apps/mobile/lib/src/features/posts/presentation/create_post_page.dart`

- [ ] **Step 1: Write failing snackbar facade tests**

```dart
import 'package:cyanzone_mobile/src/core/theme/app_theme.dart';
import 'package:cyanzone_mobile/src/core/widgets/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the white floating error feedback surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppFeedback.showError(context, 'Unable to save'),
            child: const Text('Show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackbar.behavior, SnackBarBehavior.floating);
    expect(snackbar.backgroundColor, AppColors.surface);
    expect(snackbar.duration, const Duration(seconds: 4));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Unable to save'), findsOneWidget);
  });

  testWidgets('runs an action and uses the extended duration', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppFeedback.show(
              context,
              message: 'Moderation could not complete.',
              kind: AppFeedbackKind.warning,
              actions: [
                AppFeedbackAction(
                  label: 'Retry',
                  onPressed: () => retried = true,
                ),
              ],
            ),
            child: const Text('Show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackbar.duration, const Duration(seconds: 6));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
```

Import `app_design_tokens.dart` in this test.

- [ ] **Step 2: Run the test and verify it fails because the facade is absent**

Run: `flutter test test/app_feedback_test.dart`

Expected: FAIL with an import error for `app_feedback.dart`.

- [ ] **Step 3: Implement the typed feedback facade**

Create these public types and behaviour:

```dart
enum AppFeedbackKind { neutral, success, warning, error }

final class AppFeedbackAction {
  const AppFeedbackAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

abstract final class AppFeedback {
  static void show(
    BuildContext context, {
    required String message,
    AppFeedbackKind kind = AppFeedbackKind.neutral,
    List<AppFeedbackAction> actions = const [],
    bool showIcon = true,
  }) {
    assert(actions.length <= 2);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        elevation: 10,
        margin: AppInsets.snackbar,
        duration: Duration(seconds: actions.isEmpty ? 4 : 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.compact),
          side: const BorderSide(color: AppColors.border),
        ),
        content: Row(
          children: [
            if (showIcon) ...[
              Icon(_icon(kind), color: _colour(kind), size: 20),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final action in actions)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  action.onPressed();
                },
                child: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) => show(
        context,
        message: message,
        kind: AppFeedbackKind.success,
      );

  static void showError(BuildContext context, String message) => show(
        context,
        message: message,
        kind: AppFeedbackKind.error,
      );

  static IconData _icon(AppFeedbackKind kind) => switch (kind) {
        AppFeedbackKind.neutral => Icons.info_outline_rounded,
        AppFeedbackKind.success => Icons.check_circle_outline_rounded,
        AppFeedbackKind.warning => Icons.warning_amber_rounded,
        AppFeedbackKind.error => Icons.error_outline_rounded,
      };

  static Color _colour(AppFeedbackKind kind) => switch (kind) {
        AppFeedbackKind.neutral => AppColors.cyan,
        AppFeedbackKind.success => AppColors.success,
        AppFeedbackKind.warning => AppColors.warning,
        AppFeedbackKind.error => AppColors.error,
      };
}
```

Add the Material and token imports at the top of `app_feedback.dart`.

- [ ] **Step 4: Migrate the established post-feedback baseline**

Change `showDislikeFeedbackSnackBar` to call `AppFeedback.show` with
`showIcon: false` and two `AppFeedbackAction` values named Cancel and Report.
The callbacks remain unchanged.

Change the three private feedback methods in `create_post_page.dart` to:

```dart
void _showModerationMessage(String message) {
  AppFeedback.show(context, message: message);
}

void _showModerationRetry(String postId) {
  AppFeedback.show(
    context,
    message: 'Moderation could not complete.',
    kind: AppFeedbackKind.warning,
    actions: [
      AppFeedbackAction(
        label: 'Retry moderation',
        onPressed: () => _moderatePost(postId),
      ),
    ],
  );
}

void _showSubmissionError(String message) {
  AppFeedback.showError(context, message);
}
```

- [ ] **Step 5: Format, analyze, and run the feedback and create-post tests**

Run: `dart format lib/src/core/widgets/app_feedback.dart lib/src/features/posts/presentation/post_feedback_snackbar.dart lib/src/features/posts/presentation/create_post_page.dart test/app_feedback_test.dart`

Run: `flutter analyze lib/src/core/widgets/app_feedback.dart lib/src/features/posts/presentation/post_feedback_snackbar.dart lib/src/features/posts/presentation/create_post_page.dart`

Run: `flutter test test/app_feedback_test.dart test/create_post_validation_test.dart test/moderation_submission_coordinator_test.dart`

Expected: analysis succeeds and all selected tests pass. If
the command fails, correct the affected feedback integration before committing.

- [ ] **Step 6: Commit the feedback facade**

```bash
git add apps/mobile/lib/src/core/widgets/app_feedback.dart apps/mobile/lib/src/features/posts/presentation/post_feedback_snackbar.dart apps/mobile/lib/src/features/posts/presentation/create_post_page.dart apps/mobile/test/app_feedback_test.dart
git commit -m "refactor(mobile): unify snackbar feedback"
```

### Task 5: Extract the genuinely shared unread badge

**Files:**
- Create: `apps/mobile/lib/src/core/widgets/unread_badge.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`
- Create: `apps/mobile/test/unread_badge_test.dart`

- [ ] **Step 1: Move the existing badge contract into a focused test**

```dart
import 'package:cyanzone_mobile/src/core/widgets/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides zero and caps large unread counts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 0)));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 120)));
    expect(find.text('99+'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the focused test and verify the new import fails**

Run: `flutter test test/unread_badge_test.dart`

Expected: FAIL because `core/widgets/unread_badge.dart` does not exist.

- [ ] **Step 3: Move UnreadBadge without changing its behaviour**

Move `UnreadBadge` from `chat_widgets.dart` into
`core/widgets/unread_badge.dart` with this implementation:

```dart
import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.surface,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
```

Import the new file from `chat_widgets.dart` and `chat_page.dart`. Remove the
original duplicate class.

Update `chat_widgets_test.dart` to import the core badge file and remove only
the old badge test that is now in `unread_badge_test.dart`.

- [ ] **Step 4: Run focused badge and chat widget verification**

Run: `dart format lib/src/core/widgets/unread_badge.dart lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_page.dart test/chat_widgets_test.dart test/unread_badge_test.dart`

Run: `flutter analyze lib/src/core/widgets/unread_badge.dart lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_page.dart`

Run: `flutter test test/unread_badge_test.dart test/chat_widgets_test.dart`

Expected: analysis succeeds and both test files pass with zero failures.

- [ ] **Step 5: Commit the shared badge extraction**

```bash
git add apps/mobile/lib/src/core/widgets/unread_badge.dart apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/test/chat_widgets_test.dart apps/mobile/test/unread_badge_test.dart
git commit -m "refactor(mobile): extract shared unread badge"
```

### Task 6: Extract and float the bottom navigation

**Files:**
- Create: `apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart`
- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
- Create: `apps/mobile/test/cyanzone_bottom_navigation_test.dart`

- [ ] **Step 1: Write failing navigation component tests**

Test the component on a 320 by 640 surface and a 412 by 915 surface. The core
test body is:

```dart
Future<void> pumpNavigation(
  WidgetTester tester, {
  required Size size,
  EdgeInsets viewPadding = EdgeInsets.zero,
  ValueChanged<int>? onTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, viewPadding: viewPadding),
        child: Scaffold(
          extendBody: true,
          body: const ColoredBox(color: AppColors.mint),
          bottomNavigationBar: CyanZoneBottomNavigation(
            selectedIndex: 0,
            chatBadgeCount: 3,
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
}
```

Add these tests below the helper:

```dart
testWidgets('renders five destinations and routes the Chats index',
    (tester) async {
  int? selected;
  await pumpNavigation(
    tester,
    size: const Size(320, 640),
    onTap: (value) => selected = value,
  );

  expect(find.bySemanticsLabel('Home'), findsOneWidget);
  expect(find.bySemanticsLabel('Parent-Child'), findsOneWidget);
  expect(find.bySemanticsLabel('Create'), findsOneWidget);
  expect(find.bySemanticsLabel('Chats'), findsOneWidget);
  expect(find.bySemanticsLabel('Profile'), findsOneWidget);
  expect(find.text('3'), findsOneWidget);

  await tester.tap(find.bySemanticsLabel('Chats'));
  await tester.pump();
  expect(selected, 3);
});

testWidgets('adds the system bottom inset once', (tester) async {
  await pumpNavigation(
    tester,
    size: const Size(412, 915),
    viewPadding: const EdgeInsets.only(bottom: 24),
  );

  expect(
    tester.getSize(find.byType(CyanZoneBottomNavigation)).height,
    AppLayout.floatingNavigationClearance + 24,
  );
  final decorated = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(CyanZoneBottomNavigation),
      matching: find.byType(DecoratedBox),
    ).first,
  );
  final decoration = decorated.decoration as BoxDecoration;
  expect(decoration.borderRadius, BorderRadius.circular(AppRadii.navigation));
});
```

- [ ] **Step 2: Run the navigation test and verify the component import fails**

Run: `flutter test test/cyanzone_bottom_navigation_test.dart`

Expected: FAIL because the extracted component does not exist.

- [ ] **Step 3: Extract the navigation component**

Move `_CyanZoneNavBar`, `_CreateNavButton`, and `_NavButton` from
`main_shell.dart` into the new file. Rename the root to
`CyanZoneBottomNavigation`; keep the two button helpers private. Import
`AppColors`, `AppLayout`, `AppRadii`, `AppSpacing`, and the extracted
`UnreadBadge`.

Use this root layout so the page is visible around the pill and system insets
are added exactly once:

```dart
@override
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  return Padding(
    padding: EdgeInsets.fromLTRB(
      AppLayout.floatingNavigationOuterMargin,
      AppLayout.floatingNavigationOuterMargin,
      AppLayout.floatingNavigationOuterMargin,
      AppLayout.floatingNavigationOuterMargin + bottomInset,
    ),
    child: SizedBox(
      height: AppLayout.floatingNavigationHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.navigation),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180B1F3E),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _navigationButtons(),
          ),
        ),
      ),
    ),
  );
}
```

Implement `_navigationButtons()` as:

```dart
List<Widget> _navigationButtons() {
  return [
    _NavButton(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
      selected: selectedIndex == 0,
      onTap: () => onTap(0),
    ),
    _NavButton(
      icon: Icons.supervised_user_circle_outlined,
      selectedIcon: Icons.supervised_user_circle_rounded,
      label: 'Parent-Child',
      selected: selectedIndex == 1,
      onTap: () => onTap(1),
    ),
    _CreateNavButton(
      selected: selectedIndex == 2,
      onTap: () => onTap(2),
    ),
    _NavButton(
      icon: Icons.mode_comment_outlined,
      selectedIcon: Icons.mode_comment_rounded,
      label: 'Chats',
      selected: selectedIndex == 3,
      onTap: () => onTap(3),
      badgeCount: chatBadgeCount,
    ),
    _NavButton(
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle_rounded,
      label: 'Profile',
      selected: selectedIndex == 4,
      onTap: () => onTap(4),
    ),
  ];
}
```

Replace repeated navy, surface, muted surface, and inactive-text colours inside
the two button helpers with `AppColors` tokens. Preserve the current icons,
180-millisecond animation, dimensions, semantics, selected dot, and badge
position.

- [ ] **Step 4: Make MainShell extend behind the extracted bar**

Import the new component. Add this method to `_MainShellState`:

```dart
void _handleNavigationTap(int value) {
  if (value == _index) {
    if (value == 0) {
      _homeKey.currentState?.revealRefreshAndRefresh();
    } else if (value == 4) {
      setState(() => _profileRefreshSignal += 1);
    }
    return;
  }
  setState(() {
    _index = value;
    if (value == 4) {
      _profileRefreshSignal += 1;
    }
  });
  if (value == 3) {
    _refreshChatBadge();
  }
}
```

Add `extendBody: true` immediately after the existing `return Scaffold(`. Keep
the current app-bar and body blocks unchanged. Replace the complete current
`bottomNavigationBar: DecoratedBox(...)` value with:

```dart
bottomNavigationBar: CyanZoneBottomNavigation(
  selectedIndex: _index,
  onTap: _handleNavigationTap,
  chatBadgeCount: _chatBadgeCount,
),
```

Delete the three old private navigation widget classes from
`main_shell.dart`. Do not modify `_SearchPage` or other shell behaviour.

- [ ] **Step 5: Format, analyze, and run shell-focused tests**

Run: `dart format lib/src/features/shell/presentation/main_shell.dart lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart test/cyanzone_bottom_navigation_test.dart`

Run: `flutter analyze lib/src/features/shell/presentation/main_shell.dart lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart`

Run: `flutter test test/cyanzone_bottom_navigation_test.dart test/widget_test.dart`

Expected: analysis succeeds, both test files pass, all five taps retain their
existing indexes, and the shell Scaffold has `extendBody == true`.

- [ ] **Step 6: Commit the floating navigation**

```bash
git add apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart apps/mobile/test/cyanzone_bottom_navigation_test.dart
git commit -m "refactor(mobile): float bottom navigation"
```

### Task 7: Complete the phase-one checkpoint

**Files:**
- Modify only if verification exposes a phase-one regression in the files
  listed by Tasks 1-6.

- [ ] **Step 1: Run formatting and whitespace verification**

Run: `dart format lib/src/core/theme/app_design_tokens.dart lib/src/core/theme/app_theme.dart lib/src/core/widgets/app_confirmation_dialog.dart lib/src/core/widgets/app_feedback.dart lib/src/core/widgets/unread_badge.dart lib/src/features/notifications/presentation/push_permission_prompt.dart lib/src/features/posts/presentation/post_feedback_snackbar.dart lib/src/features/posts/presentation/create_post_page.dart lib/src/features/chat/presentation/chat_widgets.dart lib/src/features/chat/presentation/chat_page.dart lib/src/features/shell/presentation/main_shell.dart lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart test/app_design_tokens_test.dart test/app_confirmation_dialog_test.dart test/push_permission_prompt_test.dart test/app_feedback_test.dart test/unread_badge_test.dart test/chat_widgets_test.dart test/cyanzone_bottom_navigation_test.dart`

Run from the repository root: `git diff --check`

Expected: formatter completes and Git reports no whitespace errors.

- [ ] **Step 2: Run full static analysis**

Run: `flutter analyze`

Expected: exit code 0 with no analysis issues.

- [ ] **Step 3: Run the complete mobile test suite**

Run: `flutter test`

Expected: exit code 0 and zero failed tests.

- [ ] **Step 4: Perform the Android manual UI matrix**

On the available Android phone, verify:

- Home, Parent-Child, Create, Chats, and Profile all show the same floating
  white navigation pill;
- the page surface is visible around the pill;
- the last scrollable item and primary action remain reachable;
- the keyboard does not cover the Create action or chat input;
- the push permission prompt uses the shared dialog and Enable/Not now work;
- confirmation and destructive dialogs cannot be dismissed by tapping outside;
- neutral, warning, and error snackbars use the white surface and appear above
  the floating navigation; and
- tapping every navigation destination preserves current behaviour and badges.

- [ ] **Step 5: Record only unresolved evidence**

If a manual item cannot be tested, add one concise unchecked item under the
relevant section of `Project_Overview.md`. Do not mark the deferred two-account
FCM delivery test complete merely because the permission dialog works.

- [ ] **Step 6: Commit any verification-only correction**

If Step 1-4 required a correction, stage only the corrected phase-one files and
commit:

```bash
git commit -m "fix(mobile): close design system checkpoint gaps"
```

If no correction was required, do not create an empty commit.

## Phase-One Completion Gate

Do not begin the posts decomposition plan until `flutter analyze`, the complete
`flutter test` suite, and every available item in the Android manual matrix
pass. Any deferred manual item must be stated explicitly in the handoff.
