# Mobile Password Presentation Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Phase 5C by separating Change Password presentation from its authentication workflow and applying shared feedback and exact design tokens without changing the existing password flow.

**Architecture:** `SetPasswordPage` remains the stateful workflow coordinator for controllers, validation, Supabase authentication, and navigation. Stateless form components move into a feature-local Dart part file that receives values and callbacks and has no direct service dependency.

**Tech Stack:** Flutter/Dart, Supabase Flutter Auth, existing `PasswordPolicy`, `PasswordChecklist`, `AppFeedback`, and CyanZone design tokens.

---

## Execution Constraints

- Work on `refactor/mobile-architecture-optimization` in the original CyanZone directory.
- Do not create a Git worktree.
- Write and observe a failing regression before changing production code.
- Preserve all public constructors, injected authentication callbacks, validation order, message text, route behaviour, field keys, dimensions, and the 12px control radius.
- Do not modify Supabase configuration, SQL, APIs, the Administration Portal, or other mobile features.
- Do not add Riverpod or another dependency.
- Do not perform physical-device testing until the automated Phase 5C gate is complete.

## Planned File Structure

- `set_password_page.dart`: controllers, password-policy state, current session lookup, reauthentication, password update, error mapping, and navigation.
- `set_password_widgets.dart`: form body, labelled password input, guidance note, and submit button.
- `set_password_presentation_decomposition_test.dart`: ownership, dependency direction, feedback, and exact-token structural contracts.
- `set_password_page_test.dart`: user-visible validation, processing, failure, and success behaviour.

---

### Task 1: Establish the Phase 5C structural regression gate

**Files:**

- Create: `apps/mobile/test/set_password_presentation_decomposition_test.dart`
- Verify: `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`

- [ ] **Step 1: Confirm the baseline**

Run from `apps/mobile`:

```powershell
git branch --show-current
git status --short
flutter test test/set_password_page_test.dart test/password_policy_test.dart test/app_feedback_test.dart --no-pub --reporter expanded
flutter analyze --no-pub
```

Expected: the refactor branch is active, Git is clean, the selected tests pass, and analysis reports no issues.

- [ ] **Step 2: Add the failing ownership and consistency contract**

Create `set_password_presentation_decomposition_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _path = 'lib/src/features/profile/presentation';

String _read(String file) => File('$_path/$file').readAsStringSync();

void main() {
  test('Change Password delegates stateless presentation widgets', () {
    final page = _read('set_password_page.dart');
    final widgetsFile = File('$_path/set_password_widgets.dart');

    expect(page, contains("part 'set_password_widgets.dart';"));
    expect(widgetsFile.existsSync(), isTrue);

    final widgets = widgetsFile.readAsStringSync();
    expect(widgets, contains("part of 'set_password_page.dart';"));
    for (final className in [
      '_SetPasswordBody',
      '_PasswordInput',
      '_PasswordGuidance',
      '_PasswordSubmitButton',
    ]) {
      expect(widgets, contains('class $className'));
      expect(page, isNot(contains('class $className')));
    }
    expect(page, contains('class _SetPasswordPageState'));
    expect(page, contains('Future<void> _updatePassword()'));
    expect(page, contains('Future<String?> _defaultReauthenticate('));
    expect(page, contains('Future<void> _defaultUpdatePassword('));
  });

  test('Password presentation has no service or direct snackbar dependency', () {
    final page = _read('set_password_page.dart');
    final widgets = File('$_path/set_password_widgets.dart').existsSync()
        ? _read('set_password_widgets.dart')
        : '';

    expect(widgets, isNot(contains('Supabase.instance')));
    expect(widgets, isNot(contains('ScaffoldMessenger.of(')));
    expect(widgets, isNot(contains('SnackBar(')));
    expect(page, isNot(contains('ScaffoldMessenger.of(')));
    expect(page, isNot(contains('SnackBar(')));
  });

  test('Change Password uses shared tokens for exact existing values', () {
    final source = [
      _read('set_password_page.dart'),
      if (File('$_path/set_password_widgets.dart').existsSync())
        _read('set_password_widgets.dart'),
    ].join('\n');

    for (final rawValue in [
      'Color(0xFF0B1F3E)',
      'Color(0xFF64748B)',
      'Color(0xFF94A3B8)',
      'EdgeInsets.symmetric(horizontal: 20, vertical: 24)',
    ]) {
      expect(source, isNot(contains(rawValue)), reason: rawValue);
    }
  });
}
```

