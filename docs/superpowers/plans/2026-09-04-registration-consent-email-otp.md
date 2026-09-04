# Registration Consent and Email OTP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require versioned Terms and Privacy consent for every new registration and activate accounts through an in-app Supabase email OTP flow.

**Architecture:** Extend the existing `AuthGateway` and `AppDependencies` boundaries. A focused registration controller owns explicit form/OTP operation state and the resend timer, while a `PendingRegistrationStore` remembers only the normalized email. Supabase remains the authentication authority; an idempotent SQL migration delays public profile creation until email confirmation and records consent metadata.

**Tech Stack:** Flutter, Dart, Supabase Flutter/Auth, SharedPreferences, PostgreSQL trigger functions and RLS, Flutter unit/widget tests.

---

## File Map

### Mobile files to create

- `apps/mobile/lib/src/features/auth/domain/registration_request.dart`: immutable registration and consent input.
- `apps/mobile/lib/src/features/auth/domain/pending_registration_store.dart`: local pending-email persistence contract.
- `apps/mobile/lib/src/features/auth/data/shared_preferences_pending_registration_store.dart`: SharedPreferences adapter.
- `apps/mobile/lib/src/features/auth/data/supabase_auth_api.dart`: narrow, fakeable wrapper around `GoTrueClient`.
- `apps/mobile/lib/src/features/auth/presentation/registration_controller.dart`: explicit registration/OTP state, recovery, and resend countdown.
- `apps/mobile/lib/src/features/auth/presentation/legal_policy.dart`: version constants and concise MVP document content.
- `apps/mobile/lib/src/features/auth/presentation/legal_document_page.dart`: reusable in-app legal document page.
- `apps/mobile/lib/src/features/auth/presentation/registration_consent_field.dart`: required checkbox and legal links.
- `apps/mobile/lib/src/features/auth/presentation/email_otp_panel.dart`: OTP entry, email display, resend countdown, and Back action.
- Matching focused tests under `apps/mobile/test/features/auth/`.

### Mobile files to modify

- `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart`
- `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart`
- `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`
- `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart`
- `apps/mobile/lib/src/app_dependencies.dart`
- `apps/mobile/lib/src/app.dart`
- `apps/mobile/test/support/fake_auth_gateway.dart`
- Existing auth and app tests affected by constructor or contract changes.

### Supabase and documentation files

- Create `supabase/registration_consent_otp.sql`: safe migration for the hosted project.
- Modify `supabase/schema.sql`: fresh-project consent columns and profile protections.
- Modify `supabase/auth.sql`: fresh-project confirmed-user profile triggers.
- Modify `supabase/README.md`: exact dashboard, SQL, and verification instructions.
- Modify `Project_Overview.md`: repository status and remaining live-verification boundary.

## Task 1: Define the registration domain contract

**Files:**
- Create: `apps/mobile/lib/src/features/auth/domain/registration_request.dart`
- Modify: `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart`
- Modify: `apps/mobile/test/features/auth/domain/auth_gateway_test.dart`
- Modify: `apps/mobile/test/support/fake_auth_gateway.dart`

- [ ] **Step 1: Write failing domain tests**

Add tests that require immutable consent data and typed authentication failures:

```dart
test('registration request preserves consent audit data', () {
  final acceptedAt = DateTime.utc(2026, 9, 4, 8, 30);
  final request = RegistrationRequest(
    name: 'Ming Jiang',
    email: 'ming@example.com',
    password: 'StrongPass12!',
    termsVersion: '1.0',
    privacyVersion: '1.0',
    consentAcceptedAt: acceptedAt,
  );

  expect(request.name, 'Ming Jiang');
  expect(request.email, 'ming@example.com');
  expect(request.termsVersion, '1.0');
  expect(request.privacyVersion, '1.0');
  expect(request.consentAcceptedAt, acceptedAt);
});

test('auth failure identifies an unconfirmed email', () {
  const failure = AuthFailure(
    'Verify your email before logging in.',
    reason: AuthFailureReason.emailNotConfirmed,
  );

  expect(failure.reason, AuthFailureReason.emailNotConfirmed);
});
```

- [ ] **Step 2: Run the domain test and verify that it fails**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth/domain/auth_gateway_test.dart
```

Expected: FAIL because `RegistrationRequest` and `AuthFailureReason` do not exist.

- [ ] **Step 3: Add the registration request**

Create `registration_request.dart`:

```dart
final class RegistrationRequest {
  const RegistrationRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.termsVersion,
    required this.privacyVersion,
    required this.consentAcceptedAt,
  });

  final String name;
  final String email;
  final String password;
  final String termsVersion;
  final String privacyVersion;
  final DateTime consentAcceptedAt;
}
```

- [ ] **Step 4: Extend the gateway without leaking Supabase types**

Replace the registration signature and add OTP operations in `auth_gateway.dart`:

```dart
import 'registration_request.dart';

enum RegistrationOutcome { signedIn, confirmationRequired }

