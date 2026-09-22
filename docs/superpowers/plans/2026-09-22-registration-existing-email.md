# Existing Registration Email Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep confirmed duplicate-email registrations on the form with an inline email error while allowing new and still-unverified registrations to continue to OTP.

**Architecture:** Preserve Supabase signup response metadata at the API adapter boundary, classify the confirmed-duplicate response in the authentication gateway, and carry a dedicated field error through `RegistrationController` to `AuthPage`. The existing unrelated tag-request SQL cleanup remains on this branch and receives a small contract test before it is committed.

**Tech Stack:** Flutter/Dart, Supabase Auth (`supabase_flutter`/GoTrue), Flutter widget tests, Dart unit tests, PostgreSQL migration text contracts.

---

## File structure

- `apps/mobile/lib/src/features/auth/data/supabase_auth_api.dart`: preserve session presence and identity count from the SDK response.
- `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart`: classify an empty identities list as a confirmed duplicate account.
- `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart`: add the domain failure reason used by presentation code.
- `apps/mobile/lib/src/features/auth/presentation/registration_controller.dart`: own and clear the server-side email field error.
- `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`: render the error under the registration email field and clear it on edit.
- `apps/mobile/test/features/auth/data/supabase_auth_gateway_test.dart`: cover duplicate and confirmation-required gateway outcomes.
- `apps/mobile/test/features/auth/presentation/registration_controller_test.dart`: cover controller state and pending-email behavior.
- `apps/mobile/test/features/auth/presentation/auth_page_test.dart`: cover inline placement, no OTP navigation, and clearing on edit.
- `supabase/tags.sql`: preserve the user-authored removal of the obsolete `tag_requests` workflow.
- `apps/mobile/test/tags_sql_migration_test.dart`: lock in the intended tag SQL cleanup.

### Task 1: Preserve and classify the Supabase signup response

**Files:**
- Modify: `apps/mobile/test/features/auth/data/supabase_auth_gateway_test.dart`
- Modify: `apps/mobile/lib/src/features/auth/data/supabase_auth_api.dart`
- Modify: `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart`
- Modify: `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart`

- [ ] **Step 1: Write the failing gateway tests**

Add a configurable signup response to `FakeSupabaseAuthApi` and add these tests:

```dart
test('confirmed duplicate registration maps to an email field failure',
    () async {
  api.signUpResponse = const SupabaseSignUpResponse(
    hasSession: false,
    identityCount: 0,
  );
  final gateway = SupabaseAuthGateway.fromApi(api);

  await expectLater(
    gateway.register(RegistrationRequest(
      name: 'Ming Jiang',
      email: 'ming@example.com',
      password: 'StrongPass12!',
      termsVersion: '1.0',
      privacyVersion: '1.0',
      consentAcceptedAt: DateTime.utc(2026, 9, 4, 9),
    )),
    throwsA(
      isA<AuthFailure>()
          .having(
            (error) => error.reason,
            'reason',
            AuthFailureReason.emailAlreadyRegistered,
          )
          .having(
            (error) => error.message,
            'message',
            'An account with this email already exists.',
          ),
    ),
  );
});

test('unverified registration still requires confirmation', () async {
  api.signUpResponse = const SupabaseSignUpResponse(
    hasSession: false,
    identityCount: 1,
  );
  final gateway = SupabaseAuthGateway.fromApi(api);

  final outcome = await gateway.register(RegistrationRequest(
    name: 'Ming Jiang',
    email: 'ming@example.com',
    password: 'StrongPass12!',
    termsVersion: '1.0',
    privacyVersion: '1.0',
    consentAcceptedAt: DateTime.utc(2026, 9, 4, 9),
  ));

  expect(outcome, RegistrationOutcome.confirmationRequired);
});
```

Replace the fake's `bool signUpHasSession` with:

```dart
SupabaseSignUpResponse signUpResponse = const SupabaseSignUpResponse(
  hasSession: false,
  identityCount: 1,
);
```

