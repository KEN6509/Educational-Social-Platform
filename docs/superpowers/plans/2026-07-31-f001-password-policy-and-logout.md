# F001 Password Policy and Logout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete F001 logout/password-change conformance and enforce the approved strong-password policy for every newly created mobile or administrator password.

**Architecture:** Flutter uses one reusable password-policy utility from registration and password change, with injected authentication callbacks for deterministic widget tests. Express uses an equivalent server-side policy and a separately testable bootstrap schema. Mobile and React logout actions gain explicit confirmation UI; the Administration Portal uses a focused modal component without adding dependencies.

**Tech Stack:** Flutter/Dart, `flutter_test`, Supabase Flutter Auth, React/TypeScript/Tailwind, Node.js/Express, Zod, Node's built-in test runner through `tsx`.

---

## File structure

- Create `apps/mobile/lib/src/core/security/password_policy.dart`: reusable mobile password-rule evaluation and validation copy.
- Create `apps/mobile/test/password_policy_test.dart`: unit coverage for every mobile password rule.
- Modify `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`: apply the policy only during registration and update guidance.
- Modify `apps/mobile/test/widget_test.dart`: prove registration displays the strong-password validation.
- Modify `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`: current-password input, live checklist, reauthentication, and update sequencing.
- Create `apps/mobile/test/set_password_page_test.dart`: widget coverage for verification and password update behavior.
- Modify `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`: injected sign-out action and confirmation dialog.
- Modify `apps/mobile/test/settings_page_test.dart`: Cancel/confirm/failure logout coverage.
- Create `services/api/src/lib/passwordPolicy.ts`: server-side password policy.
- Create `services/api/src/routes/adminSchema.ts`: testable administrator bootstrap request schema.
- Create `services/api/src/lib/passwordPolicy.test.ts`: policy and bootstrap-schema tests.
- Modify `services/api/src/routes/admin.ts`: consume the validated schema.
- Modify `services/api/package.json`: add the Node/`tsx` test command.
- Create `apps/admin/src/components/AdminLogoutDialog.tsx`: styled confirmation modal.
- Modify `apps/admin/src/App.tsx`: modal state, confirmed sign-out, and failure feedback.
- Modify `Project_Overview.md`: F001 completion, password policy, UC004/F009 corrections, and Administration Portal priority.

### Task 1: Mobile password policy and registration

**Files:**
- Create: `apps/mobile/test/password_policy_test.dart`
- Create: `apps/mobile/lib/src/core/security/password_policy.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`
- Modify: `apps/mobile/test/widget_test.dart`

- [ ] **Step 1: Write failing password-policy unit tests**

```dart
import 'package:cyanzone_mobile/src/core/security/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires every strong-password category', () {
    expect(PasswordPolicy.evaluate('Short1.').isValid, isFalse);
    expect(PasswordPolicy.evaluate('lowercaseonly1.').hasUppercase, isFalse);
    expect(PasswordPolicy.evaluate('UPPERCASEONLY1.').hasLowercase, isFalse);
    expect(PasswordPolicy.evaluate('NoNumberHere.').hasNumber, isFalse);
    expect(PasswordPolicy.evaluate('NoSymbolHere1').hasSymbol, isFalse);
  });

  test('period and underscore are accepted symbols', () {
    expect(PasswordPolicy.evaluate('StrongPass12.').isValid, isTrue);
    expect(PasswordPolicy.evaluate('StrongPass12_').isValid, isTrue);
  });

  test('whitespace alone does not satisfy the symbol rule', () {
    expect(PasswordPolicy.evaluate('StrongPass12 ').hasSymbol, isFalse);
  });
}
```

- [ ] **Step 2: Run the unit test and verify failure**

Run:

```powershell
cd apps/mobile
flutter test test/password_policy_test.dart
```

Expected: compilation fails because `password_policy.dart` and
`PasswordPolicy` do not exist.

- [ ] **Step 3: Implement the reusable mobile policy**