enum AuthFailureReason {
  emailNotConfirmed,
  invalidOtp,
  expiredOtp,
  rateLimited,
  network,
  other,
}

final class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.reason = AuthFailureReason.other,
  });

  final String message;
  final AuthFailureReason reason;

  @override
  String toString() => message;
}

abstract interface class AuthGateway {
  bool get isSignedIn;
  Stream<bool> get signedInChanges;

  Future<void> signIn({required String email, required String password});

  Future<RegistrationOutcome> register(RegistrationRequest request);

  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  });

  Future<void> resendRegistrationOtp({required String email});
}
```

Update `FakeAuthGateway` to capture a `RegistrationRequest`, verification email/token, and resend email. Add independently configurable errors for all three operations.

```dart
RegistrationRequest? registrationRequest;
String? verificationEmail;
String? verificationToken;
String? resendEmail;
Object? verificationError;
Object? resendError;

@override
Future<RegistrationOutcome> register(RegistrationRequest request) async {
  if (registrationError case final error?) throw error;
  registrationRequest = request;
  return registrationOutcome;
}

@override
Future<void> verifyRegistrationOtp({
  required String email,
  required String token,
}) async {
  if (verificationError case final error?) throw error;
  verificationEmail = email;
  verificationToken = token;
}

@override
Future<void> resendRegistrationOtp({required String email}) async {
  if (resendError case final error?) throw error;
  resendEmail = email;
}
```

- [ ] **Step 5: Run and pass the domain test**

```powershell
dart format lib/src/features/auth/domain test/features/auth/domain test/support/fake_auth_gateway.dart
flutter test test/features/auth/domain/auth_gateway_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the domain contract**

```powershell
git add -- apps/mobile/lib/src/features/auth/domain apps/mobile/test/features/auth/domain apps/mobile/test/support/fake_auth_gateway.dart
git commit -m "feat: define registration otp contract"
```

## Task 2: Add pending registration persistence and dependency composition

**Files:**
- Create: `apps/mobile/lib/src/features/auth/domain/pending_registration_store.dart`
- Create: `apps/mobile/lib/src/features/auth/data/shared_preferences_pending_registration_store.dart`
- Create: `apps/mobile/test/features/auth/data/shared_preferences_pending_registration_store_test.dart`
- Modify: `apps/mobile/lib/src/app_dependencies.dart`
- Modify: `apps/mobile/lib/src/app.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart`
- Modify: `apps/mobile/test/widget_test.dart`
- Modify: `apps/mobile/test/features/auth/presentation/auth_gate_test.dart`
- Create: `apps/mobile/test/support/fake_pending_registration_store.dart`

- [ ] **Step 1: Write failing storage tests**

```dart
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves a normalized pending email', () async {
    final store = SharedPreferencesPendingRegistrationStore();
    await store.saveEmail('  USER@Example.COM  ');
    expect(await store.readEmail(), 'user@example.com');
  });

  test('clears a pending email', () async {
    final store = SharedPreferencesPendingRegistrationStore();
    await store.saveEmail('user@example.com');
    await store.clear();
    expect(await store.readEmail(), isNull);
  });
}
```

- [ ] **Step 2: Run the storage test and verify that it fails**

```powershell
flutter test test/features/auth/data/shared_preferences_pending_registration_store_test.dart
```

Expected: FAIL because the store files do not exist.

- [ ] **Step 3: Implement the store contract and adapter**

```dart
abstract interface class PendingRegistrationStore {
  Future<String?> readEmail();
  Future<void> saveEmail(String email);
  Future<void> clear();
}
```

```dart
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pending_registration_store.dart';

final class SharedPreferencesPendingRegistrationStore
    implements PendingRegistrationStore {
  static const _pendingEmailKey = 'auth.pending_registration_email';

  @override
  Future<String?> readEmail() async {
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_pendingEmailKey)?.trim().toLowerCase();
    return email == null || email.isEmpty ? null : email;
  }

  @override
  Future<void> saveEmail(String email) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingEmailKey,
      email.trim().toLowerCase(),
    );
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingEmailKey);
  }
}
```

Create a test fake whose `readEmail`, `saveEmail`, and `clear` methods mutate one nullable `email` field.

- [ ] **Step 4: Compose and pass the store through the app**

Make `AppDependencies` require both boundaries and construct the production store:

```dart
final class AppDependencies {
  const AppDependencies({
    required this.authGateway,
    required this.pendingRegistrationStore,
  });

  factory AppDependencies.production(SupabaseClient client) {
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
      pendingRegistrationStore: SharedPreferencesPendingRegistrationStore(),
    );
  }

  final AuthGateway authGateway;
  final PendingRegistrationStore pendingRegistrationStore;
}
```

Pass `pendingRegistrationStore` from `CyanZoneApp` to `AuthGate`, then from `AuthGate` to `AuthPage`. Update affected tests to inject `FakePendingRegistrationStore`.

- [ ] **Step 5: Run the focused storage and composition tests**