Replace its `signUp` implementation with:

```dart
@override
Future<SupabaseSignUpResponse> signUp({
  required String email,
  required String password,
  required Map<String, dynamic> data,
}) async {
  if (signUpError case final error?) throw error;
  signUpEmail = email;
  signUpPassword = password;
  signUpData = data;
  return signUpResponse;
}
```

- [ ] **Step 2: Run the gateway test and verify RED**

Run:

```powershell
flutter test test/features/auth/data/supabase_auth_gateway_test.dart
```

Expected: compilation fails because `SupabaseSignUpResponse` and `AuthFailureReason.emailAlreadyRegistered` do not exist yet.

- [ ] **Step 3: Add the minimal response model and classification**

In `supabase_auth_api.dart`, add:

```dart
final class SupabaseSignUpResponse {
  const SupabaseSignUpResponse({
    required this.hasSession,
    required this.identityCount,
  });

  final bool hasSession;
  final int? identityCount;
}
```

Change `SupabaseAuthApi.signUp` to return `Future<SupabaseSignUpResponse>`. In `GoTrueSupabaseAuthApi.signUp`, preserve the SDK response:

```dart
final response = await _auth.signUp(
  email: email,
  password: password,
  data: data,
);
return SupabaseSignUpResponse(
  hasSession: response.session != null,
  identityCount: response.user?.identities?.length,
);
```

Add the domain reason:

```dart
enum AuthFailureReason {
  emailAlreadyRegistered,
  emailNotConfirmed,
  invalidOtp,
  expiredOtp,
  rateLimited,
  network,
  other,
}
```

Then update `SupabaseAuthGateway.register`:

```dart
final response = await _guard(() => _api.signUp(
      email: request.email,
      password: request.password,
      data: {
        'name': request.name,
        'terms_version': request.termsVersion,
        'privacy_version': request.privacyVersion,
        'consent_accepted_at':
            request.consentAcceptedAt.toUtc().toIso8601String(),
      },
    ));

if (!response.hasSession && response.identityCount == 0) {
  throw const AuthFailure(
    'An account with this email already exists.',
    reason: AuthFailureReason.emailAlreadyRegistered,
  );
}

return response.hasSession
    ? RegistrationOutcome.signedIn
    : RegistrationOutcome.confirmationRequired;
```

- [ ] **Step 4: Run the gateway test and verify GREEN**

Run:

```powershell
flutter test test/features/auth/data/supabase_auth_gateway_test.dart
```

Expected: all gateway tests pass, including the confirmed duplicate and unverified cases.

- [ ] **Step 5: Commit the data/domain change**

```powershell
git add -- apps/mobile/lib/src/features/auth/data/supabase_auth_api.dart apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart apps/mobile/lib/src/features/auth/domain/auth_gateway.dart apps/mobile/test/features/auth/data/supabase_auth_gateway_test.dart
git commit -m "fix(auth): classify existing registration emails"
```

### Task 2: Keep duplicate-email state on the registration form

**Files:**
- Modify: `apps/mobile/test/features/auth/presentation/registration_controller_test.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/registration_controller.dart`

- [ ] **Step 1: Write the failing controller test**

```dart
test('confirmed duplicate stays editing with an email field error', () async {
  authGateway.registrationError = const AuthFailure(
    'An account with this email already exists.',
    reason: AuthFailureReason.emailAlreadyRegistered,
  );

  await controller.register(request);

  expect(controller.state.phase, RegistrationPhase.editing);
  expect(controller.state.pendingEmail, isNull);
  expect(controller.state.emailError,
      'An account with this email already exists.');
  expect(controller.state.message, isNull);
  expect(store.email, isNull);

  controller.clearEmailError();
  expect(controller.state.emailError, isNull);
});
```

- [ ] **Step 2: Run the controller test and verify RED**

Run:

```powershell
flutter test test/features/auth/presentation/registration_controller_test.dart
```

Expected: compilation fails because `RegistrationState.emailError` and `clearEmailError` do not exist.