```dart
class PasswordPolicyResult {
  const PasswordPolicyResult({
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
  });

  final bool hasMinimumLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;

  bool get isValid =>
      hasMinimumLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSymbol;
}

class PasswordPolicy {
  const PasswordPolicy._();

  static PasswordPolicyResult evaluate(String value) {
    return PasswordPolicyResult(
      hasMinimumLength: value.length >= 12,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(value),
      hasLowercase: RegExp(r'[a-z]').hasMatch(value),
      hasNumber: RegExp(r'[0-9]').hasMatch(value),
      hasSymbol: RegExp(r'[^A-Za-z0-9\s]').hasMatch(value),
    );
  }

  static String? validationError(String value) {
    if (evaluate(value).isValid) return null;
    return 'Use at least 12 characters with uppercase, lowercase, a number, and a symbol such as . or _.';
  }
}
```

- [ ] **Step 4: Apply it only to registration**

Import the policy in `auth_page.dart`. In the password validator, keep login
compatible with existing passwords and apply the new validator only when
`isRegistering` is true:

```dart
validator: (value) {
  final password = value ?? '';
  if (!isRegistering) {
    return password.isEmpty ? 'Enter your password.' : null;
  }
  return PasswordPolicy.validationError(password);
},
```

Change registration helper text to `Use 12+ characters with upper/lowercase, a number, and a symbol.`

- [ ] **Step 5: Add a registration widget assertion**

In `widget_test.dart`, switch to Create account, enter valid name/email, enter
`weakpassword` in both password fields, submit, and assert the full policy
message appears without making a network request.

- [ ] **Step 6: Run focused tests**

Run:

```powershell
flutter test test/password_policy_test.dart test/widget_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 7: Commit Task 1**

```powershell
git add -- apps/mobile/lib/src/core/security/password_policy.dart apps/mobile/lib/src/features/auth/presentation/auth_page.dart apps/mobile/test/password_policy_test.dart apps/mobile/test/widget_test.dart
git commit -m "feat: enforce strong mobile password policy"
```

### Task 2: Current-password verification and live checklist

**Files:**
- Create: `apps/mobile/test/set_password_page_test.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/set_password_page.dart`

- [ ] **Step 1: Write failing widget tests**

Construct `SetPasswordPage` with injectable current user identity,
reauthentication, and update callbacks. Cover:

```dart
testWidgets('shows current password above new password fields', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: SetPasswordPage(
      currentUserEmail: 'user@example.com',
      currentUserId: 'user-1',
      reauthenticate: (_, __) async => 'user-1',
      updatePassword: (_) async {},
    ),
  ));

  final currentY =
      tester.getTopLeft(find.byKey(const ValueKey('current-password-field'))).dy;
  final newY =
      tester.getTopLeft(find.byKey(const ValueKey('new-password-field'))).dy;
  expect(currentY, lessThan(newY));
});
```

Add tests proving:

- mismatched confirmation never calls reauthentication;
- an equal current/new password is rejected;
- a wrong verified user ID prevents update and shows the current-password error;
- a valid submission records `verify` before `update`;
- `StrongPass12.` and `StrongPass12_` satisfy the visible symbol rule.

- [ ] **Step 2: Run the tests and verify failure**

Run:

```powershell
flutter test test/set_password_page_test.dart
```

Expected: compilation fails because the injectable constructor arguments and
field keys do not exist.

- [ ] **Step 3: Add injectable authentication boundaries**

Define:

```dart
typedef PasswordReauthenticator = Future<String?> Function(
  String email,
  String currentPassword,
);
typedef PasswordUpdater = Future<void> Function(String newPassword);
```

Add optional constructor fields for `currentUserEmail`, `currentUserId`,
`reauthenticate`, and `updatePassword`. Default reauthentication calls
`signInWithPassword`; default update calls `updateUser`.

- [ ] **Step 4: Add the Current Password row and validation sequence**

Add a `_currentPasswordController` and dispose it. Place a keyed Current
Password field before the keyed New Password and Confirm New Password rows.
Validate in this order:

```dart
if (current.isEmpty || password.isEmpty || confirm.isEmpty) {
  _showMessage('Please fill in all three password fields.');
  return;
}
final policyError = PasswordPolicy.validationError(password);
if (policyError != null) {
  _showMessage(policyError);
  return;
}
if (password != confirm) {
  _showMessage('New passwords do not match.');
  return;
}
if (password == current) {
  _showMessage('Choose a new password that differs from your current password.');
  return;
}
```

Resolve the current email/user ID, call reauthentication, compare the returned
user ID, and only then call the updater.

- [ ] **Step 5: Add the live policy checklist**

Rebuild checklist rows on new-password changes using
`PasswordPolicy.evaluate`. Each row displays a neutral/passing icon and the
five approved rules, including `Contains a symbol such as . or _`.

- [ ] **Step 6: Run focused tests**

Run:

```powershell
flutter test test/password_policy_test.dart test/set_password_page_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 7: Commit Task 2**

