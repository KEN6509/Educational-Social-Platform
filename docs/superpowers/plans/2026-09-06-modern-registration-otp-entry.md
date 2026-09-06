# Modern Registration OTP Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the registration OTP password-style field with a centered six-cell input and align the borderless Back action with the heading.

**Architecture:** Add a focused `RegistrationOtpField` presentation widget that keeps one real Flutter `TextField` as the input and accessibility source while rendering six responsive visual cells from its controller value. `EmailOtpPanel` composes the new field and rearranges only its heading area; the registration controller, Supabase gateway, resend timer, and activation flow remain unchanged.

**Tech Stack:** Flutter, Dart, Material 3, `flutter_test`, existing CyanZone theme and authentication presentation layer.

---

### Task 1: Build the reusable six-cell OTP field

**Files:**
- Create: `apps/mobile/lib/src/features/auth/presentation/registration_otp_field.dart`
- Create: `apps/mobile/test/features/auth/presentation/registration_otp_field_test.dart`

- [x] **Step 1: Write failing widget tests for structure and input behavior**

Create `registration_otp_field_test.dart` with tests that expect six keyed cells, a centered cell group, one real numeric text field, digit-only input, a six-character limit, focus styling, and complete-only submission:

```dart
import 'package:cyanzone_mobile/src/features/auth/presentation/registration_otp_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders six cells as one centered group', (tester) async {
    final controller = TextEditingController(text: '123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RegistrationOtpField(controller: controller)),
    ));

    expect(find.byKey(const ValueKey('registration-otp-cells')), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      expect(find.byKey(ValueKey('registration-otp-cell-$index')), findsOneWidget);
    }
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('registration-otp-cells')),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses one six-digit numeric input and submits only when complete',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submitted = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RegistrationOtpField(
          controller: controller,
          onSubmitted: (value) => submitted = value,
        ),
      ),
    ));

    final input = find.byKey(const ValueKey('registration-otp-field'));
    final field = tester.widget<TextField>(input);
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(
      field.inputFormatters!.whereType<LengthLimitingTextInputFormatter>().single.maxLength,
      6,
    );

    await tester.enterText(input, '12345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, isEmpty);

    await tester.enterText(input, '12ab345678');
    expect(controller.text, '123456');

    await tester.enterText(input, '123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, '123456');
  });
}
```

- [x] **Step 2: Run the new tests and verify RED**

Run directly in the user's PowerShell terminal:

```powershell
cd apps/mobile
flutter test test/features/auth/presentation/registration_otp_field_test.dart
```

Expected: FAIL because `registration_otp_field.dart` and `RegistrationOtpField` do not exist.

- [x] **Step 3: Implement the minimal reusable OTP field**

Create `registration_otp_field.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistrationOtpField extends StatefulWidget {
  const RegistrationOtpField({
    required this.controller,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  static const length = 6;

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<RegistrationOtpField> createState() => _RegistrationOtpFieldState();
}

class _RegistrationOtpFieldState extends State<RegistrationOtpField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 344),
        child: SizedBox(
          height: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => ExcludeSemantics(
                  child: Row(
                    key: const ValueKey('registration-otp-cells'),
                    children: [
                      for (var index = 0;
                          index < RegistrationOtpField.length;
                          index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedContainer(
                            key: ValueKey('registration-otp-cell-$index'),
                            duration: const Duration(milliseconds: 140),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _isActive(index, value.text)
                                  ? const Color(0xFFF1FBFC)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isActive(index, value.text)
                                    ? theme.colorScheme.primary
                                    : const Color(0xFFD5E0E5),
                                width: _isActive(index, value.text) ? 1.8 : 1.2,
                              ),
                            ),
                            child: Text(
                              index < value.text.length ? value.text[index] : '',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF0B1F3E),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Semantics(
                label: 'Six-digit verification code',
                textField: true,
                child: TextField(
                  key: const ValueKey('registration-otp-field'),
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(RegistrationOtpField.length),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  enableSuggestions: false,
                  autocorrect: false,
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: (value) {
                    if (value.trim().length == RegistrationOtpField.length) {
                      widget.onSubmitted?.call(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isActive(int index, String value) {
    return widget.enabled &&
        _focusNode.hasFocus &&
        value.length < RegistrationOtpField.length &&
        index == value.length;
  }
}
```

- [x] **Step 4: Format and run the focused component tests to verify GREEN**

```powershell
cd apps/mobile
dart format lib/src/features/auth/presentation/registration_otp_field.dart test/features/auth/presentation/registration_otp_field_test.dart
flutter test test/features/auth/presentation/registration_otp_field_test.dart
```

Expected: all new OTP component tests pass.

- [x] **Step 5: Commit the reusable field**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/registration_otp_field.dart apps/mobile/test/features/auth/presentation/registration_otp_field_test.dart
git commit -m "feat: add modern registration otp field"
```

### Task 2: Integrate the approved header and centered field

**Files:**
- Modify: `apps/mobile/lib/src/features/auth/presentation/email_otp_panel.dart`
- Modify: `apps/mobile/test/features/auth/presentation/auth_page_test.dart`

- [x] **Step 1: Update the flow tests first**

In `auth_page_test.dart`, change OTP heading expectations from `Verify your email` to `Enter the 6-digit code`. Add assertions proving the Back action and heading share a row and the new field remains compatible with the existing controller and Verify button flow:

```dart
expect(find.text('Enter the 6-digit code'), findsOneWidget);
expect(find.byKey(const ValueKey('registration-otp-cells')), findsOneWidget);