- [ ] **Step 3: Add field-error state and duplicate handling**

Add `emailError` to `RegistrationState`, its constructor, and `copyWith` using the same `_unset` sentinel pattern as `message`:

```dart
const RegistrationState({
  this.phase = RegistrationPhase.editing,
  this.pendingEmail,
  this.resendSecondsRemaining = 0,
  this.message,
  this.emailError,
  this.isSuccessMessage = false,
});

final String? emailError;

RegistrationState copyWith({
  RegistrationPhase? phase,
  Object? pendingEmail = _unset,
  int? resendSecondsRemaining,
  Object? message = _unset,
  Object? emailError = _unset,
  bool? isSuccessMessage,
}) {
  return RegistrationState(
    phase: phase ?? this.phase,
    pendingEmail: identical(pendingEmail, _unset)
        ? this.pendingEmail
        : pendingEmail as String?,
    resendSecondsRemaining:
        resendSecondsRemaining ?? this.resendSecondsRemaining,
    message: identical(message, _unset) ? this.message : message as String?,
    emailError: identical(emailError, _unset)
        ? this.emailError
        : emailError as String?,
    isSuccessMessage: isSuccessMessage ?? this.isSuccessMessage,
  );
}
```

Clear `emailError` when submission starts:

```dart
_setState(_state.copyWith(
  phase: RegistrationPhase.submitting,
  message: null,
  emailError: null,
  isSuccessMessage: false,
));
```

In the `AuthFailure` catch block, route only `emailAlreadyRegistered` to the field:

```dart
final isDuplicate =
    error.reason == AuthFailureReason.emailAlreadyRegistered;
_setState(_state.copyWith(
  phase: RegistrationPhase.editing,
  message: isDuplicate ? null : error.message,
  emailError: isDuplicate ? error.message : null,
  isSuccessMessage: false,
));
```

Add:

```dart
void clearEmailError() {
  if (_state.emailError == null) return;
  _setState(_state.copyWith(emailError: null));
}
```

- [ ] **Step 4: Run the controller test and verify GREEN**

Run:

```powershell
flutter test test/features/auth/presentation/registration_controller_test.dart
```

Expected: all controller tests pass and no pending email is saved for a confirmed duplicate.

- [ ] **Step 5: Commit the controller change**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/registration_controller.dart apps/mobile/test/features/auth/presentation/registration_controller_test.dart
git commit -m "fix(auth): retain duplicate email errors on form"
```

### Task 3: Render and clear the inline email error

**Files:**
- Modify: `apps/mobile/test/features/auth/presentation/auth_page_test.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`

- [ ] **Step 1: Write the failing widget test**

Add a widget test that submits a valid registration while the fake gateway throws the duplicate failure:

```dart
testWidgets('confirmed duplicate shows inline email error and skips OTP',
    (tester) async {
  authGateway.registrationError = const AuthFailure(
    'An account with this email already exists.',
    reason: AuthFailureReason.emailAlreadyRegistered,
  );
  await pumpAuthPage(tester);

  await tester.tap(find.text('Create account'));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey('register-name-field')),
    'Ming Jiang',
  );
  final emailField = find.byKey(const ValueKey('register-email-field'));
  await tester.enterText(emailField, 'ming@example.com');
  await tester.enterText(
    find.byKey(const ValueKey('register-password-field')),
    'StrongPass12!',
  );
  await tester.enterText(
    find.byKey(const ValueKey('register-confirm-password-field')),
    'StrongPass12!',
  );
  final consent = find.byKey(const ValueKey('registration-consent-checkbox'));
  await tester.ensureVisible(consent);
  await tester.tap(consent);
  final submit = find.widgetWithText(FilledButton, 'Create account');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pump();

  const errorText = 'An account with this email already exists.';
  expect(
    find.descendant(of: emailField, matching: find.text(errorText)),
    findsOneWidget,
  );
  expect(find.text('Enter the 6-digit code'), findsNothing);
  expect(pendingStore.email, isNull);

  await tester.enterText(emailField, 'new@example.com');
  await tester.pump();
  expect(find.text(errorText), findsNothing);
});
```

- [ ] **Step 2: Run the widget test and verify RED**

Run:

```powershell
flutter test test/features/auth/presentation/auth_page_test.dart --plain-name "confirmed duplicate shows inline email error and skips OTP"
```

Expected: the error is not found under the email field because the page only renders general registration messages.

- [ ] **Step 3: Wire the controller field error into the email input**

Pass these new arguments to `_AuthPanel`:

```dart
emailError: _isRegistering ? _registrationState.emailError : null,
onEmailChanged: _registrationController.clearEmailError,
```

Add the matching constructor parameters and fields:

```dart
final String? emailError;
final VoidCallback onEmailChanged;
```

Update the email `TextFormField`:

```dart
forceErrorText: isRegistering ? emailError : null,
onChanged: isRegistering ? (_) => onEmailChanged() : null,
```

Keep the existing syntax validator unchanged so malformed addresses are still rejected before registration is submitted.

- [ ] **Step 4: Run the widget test and verify GREEN**

Run:

```powershell
flutter test test/features/auth/presentation/auth_page_test.dart
```

Expected: all authentication page tests pass; the duplicate error is inline, OTP is absent, and editing clears the error.

- [ ] **Step 5: Commit the presentation change**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/auth_page.dart apps/mobile/test/features/auth/presentation/auth_page_test.dart
git commit -m "fix(auth): show existing email error inline"
```