```powershell
dart format lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/features/auth test/support test/widget_test.dart
flutter test test/features/auth/data/shared_preferences_pending_registration_store_test.dart test/features/auth/presentation/auth_gate_test.dart test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit pending registration persistence**

```powershell
git add -- apps/mobile/lib/src/app.dart apps/mobile/lib/src/app_dependencies.dart apps/mobile/lib/src/features/auth apps/mobile/test/features/auth apps/mobile/test/support apps/mobile/test/widget_test.dart
git commit -m "feat: persist pending email verification"
```

## Task 3: Make the Supabase gateway testable and implement confirmed sessions

**Files:**
- Create: `apps/mobile/lib/src/features/auth/data/supabase_auth_api.dart`
- Modify: `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart`
- Modify: `apps/mobile/test/features/auth/data/supabase_auth_gateway_test.dart`

- [ ] **Step 1: Write failing adapter tests**

Use a small fake `SupabaseAuthApi` and add these behaviors:

```dart
test('register sends versioned consent metadata', () async {
  final api = FakeSupabaseAuthApi(signUpHasSession: false);
  final gateway = SupabaseAuthGateway.fromApi(api);
  final acceptedAt = DateTime.utc(2026, 9, 4, 9);

  final outcome = await gateway.register(RegistrationRequest(
    name: 'Ming Jiang',
    email: 'ming@example.com',
    password: 'StrongPass12!',
    termsVersion: '1.0',
    privacyVersion: '1.0',
    consentAcceptedAt: acceptedAt,
  ));

  expect(outcome, RegistrationOutcome.confirmationRequired);
  expect(api.signUpData, {
    'name': 'Ming Jiang',
    'terms_version': '1.0',
    'privacy_version': '1.0',
    'consent_accepted_at': '2026-09-04T09:00:00.000Z',
  });
});

test('verification and resend use signup OTP', () async {
  final api = FakeSupabaseAuthApi();
  final gateway = SupabaseAuthGateway.fromApi(api);

  await gateway.verifyRegistrationOtp(
    email: 'ming@example.com',
    token: '123456',
  );
  await gateway.resendRegistrationOtp(email: 'ming@example.com');

  expect(api.verifiedEmail, 'ming@example.com');
  expect(api.verifiedToken, '123456');
  expect(api.resentEmail, 'ming@example.com');
});

test('only confirmed sessions are signed in', () {
  final api = FakeSupabaseAuthApi(isConfirmedSession: false);
  final gateway = SupabaseAuthGateway.fromApi(api);
  expect(gateway.isSignedIn, isFalse);
});
```

Also test that Supabase `email_not_confirmed`, OTP expiry, rate-limit, and retryable network failures map to the matching `AuthFailureReason` and safe messages.

- [ ] **Step 2: Run the adapter test and verify that it fails**

```powershell
flutter test test/features/auth/data/supabase_auth_gateway_test.dart
```

Expected: FAIL because `SupabaseAuthApi`, OTP methods, and confirmed-session checks do not exist.

- [ ] **Step 3: Add the narrow Supabase Auth API**

Define this interface and production adapter in `supabase_auth_api.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SupabaseAuthApi {
  bool get hasConfirmedSession;
  Stream<bool> get confirmedSessionChanges;

  Future<void> signIn({required String email, required String password});

  Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  });

  Future<void> verifySignupOtp({
    required String email,
    required String token,
  });

  Future<void> resendSignupOtp({required String email});
}

final class GoTrueSupabaseAuthApi implements SupabaseAuthApi {
  GoTrueSupabaseAuthApi(this._auth);

  final GoTrueClient _auth;

  @override
  bool get hasConfirmedSession =>
      _auth.currentSession?.user.emailConfirmedAt != null;

  @override
  Stream<bool> get confirmedSessionChanges => _auth.onAuthStateChange.map(
        (state) => state.session?.user.emailConfirmedAt != null,
      );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: data,
    );
    return response.session != null;
  }

  @override
  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    await _auth.verifyOTP(email: email, token: token, type: OtpType.signup);
  }

  @override
  Future<void> resendSignupOtp({required String email}) async {
    await _auth.resend(email: email, type: OtpType.signup);
  }
}
```

- [ ] **Step 4: Implement the gateway mapping**

Give `SupabaseAuthGateway` a production factory and a test seam:

```dart
final class SupabaseAuthGateway implements AuthGateway {
  factory SupabaseAuthGateway(SupabaseClient client) {
    return SupabaseAuthGateway.fromApi(GoTrueSupabaseAuthApi(client.auth));
  }

  SupabaseAuthGateway.fromApi(this._api);

  final SupabaseAuthApi _api;
  late final Stream<bool> _signedInChanges =
      _api.confirmedSessionChanges.distinct();

  @override
  bool get isSignedIn => _api.hasConfirmedSession;

  @override
  Stream<bool> get signedInChanges => _signedInChanges;

  @override
  Future<void> signIn({required String email, required String password}) {
    return _guard(() => _api.signIn(email: email, password: password));
  }