- [ ] **Step 3: Verify the expected failure**

```powershell
flutter test test/set_password_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL because the part file does not exist, the page directly constructs a snackbar, and exact reusable values remain raw.

- [ ] **Step 4: Commit the failing regression gate**

```powershell
git add apps/mobile/test/set_password_presentation_decomposition_test.dart
git commit -m "test(mobile): define password presentation boundary"
```

---

### Task 2: Route Change Password feedback through the shared facade

**Files:**

- Modify: `apps/mobile/test/set_password_page_test.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`

- [ ] **Step 1: Add a failing shared-feedback assertion**

Import the design tokens in `set_password_page_test.dart`:

```dart
import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
```

In `mismatched new passwords never reauthenticate`, add after the message assertion:

```dart
final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
expect(snackBar.behavior, SnackBarBehavior.floating);
expect(snackBar.backgroundColor, AppColors.surface);
expect(snackBar.shape, isA<RoundedRectangleBorder>());
```

- [ ] **Step 2: Verify the feedback test fails for the current raw snackbar**

```powershell
flutter test test/set_password_page_test.dart --no-pub --plain-name "mismatched new passwords never reauthenticate"
```

Expected: FAIL because the existing `SnackBar` has no floating behaviour and does not use the shared surface configuration.

- [ ] **Step 3: Use semantic shared feedback without changing message text**

Add:

```dart
import '../../../core/widgets/app_feedback.dart';
```

Replace `_showMessage` with:

```dart
void _showError(String message) {
  AppFeedback.showError(context, message);
}

void _showSuccess(String message) {
  AppFeedback.showSuccess(context, message);
}
```

Call `_showError` for empty fields, policy rejection, mismatch, unchanged password, expired session, incorrect password, authentication failure, and update failure. Call `_showSuccess('Password updated successfully')` only after the password update succeeds. Keep the current `mounted` checks and navigation order.

- [ ] **Step 4: Verify feedback and password behaviour**

```powershell
dart format lib/src/features/profile/presentation/set_password_page.dart test/set_password_page_test.dart
flutter test test/set_password_page_test.dart test/app_feedback_test.dart --no-pub --reporter expanded
```

Expected: all password and feedback tests pass.

- [ ] **Step 5: Commit shared feedback**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/set_password_page.dart apps/mobile/test/set_password_page_test.dart
git commit -m "refactor(mobile): standardize password feedback"
```

---