### Task 4: Cover the retained tag SQL cleanup and verify the branch

**Files:**
- Preserve: `supabase/tags.sql`
- Create: `apps/mobile/test/tags_sql_migration_test.dart`

- [ ] **Step 1: Add a contract test for the user-authored SQL cleanup**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tags SQL removes the obsolete tag request workflow', () {
    final sql = File('../../supabase/tags.sql').readAsStringSync();

    expect(sql, contains('drop table if exists public.tag_requests;'));
    expect(
      sql,
      isNot(contains('create table if not exists public.tag_requests')),
    );
    expect(sql, isNot(contains('on public.tag_requests')));
  });
}
```

- [ ] **Step 2: Run the SQL contract test**

Run:

```powershell
flutter test test/tags_sql_migration_test.dart
```

Expected: PASS against the preserved `supabase/tags.sql` cleanup.

- [ ] **Step 3: Format all changed Dart files**

Run:

```powershell
dart format lib/src/features/auth/data/supabase_auth_api.dart lib/src/features/auth/data/supabase_auth_gateway.dart lib/src/features/auth/domain/auth_gateway.dart lib/src/features/auth/presentation/registration_controller.dart lib/src/features/auth/presentation/auth_page.dart test/features/auth/data/supabase_auth_gateway_test.dart test/features/auth/presentation/registration_controller_test.dart test/features/auth/presentation/auth_page_test.dart test/tags_sql_migration_test.dart
```

Expected: formatter exits successfully.

- [ ] **Step 4: Run focused authentication and SQL tests**

Run:

```powershell
flutter test test/features/auth/data/supabase_auth_gateway_test.dart test/features/auth/presentation/registration_controller_test.dart test/features/auth/presentation/auth_page_test.dart test/tags_sql_migration_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 5: Run full static analysis and test suite**

Run:

```powershell
flutter analyze
flutter test
```

Expected: analysis reports no issues and all tests pass.

- [ ] **Step 6: Verify the final diff is scoped**

Run from the repository root:

```powershell
git diff --check
git status --short
git diff --stat origin/main...HEAD
git diff --stat
```

Expected: no whitespace errors; only the approved authentication files, tests, design/plan docs, and `supabase/tags.sql` are present.

- [ ] **Step 7: Commit the SQL cleanup and its contract test**

```powershell
git add -- supabase/tags.sql apps/mobile/test/tags_sql_migration_test.dart
git commit -m "chore(tags): remove obsolete tag request workflow"
```