  @override
  Future<RegistrationOutcome> register(RegistrationRequest request) async {
    final hasSession = await _guard(() => _api.signUp(
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
    return hasSession
        ? RegistrationOutcome.signedIn
        : RegistrationOutcome.confirmationRequired;
  }

  @override
  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  }) {
    return _guard(() => _api.verifySignupOtp(email: email, token: token));
  }

  @override
  Future<void> resendRegistrationOtp({required String email}) {
    return _guard(() => _api.resendSignupOtp(email: email));
  }
}
```

Implement `_guard` and `_mapAuthFailure` once. Prefer stable Supabase error codes, with a lowercase-message fallback for SDK/server variations. Never return raw internal stack details:

```dart
Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on AuthRetryableFetchException {
    throw const AuthFailure(
      'Unable to reach CyanZone. Check your connection and try again.',
      reason: AuthFailureReason.network,
    );
  } on AuthException catch (error) {
    throw _mapAuthFailure(error);
  }
}

AuthFailure _mapAuthFailure(AuthException error) {
  final code = (error.code ?? '').toLowerCase();
  final message = error.message.toLowerCase();

  if (code == 'email_not_confirmed' || message.contains('email not confirmed')) {
    return const AuthFailure(
      'Verify your email before logging in.',
      reason: AuthFailureReason.emailNotConfirmed,
    );
  }
  if (code.contains('otp_expired') || message.contains('expired')) {
    return const AuthFailure(
      'That verification code has expired. Request a new code.',
      reason: AuthFailureReason.expiredOtp,
    );
  }
  if (code.contains('rate_limit') || message.contains('rate limit')) {
    return const AuthFailure(
      'Please wait before requesting another verification code.',
      reason: AuthFailureReason.rateLimited,
    );
  }
  if (code.contains('otp') || message.contains('token')) {
    return const AuthFailure(
      'That verification code is not valid.',
      reason: AuthFailureReason.invalidOtp,
    );
  }
  return const AuthFailure(
    'Unable to complete authentication. Please try again.',
  );
}
```

- [ ] **Step 5: Run and pass gateway tests**

```powershell
dart format lib/src/features/auth/data test/features/auth/data
flutter test test/features/auth/data/supabase_auth_gateway_test.dart test/features/auth/domain/auth_gateway_test.dart
```

Expected: PASS, including the existing stable-stream regression.

- [ ] **Step 6: Commit the Supabase adapter**

```powershell
git add -- apps/mobile/lib/src/features/auth/data apps/mobile/test/features/auth/data
git commit -m "feat: add confirmed email otp gateway"
```

## Task 4: Implement the explicit registration controller

**Files:**
- Create: `apps/mobile/lib/src/features/auth/presentation/registration_controller.dart`
- Create: `apps/mobile/test/features/auth/presentation/registration_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

Cover these independent transitions:

```dart
test('confirmation-required registration saves email and awaits OTP', () async {
  authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;
  await controller.register(request);

  expect(store.email, 'ming@example.com');
  expect(controller.state.phase, RegistrationPhase.awaitingOtp);
  expect(controller.state.pendingEmail, 'ming@example.com');
  expect(controller.state.resendSecondsRemaining, 60);
});

test('restore resumes the OTP step without restoring secrets', () async {
  store.email = 'ming@example.com';
  await controller.restore();
  expect(controller.state.phase, RegistrationPhase.awaitingOtp);
  expect(controller.state.pendingEmail, 'ming@example.com');
});

test('back clears local pending email and returns to editing', () async {
  store.email = 'ming@example.com';
  await controller.restore();
  await controller.backToForm();
  expect(store.email, isNull);
  expect(controller.state.phase, RegistrationPhase.editing);
});
```

Also test successful verification clears storage, invalid OTP retains the step, resend cannot run before zero, successful resend restarts at 60, and `resumeUnconfirmedLogin` saves the login email.

- [ ] **Step 2: Run the controller test and verify that it fails**

```powershell
flutter test test/features/auth/presentation/registration_controller_test.dart
```

Expected: FAIL because the controller and states do not exist.

- [ ] **Step 3: Implement immutable state and controller operations**

Use these public types:

```dart
enum RegistrationPhase {
  editing,
  submitting,
  awaitingOtp,
  verifyingOtp,
  resendingOtp,
}

final class RegistrationState {
  const RegistrationState({
    this.phase = RegistrationPhase.editing,
    this.pendingEmail,
    this.resendSecondsRemaining = 0,
    this.message,
    this.isSuccessMessage = false,
  });

  final RegistrationPhase phase;
  final String? pendingEmail;
  final int resendSecondsRemaining;
  final String? message;
  final bool isSuccessMessage;

  bool get showsOtp => switch (phase) {
        RegistrationPhase.awaitingOtp ||
        RegistrationPhase.verifyingOtp ||
        RegistrationPhase.resendingOtp => true,
        _ => false,
      };

  bool get isBusy => switch (phase) {
        RegistrationPhase.submitting ||
        RegistrationPhase.verifyingOtp ||
        RegistrationPhase.resendingOtp => true,
        _ => false,
      };
}
```

