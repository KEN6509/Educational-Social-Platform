# Feature-Enabling Architecture Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a narrow mobile composition root and application-owned authentication boundary without changing the current login or registration experience.

**Architecture:** Flutter presentation widgets will depend on an `AuthGateway` contract, while `SupabaseAuthGateway` adapts the Supabase SDK at the application boundary. `main.dart` creates production dependencies once and passes them through `CyanZoneApp`; widget tests inject a deterministic fake and no longer initialize the global Supabase singleton.

**Tech Stack:** Flutter, Dart, `supabase_flutter`, `flutter_test`

---

## Working Rules

- Work in the original `C:\Chan Ming Jiang\Degree\Sem 5\CyanZone` checkout on `feature/AI-Moderation`; do not create a worktree.
- Run Flutter and Dart commands with `C:\Chan Ming Jiang\Degree\Sem 5\CyanZone\apps\mobile` as the working directory.
- Run only the focused authentication tests plus scoped analysis, in line with the agreed verification scope.
- Do not stage or modify the five pre-existing deleted mobile screenshots.
- Do not introduce Riverpod, provider registries, consent/OTP UI, Gemini, or FCM in this foundation.

## File Structure

### New production files

- `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart` — application-owned authentication contract, registration outcome, and safe failure value.
- `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart` — Supabase Adapter implementing the application contract.
- `apps/mobile/lib/src/app_dependencies.dart` — small application composition facade that constructs production dependencies.

### Modified production files

- `apps/mobile/lib/src/features/auth/presentation/auth_page.dart` — submit through injected `AuthGateway`; no Supabase dependency.
- `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart` — observe injected signed-in state; no Supabase dependency.
- `apps/mobile/lib/src/app.dart` — receive `AppDependencies` and pass authentication into the gate.
- `apps/mobile/lib/main.dart` — construct production dependencies after Supabase initialization.

### New and modified test files

- `apps/mobile/test/features/auth/domain/auth_gateway_test.dart` — contract value test.
- `apps/mobile/test/support/fake_auth_gateway.dart` — shared deterministic fake for authentication widget tests.
- `apps/mobile/test/features/auth/presentation/auth_page_test.dart` — delegation, outcome, errors, and SDK-boundary tests.
- `apps/mobile/test/features/auth/presentation/auth_gate_test.dart` — initial and emitted auth-state behavior plus SDK-boundary test.
- `apps/mobile/test/app_dependencies_test.dart` — production factory wiring test.
- `apps/mobile/test/widget_test.dart` — existing authentication UI regression tests migrated to injected dependencies.

## Task 1: Define the Application-Owned Authentication Contract

**Files:**

- Create: `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart`
- Create: `apps/mobile/test/features/auth/domain/auth_gateway_test.dart`

- [ ] **Step 1: Write the failing contract test**

Create `apps/mobile/test/features/auth/domain/auth_gateway_test.dart`:

```dart
import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthFailure exposes its safe user-facing message', () {
    const failure = AuthFailure('Invalid login credentials');

    expect(failure.message, 'Invalid login credentials');
    expect(failure.toString(), 'Invalid login credentials');
  });

  test('registration outcome distinguishes session and confirmation flows', () {
    expect(
      RegistrationOutcome.values,
      [
        RegistrationOutcome.signedIn,
        RegistrationOutcome.confirmationRequired,
      ],
    );
  });
}
```

- [ ] **Step 2: Run the test and verify the missing contract causes failure**

Run:

```powershell
flutter test test/features/auth/domain/auth_gateway_test.dart
```

Expected: FAIL because `auth_gateway.dart`, `AuthFailure`, and `RegistrationOutcome` do not exist.

- [ ] **Step 3: Add the minimal contract**

Create `apps/mobile/lib/src/features/auth/domain/auth_gateway.dart`:

```dart
enum RegistrationOutcome {
  signedIn,
  confirmationRequired,
}

final class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthGateway {
  bool get isSignedIn;

  Stream<bool> get signedInChanges;

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<RegistrationOutcome> register({
    required String name,
    required String email,
    required String password,
  });
}
```

- [ ] **Step 4: Format and rerun the contract test**

Run:

```powershell
dart format lib/src/features/auth/domain/auth_gateway.dart test/features/auth/domain/auth_gateway_test.dart
flutter test test/features/auth/domain/auth_gateway_test.dart
```

Expected: both tests PASS.

- [ ] **Step 5: Commit the contract**

Run from the repository root:

```powershell
git add -- apps/mobile/lib/src/features/auth/domain/auth_gateway.dart apps/mobile/test/features/auth/domain/auth_gateway_test.dart
git commit -m "feat: define mobile authentication gateway"
```

## Task 2: Inject Authentication into the Existing Auth Page

**Files:**