```powershell
git add -- apps/mobile/lib/src/features/profile/presentation/set_password_page.dart apps/mobile/test/set_password_page_test.dart
git commit -m "feat: verify current password before update"
```

### Task 3: Mobile logout confirmation

**Files:**
- Modify: `apps/mobile/test/settings_page_test.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`

- [ ] **Step 1: Write failing Cancel and confirm tests**

Inject a `Future<void> Function()` sign-out callback. Tap Log out and assert:

```dart
expect(find.text('Log out?'), findsOneWidget);
await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
expect(signOutCalls, 0);
```

In the confirmation case, tap the destructive dialog action and assert
`signOutCalls == 1`. Add a failure test that throws and expects
`Could not log out. Please try again.`

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```powershell
flutter test test/settings_page_test.dart
```

Expected: tests fail because Settings immediately signs out and has no injected
callback or confirmation dialog.

- [ ] **Step 3: Implement confirmation and failure handling**

Add `SignOutAction`, a widget constructor field, `_isSigningOut`, and
`_confirmLogout`. Use `showDialog<bool>` with `Cancel` and a red `Log out`
action. Call injected/default Supabase sign-out only after confirmation.
Preserve navigation and show the friendly failure snackbar when needed.

- [ ] **Step 4: Run the focused test**

Run:

```powershell
flutter test test/settings_page_test.dart
```

Expected: all settings tests pass.

- [ ] **Step 5: Commit Task 3**

```powershell
git add -- apps/mobile/lib/src/features/profile/presentation/settings_page.dart apps/mobile/test/settings_page_test.dart
git commit -m "feat: confirm mobile logout"
```

### Task 4: Administrator bootstrap password policy

**Files:**
- Create: `services/api/src/lib/passwordPolicy.test.ts`
- Create: `services/api/src/lib/passwordPolicy.ts`
- Create: `services/api/src/routes/adminSchema.ts`
- Modify: `services/api/src/routes/admin.ts`
- Modify: `services/api/package.json`

- [ ] **Step 1: Write failing API tests**

Use `node:test` and `node:assert/strict` to verify each missing category fails,
`.` and `_` pass, and `bootstrapSchema.safeParse` rejects weak input.

```ts
import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluatePasswordPolicy } from './passwordPolicy.js';
import { bootstrapSchema } from '../routes/adminSchema.js';

test('period and underscore satisfy the symbol rule', () => {
  assert.equal(evaluatePasswordPolicy('StrongPass12.').isValid, true);
  assert.equal(evaluatePasswordPolicy('StrongPass12_').isValid, true);
});

test('bootstrap rejects a weak password', () => {
  const parsed = bootstrapSchema.safeParse({
    email: 'admin@example.com',
    password: 'weakpassword',
    name: 'Admin User',
  });
  assert.equal(parsed.success, false);
});
```

- [ ] **Step 2: Add and run the API test command**

Add:

```json
"test": "tsx --test src/lib/passwordPolicy.test.ts"
```

Run:

```powershell
cd services/api
node node_modules/tsx/dist/cli.mjs --test src/lib/passwordPolicy.test.ts
```

Expected: module-not-found failure for the policy/schema files.

- [ ] **Step 3: Implement policy and schema**

Implement the same five booleans as Flutter with
`/[^A-Za-z0-9\s]/`. Export `bootstrapSchema` from `adminSchema.ts` and attach
the policy error with Zod `superRefine`.

- [ ] **Step 4: Consume the schema from the route**

Remove the inline schema in `admin.ts` and import:

```ts
import { bootstrapSchema } from './adminSchema.js';
```