`RegistrationController` extends `ChangeNotifier`, depends only on `AuthGateway` and `PendingRegistrationStore`, and owns one `Timer.periodic`. Use `_setState` to prevent notifications after disposal. Its public API is:

```dart
Future<void> restore();
Future<RegistrationOutcome?> register(RegistrationRequest request);
Future<void> verifyOtp(String token);
Future<void> resendOtp();
Future<void> resumeUnconfirmedLogin(String email);
Future<void> backToForm();
```

Rules inside those methods:

- Normalize emails with `trim().toLowerCase()`.
- Set busy state before awaiting a gateway call.
- Save the pending email before showing OTP.
- Start a 60-second periodic timer only after registration, restore, unconfirmed-login recovery, or successful resend.
- Do not call resend unless the remaining count is zero.
- Keep `pendingEmail` when verification/resend fails.
- Clear the store after successful verification or Back.
- Cancel the old timer before starting another and in `dispose()`.
- Map `AuthFailure.message` to state; use `Something went wrong. Please try again.` for unexpected errors.

- [ ] **Step 4: Run and pass the controller tests**

```powershell
dart format lib/src/features/auth/presentation/registration_controller.dart test/features/auth/presentation/registration_controller_test.dart
flutter test test/features/auth/presentation/registration_controller_test.dart
```

Expected: PASS without waiting 60 real seconds; use `fakeAsync` through Flutter test timing or pump the timer duration.

- [ ] **Step 5: Commit the registration state controller**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/registration_controller.dart apps/mobile/test/features/auth/presentation/registration_controller_test.dart
git commit -m "feat: coordinate registration otp state"
```

## Task 5: Add versioned in-app Terms and Privacy documents

**Files:**
- Create: `apps/mobile/lib/src/features/auth/presentation/legal_policy.dart`
- Create: `apps/mobile/lib/src/features/auth/presentation/legal_document_page.dart`
- Create: `apps/mobile/lib/src/features/auth/presentation/registration_consent_field.dart`
- Create: `apps/mobile/test/features/auth/presentation/legal_document_page_test.dart`
- Create: `apps/mobile/test/features/auth/presentation/registration_consent_field_test.dart`

- [ ] **Step 1: Write failing legal UI tests**

```dart
testWidgets('terms and privacy links open their matching documents',
    (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: RegistrationConsentField(
        value: false,
        showError: false,
        onChanged: (_) {},
      ),
    ),
  ));

  await tester.tap(find.text('Terms and Conditions'));
  await tester.pumpAndSettle();
  expect(find.text('Terms and Conditions', skipOffstage: false), findsWidgets);
  expect(find.text('Version 1.0'), findsOneWidget);

  await tester.pageBack();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Privacy Policy'));
  await tester.pumpAndSettle();
  expect(find.text('How we use information'), findsOneWidget);
});
```

Also verify that `showError: true` renders `Accept the Terms and Privacy Policy to continue.` and that changing the checkbox reports the new value.

- [ ] **Step 2: Run the legal UI tests and verify that they fail**

```powershell
flutter test test/features/auth/presentation/legal_document_page_test.dart test/features/auth/presentation/registration_consent_field_test.dart
```

Expected: FAIL because the legal presentation files do not exist.

- [ ] **Step 3: Define one source of truth for versions and content**

Use constants in `legal_policy.dart`:

```dart
abstract final class LegalPolicy {
  static const termsVersion = '1.0';
  static const privacyVersion = '1.0';
  static const effectiveDateLabel = '4 September 2026';
}

final class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}

const termsSections = <LegalSection>[
  LegalSection(
    'Using CyanZone',
    'Use CyanZone responsibly and provide accurate account information. '
        'Do not use the service to break the law, harm another person, '
        'impersonate someone, or interfere with the service.',
  ),
  LegalSection(
    'Your content',
    'You are responsible for the content you submit. CyanZone may review, '
        'limit, or remove content that is unsafe, unlawful, or against the '
        'platform rules.',
  ),
  LegalSection(
    'Parent supervision',
    'Parent supervision features work only after an account link is accepted. '
        'Linked parents may receive the supervision information described in '
        'the app.',
  ),
  LegalSection(
    'SOS and safety tools',
    'SOS and Check-In features are support tools. They do not replace local '
        'emergency services. Contact emergency services when immediate help '
        'is required.',
  ),
  LegalSection(
    'Account action',
    'CyanZone may restrict or suspend an account that seriously or repeatedly '
        'breaks these terms. You may request account deletion through the '
        'project administrator.',
  ),
  LegalSection(
    'Changes',
    'A future version may update these terms. CyanZone will identify the new '
        'version and effective date when another acceptance is required.',
  ),
];