- Create: `apps/mobile/test/support/fake_auth_gateway.dart`
- Create: `apps/mobile/test/features/auth/presentation/auth_page_test.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`

- [ ] **Step 1: Add the shared fake gateway**

Create `apps/mobile/test/support/fake_auth_gateway.dart`:

```dart
import 'dart:async';

import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';

final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({bool isSignedIn = false}) : _isSignedIn = isSignedIn;

  final _signedInController = StreamController<bool>.broadcast();
  bool _isSignedIn;

  String? signInEmail;
  String? signInPassword;
  Object? signInError;

  String? registrationName;
  String? registrationEmail;
  String? registrationPassword;
  Object? registrationError;
  RegistrationOutcome registrationOutcome = RegistrationOutcome.signedIn;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  Stream<bool> get signedInChanges => _signedInController.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) {
      throw error;
    }
    signInEmail = email;
    signInPassword = password;
  }

  @override
  Future<RegistrationOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final error = registrationError;
    if (error != null) {
      throw error;
    }
    registrationName = name;
    registrationEmail = email;
    registrationPassword = password;
    return registrationOutcome;
  }

  void emitSignedIn(bool value) {
    _isSignedIn = value;
    _signedInController.add(value);
  }

  Future<void> dispose() => _signedInController.close();
}
```

- [ ] **Step 2: Write failing AuthPage behavior and boundary tests**

Create `apps/mobile/test/features/auth/presentation/auth_page_test.dart`:

```dart
import 'dart:io';

import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway authGateway;

  setUp(() {
    authGateway = FakeAuthGateway();
    addTearDown(authGateway.dispose);
  });

  Future<void> pumpAuthPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(home: AuthPage(authGateway: authGateway)),
    );
  }

  testWidgets('login delegates trimmed email and password', (tester) async {
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      '  child@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Secret123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(authGateway.signInEmail, 'child@example.com');
    expect(authGateway.signInPassword, 'Secret123!');
  });

  testWidgets('registration delegates fields and shows confirmation message',
      (tester) async {
    authGateway.registrationOutcome =
        RegistrationOutcome.confirmationRequired;
    await pumpAuthPage(tester);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('register-name-field')),
      '  Ming Jiang  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email-field')),
      '  ming@example.com  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password-field')),
      'StrongPass12!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password-field')),
      'StrongPass12!',
    );
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(authGateway.registrationName, 'Ming Jiang');
    expect(authGateway.registrationEmail, 'ming@example.com');
    expect(authGateway.registrationPassword, 'StrongPass12!');
    expect(
      find.text(
        'Account created. Check your email if confirmation is enabled.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows safe authentication failures', (tester) async {
    authGateway.signInError = const AuthFailure('Invalid login credentials');
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'child@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'wrong-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Invalid login credentials'), findsOneWidget);
  });

  testWidgets('shows a generic message for unexpected failures',
      (tester) async {
    authGateway.signInError = StateError('internal details');
    await pumpAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'child@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'Secret123!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal details'), findsNothing);
  });

  test('AuthPage presentation does not import or access Supabase', () {
    final source = File(
      'lib/src/features/auth/presentation/auth_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('supabase_flutter')));
    expect(source, isNot(contains('Supabase.instance')));
  });
}
```

- [ ] **Step 3: Run the AuthPage tests and verify they fail**

Run:

```powershell
flutter test test/features/auth/presentation/auth_page_test.dart
```

Expected: FAIL because `AuthPage` has no `authGateway` parameter and still imports/accesses Supabase.

- [ ] **Step 4: Replace the AuthPage SDK dependency with the gateway**

In `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`, remove:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

Add:

```dart
import '../domain/auth_gateway.dart';
```

Replace the widget declaration with:

```dart
class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.authGateway,
    super.key,
  });

  final AuthGateway authGateway;

  @override
  State<AuthPage> createState() => _AuthPageState();
}
```

Replace the `try`/`catch`/`finally` portion of `_submit` with:

```dart
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegistering) {
        final outcome = await widget.authGateway.register(
          name: _nameController.text.trim(),
          email: email,
          password: password,
        );

        if (outcome == RegistrationOutcome.confirmationRequired && mounted) {
          setState(() {
            _message =
                'Account created. Check your email if confirmation is enabled.';
            _isSuccessMessage = true;
          });
        }
      } else {
        await widget.authGateway.signIn(email: email, password: password);
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
```

- [ ] **Step 5: Format and rerun the AuthPage tests**

Run:

```powershell
dart format lib/src/features/auth/presentation/auth_page.dart test/support/fake_auth_gateway.dart test/features/auth/presentation/auth_page_test.dart
flutter test test/features/auth/presentation/auth_page_test.dart
```

Expected: all five tests PASS.

- [ ] **Step 6: Commit the AuthPage injection**