### Task 3: Extract Change Password presentation widgets

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/set_password_widgets.dart`
- Verify: `apps/mobile/test/set_password_presentation_decomposition_test.dart`

- [ ] **Step 1: Add the part boundary to the page library**

Add after the imports in `set_password_page.dart`:

```dart
part 'set_password_widgets.dart';
```

Create `set_password_widgets.dart` beginning with:

```dart
part of 'set_password_page.dart';
```

- [ ] **Step 2: Keep the stateful workflow in the page**

Replace only the current `SingleChildScrollView` body with:

```dart
body: _SetPasswordBody(
  currentPasswordController: _currentPasswordController,
  passwordController: _passwordController,
  confirmController: _confirmController,
  passwordStatus: _passwordStatus,
  isProcessing: _isProcessing,
  onPasswordChanged: (value) {
    setState(() {
      _passwordStatus = PasswordPolicy.evaluate(value);
    });
  },
  onSubmit: _updatePassword,
),
```

Keep `_SetPasswordPageState`, all controllers, `_passwordStatus`, `_isProcessing`, `_defaultReauthenticate`, `_defaultUpdatePassword`, and `_updatePassword` in the page file.

- [ ] **Step 3: Implement the immutable form body**

Add to `set_password_widgets.dart`:

```dart
class _SetPasswordBody extends StatelessWidget {
  const _SetPasswordBody({
    required this.currentPasswordController,
    required this.passwordController,
    required this.confirmController,
    required this.passwordStatus,
    required this.isProcessing,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final PasswordPolicyResult passwordStatus;
  final bool isProcessing;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.section,
        AppSpacing.page,
        AppSpacing.section,
      ),
      child: Column(
        children: [
          _PasswordInput(
            fieldKey: const ValueKey('current-password-field'),
            label: 'Current Password',
            controller: currentPasswordController,
            hint: 'Enter current password',
          ),
          const SizedBox(height: AppSpacing.lg),
          _PasswordInput(
            fieldKey: const ValueKey('new-password-field'),
            label: 'New Password',
            controller: passwordController,
            hint: 'Enter new password',
            onChanged: onPasswordChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PasswordInput(
            fieldKey: const ValueKey('confirm-password-field'),
            label: 'Confirm New Password',
            controller: confirmController,
            hint: 'Confirm new password',
          ),
          const SizedBox(height: AppSpacing.lg),
          PasswordChecklist(status: passwordStatus),
          const SizedBox(height: 10),
          const _PasswordGuidance(),
          const SizedBox(height: AppSpacing.lg),
          _PasswordSubmitButton(
            isProcessing: isProcessing,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Move the existing field, guidance, and action presentation**

Implement `_PasswordInput` with the existing field key, label, controller, hint,
obscure text, change callback, input decoration, font sizes, and spacing. Use
`AppColors.textSecondary` for the exact former `0xFF64748B` label colour:

```dart
class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: true,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
          decoration: appInputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
```

Implement `_PasswordGuidance` with the existing sentence, 12px font, 1.4
height, alignment, and padding. Use `AppColors.textMuted` for the exact former
`0xFF94A3B8` colour:

```dart
class _PasswordGuidance extends StatelessWidget {
  const _PasswordGuidance();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Your new password must be different from your current password.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
```

Implement `_PasswordSubmitButton` with the existing full width, 50px height, `ElevatedButton`, Done label, processing spinner, 12px radius, and disabled state. Use `AppColors.navy` for the exact former `0xFF0B1F3E` colour:

```dart
class _PasswordSubmitButton extends StatelessWidget {
  const _PasswordSubmitButton({
    required this.isProcessing,
    required this.onPressed,
  });

  final bool isProcessing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isProcessing ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.6),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify structural ownership and existing behaviour**

```powershell
dart format lib/src/features/profile/presentation/set_password_page.dart lib/src/features/profile/presentation/set_password_widgets.dart test/set_password_presentation_decomposition_test.dart
flutter test test/set_password_presentation_decomposition_test.dart test/set_password_page_test.dart test/password_policy_test.dart --no-pub --reporter expanded
```

Expected: the structural contract and all password behaviour tests pass.

- [ ] **Step 6: Commit the presentation extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/set_password_page.dart apps/mobile/lib/src/features/profile/presentation/set_password_widgets.dart apps/mobile/test/set_password_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract password presentation widgets"
```

---

### Task 4: Strengthen asynchronous password regressions

**Files:**

- Modify: `apps/mobile/test/set_password_page_test.dart`
- Verify: `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`

- [ ] **Step 1: Add update-failure rollback coverage**

Add:

```dart
testWidgets('failed password update keeps the page available', (tester) async {
  await pumpPage(
    tester,
    reauthenticate: (_, __) async => 'user-1',
    updatePassword: (_) async => throw StateError('offline'),
  );
  await enterPasswords(
    tester,
    current: 'OldPassword12.',
    password: 'StrongPass12_',
    confirm: 'StrongPass12_',
  );

  await submit(tester);

  expect(
    find.text('Could not update password. Please try again.'),
    findsOneWidget,
  );
  expect(find.text('Change Password'), findsOneWidget);
  expect(
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
    isNotNull,
  );
});
```

- [ ] **Step 2: Add duplicate-submission coverage**

Import `dart:async`, then add:

```dart
testWidgets('processing disables duplicate password submission', (tester) async {
  final verification = Completer<String?>();
  var reauthenticationCalls = 0;
  await pumpPage(
    tester,
    reauthenticate: (_, __) {
      reauthenticationCalls += 1;
      return verification.future;
    },
    updatePassword: (_) async {},
  );
  await enterPasswords(
    tester,
    current: 'OldPassword12.',
    password: 'StrongPass12_',
    confirm: 'StrongPass12_',
  );

  final done = find.widgetWithText(ElevatedButton, 'Done');
  await tester.ensureVisible(done);
  await tester.tap(done);
  await tester.pump();

  expect(reauthenticationCalls, 1);
  expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull);

  verification.complete('different-user');
  await tester.pumpAndSettle();
  expect(reauthenticationCalls, 1);
});
```

- [ ] **Step 3: Run the strengthened asynchronous suite**

```powershell
dart format test/set_password_page_test.dart
flutter test test/set_password_page_test.dart --no-pub --reporter expanded
```

Expected: all validation, reauthentication, update failure, success, checklist, and duplicate-submission tests pass.

- [ ] **Step 4: Commit asynchronous regressions**

```powershell
git add apps/mobile/test/set_password_page_test.dart
git commit -m "test(mobile): strengthen password update regressions"
```

---

### Task 5: Complete the Phase 5C verification gate

**Files:**

- Verify: all Phase 5C production and test files
- Modify only when a verified defect is found

- [ ] **Step 1: Run the related password and profile suite**

```powershell
flutter test test/set_password_presentation_decomposition_test.dart test/set_password_page_test.dart test/password_policy_test.dart test/settings_page_test.dart test/profile_presentation_decomposition_test.dart test/app_feedback_test.dart test/app_design_tokens_test.dart --no-pub --reporter expanded
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 2: Run the complete mobile suite**

```powershell
flutter test --no-pub --reporter compact
```

Expected: all mobile tests pass.

- [ ] **Step 3: Run analysis and strict formatting**

```powershell
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib/src/features/profile/presentation/set_password_page.dart lib/src/features/profile/presentation/set_password_widgets.dart test/set_password_presentation_decomposition_test.dart test/set_password_page_test.dart
```

Expected: analysis reports no issues and formatting reports zero changed files.

- [ ] **Step 4: Audit dependency direction and temporary feedback**

```powershell
rg -n "Supabase\.instance|ScaffoldMessenger\.of|SnackBar\(" lib/src/features/profile/presentation/set_password_widgets.dart
rg -n "ScaffoldMessenger\.of|SnackBar\(" lib/src/features/profile/presentation -g "*.dart"
git diff --check
git status --short
```

Expected: the presentation part has no matches; all profile presentation uses the shared feedback facade; Git has no whitespace errors; only intentional Phase 5C files are modified before the last commit.

- [ ] **Step 5: Correct only evidence-backed defects**

For any failure, first add a focused failing regression, observe the expected failure, apply the smallest correction, and rerun the focused and complete gates. Commit a correction only when files changed:

```powershell
git add apps/mobile
git commit -m "fix(mobile): close password presentation refactor gap"
```

- [ ] **Step 6: Record the deferred physical-device gate**

Do not claim Android device verification. After automated Phase 5C completion, the project owner will manually check validation messages, checklist updates, incorrect-current-password handling, successful password change, navigation, and visual consistency together with the rest of Phase 5.