const privacySections = <LegalSection>[
  LegalSection(
    'Information we collect',
    'CyanZone stores account and profile details, content and interactions, '
        'reports, notifications, and accepted parent-child links. It also '
        'records the policy versions and time accepted during registration.',
  ),
  LegalSection(
    'Location and supervision data',
    'Location is collected only when a user chooses Check-In or activates SOS '
        'and grants permission. Check-In stores one location. An active SOS '
        'may update location while CyanZone remains open. Linked parents can '
        'view the related supervision record.',
  ),
  LegalSection(
    'How we use information',
    'Information is used to provide accounts, social and learning features, '
        'parent supervision, safety tools, moderation, notifications, support, '
        'and service security.',
  ),
  LegalSection(
    'Service providers',
    'CyanZone uses required service providers such as Supabase to store data '
        'and operate authentication. Information is shared only as needed to '
        'operate these services or meet a legal requirement.',
  ),
  LegalSection(
    'Retention and security',
    'Information is kept while needed for the account, safety, moderation, or '
        'project records. Reasonable safeguards are used, but no online system '
        'can guarantee complete security.',
  ),
  LegalSection(
    'Your choices',
    'You may update supported profile information in the app. Requests to '
        'access, correct, or delete other account data can be made through the '
        'project administrator.',
  ),
];
```

Use these exact short sections for the MVP. They do not claim legal certification or guaranteed security.

- [ ] **Step 4: Implement the reusable document page and consent field**

`LegalDocumentPage` takes `title`, `version`, `effectiveDate`, and `List<LegalSection>`. Render a normal `Scaffold`, `AppBar`, padded `ListView`, document metadata, and semantic section headings.

`RegistrationConsentField` renders:

```dart
Checkbox(
  key: const ValueKey('registration-consent-checkbox'),
  value: value,
  onChanged: (next) => onChanged(next ?? false),
)
```

Place separate `TextButton` links for Terms and Privacy beside simple agreement copy. Open each document with `Navigator.of(context).push(MaterialPageRoute(...))`. Render the validation message below the row only when `showError` is true.

- [ ] **Step 5: Run and pass the legal UI tests**

```powershell
dart format lib/src/features/auth/presentation test/features/auth/presentation
flutter test test/features/auth/presentation/legal_document_page_test.dart test/features/auth/presentation/registration_consent_field_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit legal consent UI**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation apps/mobile/test/features/auth/presentation
git commit -m "feat: add registration legal consent"
```

## Task 6: Build the OTP panel and integrate the complete auth flow

**Files:**
- Create: `apps/mobile/lib/src/features/auth/presentation/email_otp_panel.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`
- Modify: `apps/mobile/test/features/auth/presentation/auth_page_test.dart`
- Modify: `apps/mobile/test/features/auth/presentation/auth_gate_test.dart`
- Modify: `apps/mobile/test/widget_test.dart`

- [ ] **Step 1: Replace the old confirmation-message test with failing flow tests**

Add focused widget tests for:

```dart
testWidgets('registration requires consent before calling the gateway',
    (tester) async {
  await enterValidRegistration(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pump();

  expect(authGateway.registrationRequest, isNull);
  expect(
    find.text('Accept the Terms and Privacy Policy to continue.'),
    findsOneWidget,
  );
});

testWidgets('confirmed registration opens OTP with the normalized email',
    (tester) async {
  authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;
  await enterValidRegistration(tester);
  await tester.tap(
    find.byKey(const ValueKey('registration-consent-checkbox')),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();

  expect(find.text('Verify your email'), findsOneWidget);
  expect(find.text('ming@example.com'), findsOneWidget);
  expect(authGateway.registrationRequest?.termsVersion, '1.0');
  expect(authGateway.registrationRequest?.privacyVersion, '1.0');
});
```

Add tests for six-digit numeric input, disabled incomplete verification, invalid/expired errors, resend after 60 seconds, Back preserving form text, restored pending email, successful verification clearing storage, and unconfirmed login entering OTP recovery.

- [ ] **Step 2: Run the auth page tests and verify that they fail**

```powershell
flutter test test/features/auth/presentation/auth_page_test.dart
```

Expected: FAIL because the current page only displays a generic confirmation message.

- [ ] **Step 3: Implement `EmailOtpPanel`**

The widget accepts the controller state plus `onTokenChanged`, `onVerify`, `onResend`, and `onBack`. Its field must use:

```dart
TextField(
  key: const ValueKey('registration-otp-field'),
  keyboardType: TextInputType.number,
  textInputAction: TextInputAction.done,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ],
  autofillHints: const [AutofillHints.oneTimeCode],
  onChanged: onTokenChanged,
  onSubmitted: token.length == 6 ? (_) => onVerify() : null,
)
```

Show one bottom `Verify Email` button. Under it, show either `Resend code in 60s` through `1s`, or an enabled `Resend code` action at zero. The Back action must be visible and labelled `Change email`.

- [ ] **Step 4: Integrate the controller into `AuthPage`**

Update the widget constructor:

```dart
const AuthPage({
  required this.authGateway,
  required this.pendingRegistrationStore,
  super.key,
});
```

In `initState`, construct and listen to `RegistrationController`, then call `restore()`. Dispose it with the text controllers. Keep `_isRegistering` only for login-versus-register mode; registration operation and OTP state come from the controller.

On registration submit:

```dart
if (!_hasAcceptedPolicies) {
  setState(() => _showConsentError = true);
  return;
}

await _registrationController.register(RegistrationRequest(
  name: _nameController.text.trim(),
  email: _emailController.text.trim().toLowerCase(),
  password: _passwordController.text,
  termsVersion: LegalPolicy.termsVersion,
  privacyVersion: LegalPolicy.privacyVersion,
  consentAcceptedAt: DateTime.now().toUtc(),
));
```

For login, catch `AuthFailureReason.emailNotConfirmed`, call `resumeUnconfirmedLogin(email)`, and do not show the generic login error.

When the controller reports `showsOtp`, render `EmailOtpPanel` in the existing centered auth shell instead of `_AuthPanel`. Back must call `backToForm()`, restore registration mode, leave the text controllers unchanged, and clear the OTP controller.

Do not persist the name, password, confirmation password, checkbox state, or OTP.

- [ ] **Step 5: Run all affected widget tests**

```powershell
dart format lib/src/features/auth/presentation test/features/auth/presentation test/widget_test.dart
flutter test test/features/auth/presentation/auth_page_test.dart test/features/auth/presentation/auth_gate_test.dart test/widget_test.dart
```

Expected: PASS. Timer tests must dispose the page/controller without pending-timer warnings.

- [ ] **Step 6: Commit the mobile registration flow**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation apps/mobile/test/features/auth/presentation apps/mobile/test/widget_test.dart
git commit -m "feat: add registration email otp flow"
```

## Task 7: Add the confirmed-profile and consent SQL migration

**Files:**
- Create: `supabase/registration_consent_otp.sql`
- Modify: `supabase/schema.sql`
- Modify: `supabase/auth.sql`

- [ ] **Step 1: Add the dedicated rerunnable migration**

`registration_consent_otp.sql` must perform these complete operations in order:

```sql
alter table public.profiles
  add column if not exists terms_version text,
  add column if not exists privacy_version text,
  add column if not exists consent_accepted_at timestamptz;

create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'authenticated'
    and (
      new.is_admin is distinct from old.is_admin
      or new.is_content_creator is distinct from old.is_content_creator
      or new.account_status is distinct from old.account_status
      or new.terms_version is distinct from old.terms_version
      or new.privacy_version is distinct from old.privacy_version
      or new.consent_accepted_at is distinct from old.consent_accepted_at
    )
  then
    raise exception 'Protected profile fields can only be changed by trusted server operations';
  end if;
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  insert into public.profiles (
    id,
    email,
    name,
    terms_version,
    privacy_version,
    consent_accepted_at
  )
  values (
    new.id,
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(new.email, '@', 1)
    ),
    nullif(trim(new.raw_user_meta_data ->> 'terms_version'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'privacy_version'), ''),
    nullif(
      trim(new.raw_user_meta_data ->> 'consent_accepted_at'),
      ''
    )::timestamptz
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(nullif(public.profiles.name, ''), excluded.name),
    terms_version = coalesce(
      public.profiles.terms_version,
      excluded.terms_version
    ),
    privacy_version = coalesce(
      public.profiles.privacy_version,
      excluded.privacy_version
    ),
    consent_accepted_at = coalesce(
      public.profiles.consent_accepted_at,
      excluded.consent_accepted_at
    ),
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed
after update of email_confirmed_at on auth.users
for each row
when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
execute function public.handle_new_user();
```

Add this `security definer` helper and use it in the profile Select policy. This defence hides any legacy unverified profile row without deleting it:

```sql
create or replace function public.is_profile_email_confirmed(profile_id uuid)
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1
    from auth.users
    where id = profile_id
      and email_confirmed_at is not null
  );
$$;

revoke all on function public.is_profile_email_confirmed(uuid) from public;
grant execute on function public.is_profile_email_confirmed(uuid)
  to authenticated, service_role;

drop policy if exists "Profiles are visible to signed-in users"
  on public.profiles;
create policy "Profiles are visible to signed-in users"
on public.profiles for select
to authenticated
using (public.is_profile_email_confirmed(id));
```

- [ ] **Step 2: Update fresh-project baseline SQL**

Add the three columns to the `profiles` definition in `schema.sql`, include them in `prevent_profile_privilege_escalation`, and use the confirmed-profile visibility helper/policy. Copy the same `handle_new_user` function and both auth triggers into `auth.sql`.

Do not delete existing Auth users or profile rows. Do not modify chat, parent supervision, or moderation SQL.

- [ ] **Step 3: Perform static SQL checks**

```powershell
rg -n "terms_version|privacy_version|consent_accepted_at|on_auth_user_email_confirmed|email_confirmed_at" supabase/schema.sql supabase/auth.sql supabase/registration_consent_otp.sql
```

Expected: all consent columns, confirmation checks, and both trigger paths appear in the baseline and dedicated migration.

```powershell
git diff --check -- supabase/schema.sql supabase/auth.sql supabase/registration_consent_otp.sql
```

Expected: no output.

- [ ] **Step 4: Commit the database contract**

```powershell
git add -- supabase/schema.sql supabase/auth.sql supabase/registration_consent_otp.sql
git commit -m "feat: provision profiles after email confirmation"
```

## Task 8: Document the hosted Supabase setup and project status

**Files:**
- Modify: `supabase/README.md`
- Modify: `Project_Overview.md`

- [ ] **Step 1: Replace the optional-confirmation instruction**

Document this exact hosted-project procedure in `supabase/README.md`:

1. Open the CyanZone project in Supabase Dashboard.
2. Open `Authentication` -> `Providers` -> `Email`.
3. Keep Email enabled, enable `Confirm Email`, and save.
4. Open `Authentication` -> `Email Templates` -> `Confirm signup`.
5. Set the subject to `Your CyanZone verification code`.
6. Replace the template body with:

```html
<h2>Verify your CyanZone email</h2>
<p>Enter this code in CyanZone to finish creating your account:</p>
<p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">
  {{ .Token }}
</p>
<p>If you did not create this account, you can ignore this email.</p>
```

7. Save the template.
8. Open `SQL Editor`, paste the complete `supabase/registration_consent_otp.sql`, and run it once.
9. Do not rerun `chat.sql` or `parent_supervision.sql` for this registration change.

Add verification queries for the three columns and two auth triggers:

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'terms_version',
    'privacy_version',
    'consent_accepted_at'
  )