Run from the repository root:

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/auth_page.dart apps/mobile/test/support/fake_auth_gateway.dart apps/mobile/test/features/auth/presentation/auth_page_test.dart
git commit -m "refactor: inject authentication into auth page"
```

## Task 3: Observe Authentication State Through the Contract

**Files:**

- Create: `apps/mobile/test/features/auth/presentation/auth_gate_test.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart`

- [ ] **Step 1: Write failing AuthGate state and boundary tests**

Create `apps/mobile/test/features/auth/presentation/auth_gate_test.dart`:

```dart
import 'dart:io';

import 'package:cyanzone_mobile/src/features/auth/presentation/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway authGateway;

  setUp(() {
    authGateway = FakeAuthGateway();
    addTearDown(authGateway.dispose);
  });

  Widget buildGate() {
    return MaterialApp(
      home: AuthGate(
        authGateway: authGateway,
        authenticatedChild: const SizedBox(
          key: ValueKey('authenticated-destination'),
        ),
      ),
    );
  }

  testWidgets('shows authentication when initially signed out',
      (tester) async {
    await tester.pumpWidget(buildGate());

    expect(find.text('Beyond the Blue, Inside the Zone.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('authenticated-destination')),
      findsNothing,
    );
  });

  testWidgets('shows the authenticated destination when initially signed in',
      (tester) async {
    authGateway.emitSignedIn(true);

    await tester.pumpWidget(buildGate());

    expect(
      find.byKey(const ValueKey('authenticated-destination')),
      findsOneWidget,
    );
    expect(find.text('Beyond the Blue, Inside the Zone.'), findsNothing);
  });

  testWidgets('reacts when the gateway emits a signed-in state',
      (tester) async {
    await tester.pumpWidget(buildGate());

    authGateway.emitSignedIn(true);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('authenticated-destination')),
      findsOneWidget,
    );
    expect(find.text('Beyond the Blue, Inside the Zone.'), findsNothing);
  });

  test('AuthGate presentation does not import or access Supabase', () {
    final source = File(
      'lib/src/features/auth/presentation/auth_gate.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('supabase_flutter')));
    expect(source, isNot(contains('Supabase.instance')));
  });
}
```

- [ ] **Step 2: Run the AuthGate tests and verify they fail**

Run:

```powershell
flutter test test/features/auth/presentation/auth_gate_test.dart
```

Expected: FAIL because `AuthGate` lacks injected gateway/child parameters and still imports/accesses Supabase.

- [ ] **Step 3: Implement the contract-based AuthGate observer**

Replace `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../parent_child/presentation/sos_tracking_scope.dart';
import '../../shell/presentation/main_shell.dart';
import '../domain/auth_gateway.dart';
import 'auth_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authGateway,
    this.authenticatedChild = const SosTrackingHost(child: MainShell()),
    super.key,
  });

  final AuthGateway authGateway;
  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: authGateway.signedInChanges,
      initialData: authGateway.isSignedIn,
      builder: (context, snapshot) {
        final isSignedIn = snapshot.data ?? authGateway.isSignedIn;
        return isSignedIn
            ? authenticatedChild
            : AuthPage(authGateway: authGateway);
      },
    );
  }
}
```

- [ ] **Step 4: Format and rerun AuthGate and AuthPage tests**

Run:

```powershell
dart format lib/src/features/auth/presentation/auth_gate.dart test/features/auth/presentation/auth_gate_test.dart
flutter test test/features/auth/presentation/auth_gate_test.dart test/features/auth/presentation/auth_page_test.dart
```

Expected: all AuthGate and AuthPage tests PASS.

- [ ] **Step 5: Commit the AuthGate observer**

Run from the repository root:

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/auth_gate.dart apps/mobile/test/features/auth/presentation/auth_gate_test.dart
git commit -m "refactor: observe injected authentication state"
```

## Task 4: Add the Supabase Adapter and Production Composition Root

**Files:**

- Create: `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart`
- Create: `apps/mobile/lib/src/app_dependencies.dart`
- Create: `apps/mobile/test/app_dependencies_test.dart`
- Modify: `apps/mobile/lib/src/app.dart`
- Modify: `apps/mobile/lib/main.dart`
- Modify: `apps/mobile/test/widget_test.dart`

- [ ] **Step 1: Write the failing production-wiring test**

Create `apps/mobile/test/app_dependencies_test.dart`:

```dart
import 'package:cyanzone_mobile/src/app_dependencies.dart';
import 'package:cyanzone_mobile/src/features/auth/data/supabase_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('production dependencies use the Supabase authentication adapter', () {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );

    final dependencies = AppDependencies.production(client);

    expect(dependencies.authGateway, isA<SupabaseAuthGateway>());
  });
}
```

- [ ] **Step 2: Run the wiring test and verify it fails**

Run:

```powershell
flutter test test/app_dependencies_test.dart
```