The existing `safeParse` gate remains before Supabase count/create operations.

- [ ] **Step 5: Run API tests and build**

Run:

```powershell
node node_modules/tsx/dist/cli.mjs --test src/lib/passwordPolicy.test.ts
node node_modules/typescript/bin/tsc
```

Expected: all API tests pass and TypeScript exits successfully.

- [ ] **Step 6: Commit Task 4**

```powershell
git add -- services/api/package.json services/api/src/lib/passwordPolicy.ts services/api/src/lib/passwordPolicy.test.ts services/api/src/routes/adminSchema.ts services/api/src/routes/admin.ts
git commit -m "feat: secure administrator bootstrap passwords"
```

### Task 5: Administration Portal logout confirmation

**Files:**
- Create: `apps/admin/src/components/AdminLogoutDialog.tsx`
- Modify: `apps/admin/src/App.tsx`

- [ ] **Step 1: Create the focused modal component**

The component accepts:

```ts
type AdminLogoutDialogProps = {
  isOpen: boolean;
  isSigningOut: boolean;
  error: string | null;
  onCancel: () => void;
  onConfirm: () => void;
};
```

When open, render a fixed backdrop and centered `role="dialog"` panel with
`aria-modal="true"`, Cancel, and destructive Sign out buttons. Disable both
actions while signing out and render the supplied error.

- [ ] **Step 2: Wire dashboard state and confirmed sign-out**

In `Dashboard`, add `isLogoutOpen`, `isSigningOut`, and `logoutError`. The
header button opens the dialog. Confirmation awaits `supabase.auth.signOut()`;
on error, keep the modal open and show `Could not sign out. Please try again.`

- [ ] **Step 3: Run the Administration Portal build**

Run:

```powershell
cd apps/admin
node node_modules/typescript/bin/tsc -b
node node_modules/vite/bin/vite.js build
```

Expected: TypeScript and Vite production builds pass.

- [ ] **Step 4: Commit Task 5**

```powershell
git add -- apps/admin/src/App.tsx apps/admin/src/components/AdminLogoutDialog.tsx
git commit -m "feat: confirm administrator logout"
```

### Task 6: Documentation alignment

**Files:**
- Modify: `Project_Overview.md`

- [ ] **Step 1: Update F001 and password policy**

Mark F001 implemented only if mobile/admin confirmation and current-password
verification tests/builds pass. Record the five password rules and the three
new-password enforcement points.

- [ ] **Step 2: Correct UC004 and F009 boundaries**

Replace the one-tag mismatch with the approved one-to-five tag wording. State
that message-request SQL/repository foundations and the three-message cap
exist, but recipient acceptance UI and end-to-end verification remain pending.

- [ ] **Step 3: Reorder implementation priority**

Set Administration Portal completion as the next milestone. Keep F002, F006,
and AI moderation explicitly later rather than removing them.

- [ ] **Step 4: Validate and commit documentation**

Run:

```powershell
git diff --check -- Project_Overview.md
```

Expected: exit code 0, allowing only the repository's existing CRLF warning.

```powershell
git add -- Project_Overview.md
git commit -m "docs: align overview after F001 completion"
```

### Task 7: Full verification

**Files:**
- Verify all files changed by Tasks 1-6.

- [ ] **Step 1: Run the full Flutter suite**

```powershell
cd apps/mobile
flutter test
flutter analyze
```

Expected: all Flutter tests pass and analyzer reports no issues.

- [ ] **Step 2: Run API verification**

```powershell
cd services/api
node node_modules/tsx/dist/cli.mjs --test src/lib/passwordPolicy.test.ts
node node_modules/typescript/bin/tsc
```

Expected: all API tests and the build pass.

- [ ] **Step 3: Run Administration Portal verification**

```powershell
cd apps/admin
node node_modules/typescript/bin/tsc -b
node node_modules/vite/bin/vite.js build
```

Expected: both builds pass.

- [ ] **Step 4: Inspect final scope**

```powershell
git status --short
git diff --check HEAD
git log -8 --oneline
```

Expected: only intentional F001, password-policy, overview, design, and plan
changes/commits are present; no temporary files or unrelated modifications
exist.