order by column_name;

select trigger_name
from information_schema.triggers
where event_object_schema = 'auth'
  and event_object_table = 'users'
  and trigger_name in (
    'on_auth_user_created',
    'on_auth_user_email_confirmed'
  )
order by trigger_name;
```

Expected: three column rows and two trigger rows.

- [ ] **Step 2: Update `Project_Overview.md` accurately**

After repository tests pass:

- Record that the repository contains required consent, in-app legal pages, OTP verification/resend, pending-email recovery, confirmed-session gate, and deferred profile creation.
- Keep F002 marked **Partial** until the hosted Confirm Email setting, email template, migration, and live two-account verification are completed.
- Check repository implementation checklist items, but leave live inactive/unverified acceptance unchecked until the user supplies live evidence.
- Update the next-chat handoff to name `supabase/registration_consent_otp.sql` as the only new migration for this feature.
- Keep Gemini, FCM, the two-follower creator gate, and non-functional evidence as remaining work.

- [ ] **Step 3: Check documentation consistency**

```powershell
rg -n "optional for local demo|registration consent|email OTP|registration_consent_otp|Confirm Email" supabase/README.md Project_Overview.md docs/Future_Improvements.md
```

Expected: no instruction says email confirmation is optional; remaining-work statements agree with the actual repository/live status.

- [ ] **Step 4: Commit the setup documentation**

```powershell
git add -- supabase/README.md Project_Overview.md
git commit -m "docs: explain registration otp setup"
```

## Task 9: Run focused verification and prepare the manual handoff

**Files:**
- No production changes expected.
- Modify tests only if verification reveals a real defect, then repeat the relevant task's red-green cycle.

- [ ] **Step 1: Format the affected Dart files**

```powershell
dart format lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/features/auth test/support/fake_auth_gateway.dart test/support/fake_pending_registration_store.dart test/widget_test.dart
```

Expected: formatter completes without errors.

- [ ] **Step 2: Run only the related tests**

```powershell
flutter test test/features/auth test/widget_test.dart
```

Expected: all focused authentication and app-composition tests pass.

- [ ] **Step 3: Run scoped analysis**

```powershell
flutter analyze lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/features/auth test/support/fake_auth_gateway.dart test/support/fake_pending_registration_store.dart test/widget_test.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Verify the final diff and repository state**

From the repository root:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors. Only the user's pre-existing screenshot deletions may remain unstaged; no feature files should be accidentally uncommitted.

- [ ] **Step 5: Give the user the manual live-acceptance checklist**

After the user applies the dashboard and SQL steps, ask them to verify with two new email addresses:

- Registration cannot continue without consent.
- Terms and Privacy pages open and show version 1.0.
- The first email receives a six-digit OTP.
- A wrong OTP remains blocked.
- Resend becomes available after 60 seconds.
- Back permits correction to the second email.
- Restart restores the second email's OTP screen.
- Successful verification opens CyanZone.
- The verified profile contains all three consent values.
- The abandoned unverified Auth user has no visible profile.
- An unverified email/password login returns to OTP recovery instead of entering the app.

- [ ] **Step 6: Record verification evidence without overstating live status**

If local verification passes, add its command and result to `Project_Overview.md`. Do not mark hosted registration complete until the user confirms the dashboard configuration, migration result, real email delivery, and live activation behavior.

```powershell
git add -- Project_Overview.md
git commit -m "docs: record registration otp verification"
```