final headingRow = find.ancestor(
  of: find.text('Enter the 6-digit code'),
  matching: find.byKey(const ValueKey('registration-otp-header')),
);
expect(headingRow, findsOneWidget);
expect(
  find.descendant(
    of: headingRow,
    matching: find.byTooltip('Change email'),
  ),
  findsOneWidget,
);
```

Keep the existing test that enters `123456`, enables Verify Email, delegates the token, clears pending storage, and preserves form values after Back.

- [x] **Step 2: Run the updated flow test and verify RED**

```powershell
cd apps/mobile
flutter test test/features/auth/presentation/auth_page_test.dart
```

Expected: FAIL because the current screen still uses the old heading arrangement and single decorated field.

- [x] **Step 3: Integrate `RegistrationOtpField` and rearrange the header**

In `email_otp_panel.dart`:

```dart
import 'registration_otp_field.dart';
```

Replace the floating Back button plus separate heading with:

```dart
Row(
  key: const ValueKey('registration-otp-header'),
  children: [
    IconButton(
      tooltip: 'Change email',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      onPressed: isBusy ? null : onBack,
      icon: const Icon(Icons.arrow_back_rounded),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'Enter the 6-digit code',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF0B1F3E),
              fontWeight: FontWeight.w900,
            ),
      ),
    ),
  ],
),
const SizedBox(height: 8),
Text(
  'We sent a verification code to ${state.pendingEmail ?? ''}.',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF536A74),
        height: 1.4,
      ),
),
const SizedBox(height: 18),
RegistrationOtpField(
  controller: tokenController,
  enabled: !isBusy,
  onChanged: onTokenChanged,
  onSubmitted: (_) => onVerify(),
),
```

Remove the old wide `TextField` and its no-longer-needed `flutter/services.dart` import. Keep the existing status message, Verify Email button, and resend controls unchanged.

- [x] **Step 4: Format and run focused authentication tests to verify GREEN**

```powershell
cd apps/mobile
dart format lib/src/features/auth/presentation/email_otp_panel.dart test/features/auth/presentation/auth_page_test.dart
flutter test test/features/auth test/widget_test.dart test/registration_consent_sql_test.dart
```

Expected: all focused registration/authentication tests pass.

- [x] **Step 5: Run scoped static analysis**

```powershell
cd apps/mobile
flutter analyze lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/features/auth test/registration_consent_sql_test.dart test/support/fake_auth_gateway.dart test/support/fake_pending_registration_store.dart test/widget_test.dart
```

Expected: `No issues found!`

- [x] **Step 6: Commit the integration**

```powershell
git add -- apps/mobile/lib/src/features/auth/presentation/email_otp_panel.dart apps/mobile/test/features/auth/presentation/auth_page_test.dart
git commit -m "fix: modernize registration otp entry"
```

### Task 3: Update evidence and visually verify the real mobile screen

**Files:**
- Modify: `Project_Overview.md`
- Modify: `docs/superpowers/specs/2026-09-06-modern-registration-otp-entry-design.md`
- Record the physical visual-QA status in the design spec; do not recreate the
  previously removed root `design-qa.md`.

- [x] **Step 1: Update documentation after tests are known**

In the design spec, change its status to `Implemented and verified`. In `Project_Overview.md`, describe the centered six-cell registration OTP input, inline borderless Back action, and the exact focused test count observed during Task 2.

- [x] **Step 2: Run the app on the connected Android device**

```powershell
cd apps/mobile
flutter run -d 10AE6213P700176
```

Expected: CyanZone launches on the physical Android device with the pending registration OTP step restored, or the user can reach it by registering a test email.

- [ ] **Step 3: Capture and compare the implemented screen**

Capture the physical device at the OTP step and compare it against the approved revised Option A and the user's current-screen screenshot. Check:

- the borderless Back action is beside the heading;
- all six cells remain centered and on one line;
- digit, empty, focused, disabled, and complete states are visually clear;
- the card does not overflow at the device's 1080 × 2400 display;
- the status, Verify Email, and resend controls preserve their hierarchy.

Record the compared viewport/state, findings by P0–P3 priority, fixes applied,
and the final result in the design spec. The user previously removed the root
`design-qa.md`, so do not recreate it. If capture is unavailable, record the
visual QA as pending/blocked and do not claim visual verification.

- [x] **Step 4: Re-run focused verification after any visual correction**

```powershell
cd apps/mobile
flutter test test/features/auth test/widget_test.dart test/registration_consent_sql_test.dart
flutter analyze lib/src/app.dart lib/src/app_dependencies.dart lib/src/features/auth test/features/auth test/registration_consent_sql_test.dart test/support/fake_auth_gateway.dart test/support/fake_pending_registration_store.dart test/widget_test.dart
cd ../..
git diff --check
```

Expected: focused tests pass, analyzer reports no issues, and Git reports no whitespace errors.

- [x] **Step 5: Commit documentation and QA evidence without staging unrelated deletions**

```powershell
git add -- Project_Overview.md docs/superpowers/specs/2026-09-06-modern-registration-otp-entry-design.md docs/superpowers/plans/2026-09-06-modern-registration-otp-entry.md
git commit -m "docs: verify modern registration otp entry"
git status --short
```

Expected: only the user's five pre-existing screenshot deletions remain unstaged.