Expected: FAIL because `AppDependencies` and `SupabaseAuthGateway` do not exist.

- [ ] **Step 3: Implement the Supabase adapter**

Create `apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_gateway.dart';

final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges => _client.auth.onAuthStateChange
      .map((state) => state.session != null)
      .distinct();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<RegistrationOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      return response.session == null
          ? RegistrationOutcome.confirmationRequired
          : RegistrationOutcome.signedIn;
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
```

- [ ] **Step 4: Implement the dependency facade**

Create `apps/mobile/lib/src/app_dependencies.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/supabase_auth_gateway.dart';
import 'features/auth/domain/auth_gateway.dart';

final class AppDependencies {
  const AppDependencies({required this.authGateway});

  factory AppDependencies.production(SupabaseClient client) {
    return AppDependencies(
      authGateway: SupabaseAuthGateway(client),
    );
  }

  final AuthGateway authGateway;
}
```

- [ ] **Step 5: Wire dependencies through the app**

Replace `apps/mobile/lib/src/app.dart` with:

```dart
import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class CyanZoneApp extends StatelessWidget {
  const CyanZoneApp({
    required this.dependencies,
    super.key,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyanZone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthGate(authGateway: dependencies.authGateway),
    );
  }
}
```

In `apps/mobile/lib/main.dart`, add:

```dart
import 'src/app_dependencies.dart';
```

Then replace:

```dart
  runApp(const CyanZoneApp());
```

with:

```dart
  final dependencies = AppDependencies.production(Supabase.instance.client);
  runApp(CyanZoneApp(dependencies: dependencies));
```

- [ ] **Step 6: Migrate existing app widget tests to the fake gateway**

In `apps/mobile/test/widget_test.dart`, remove:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

Add:

```dart
import 'package:cyanzone_mobile/src/app_dependencies.dart';

import 'support/fake_auth_gateway.dart';
```

Replace the existing `setUpAll` and add a shared pump helper at the start of `main`:

```dart
void main() {
  late FakeAuthGateway authGateway;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authGateway = FakeAuthGateway();
    addTearDown(authGateway.dispose);
  });

  Future<void> pumpApp(WidgetTester tester) {
    return tester.pumpWidget(
      CyanZoneApp(
        dependencies: AppDependencies(authGateway: authGateway),
      ),
    );
  }
```

Replace every occurrence of:

```dart
    await tester.pumpWidget(const CyanZoneApp());
```

with:

```dart
    await pumpApp(tester);
```

Keep every existing assertion and interaction unchanged.

- [ ] **Step 7: Format and run composition plus existing regression tests**

Run:

```powershell
dart format lib/main.dart lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth/data/supabase_auth_gateway.dart test/app_dependencies_test.dart test/widget_test.dart
flutter test test/app_dependencies_test.dart test/widget_test.dart
```

Expected: the production factory test and all five existing widget regression tests PASS without calling `Supabase.initialize` in `widget_test.dart`.

- [ ] **Step 8: Commit production composition**

Run from the repository root:

```powershell
git add -- apps/mobile/lib/main.dart apps/mobile/lib/src/app.dart apps/mobile/lib/src/app_dependencies.dart apps/mobile/lib/src/features/auth/data/supabase_auth_gateway.dart apps/mobile/test/app_dependencies_test.dart apps/mobile/test/widget_test.dart
git commit -m "refactor: compose mobile authentication dependency"
```

## Task 5: Verify the Foundation as One Focused Change

**Files:**

- Verify only; no planned source changes.

- [ ] **Step 1: Run all focused authentication tests together**

Run from `apps/mobile`:

```powershell
flutter test test/features/auth test/app_dependencies_test.dart test/widget_test.dart
```

Expected: every selected test PASS.

- [ ] **Step 2: Run scoped static analysis**

Run from `apps/mobile`:

```powershell
flutter analyze lib/main.dart lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/app_dependencies_test.dart test/features/auth test/support/fake_auth_gateway.dart test/widget_test.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Verify presentation-layer SDK separation**

Run from the repository root:

```powershell
rg -n "supabase_flutter|Supabase\.instance" apps/mobile/lib/src/features/auth/presentation
```

Expected: no matches and exit code 1, meaning neither authentication presentation file contains the Supabase SDK or singleton access.

- [ ] **Step 4: Inspect the final diff and repository state**

Run from the repository root:

```powershell
git diff --check
git status --short
git log --oneline -5
```

Expected:

- `git diff --check` prints no whitespace errors;
- only the user's five pre-existing screenshot deletions remain unstaged;
- the log shows the four foundation implementation commits after the design and plan commits.

- [ ] **Step 5: Record the verification outcome**

Report the exact focused test count, analyzer result, boundary-search result, and remaining unrelated working-tree changes. Do not claim broader mobile or end-to-end coverage because those suites are intentionally outside this phase.
