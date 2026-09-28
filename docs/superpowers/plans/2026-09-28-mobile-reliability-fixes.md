# Mobile Reliability Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make profile-name validation, bottom-edge layout, snackbar presentation, notification badges, and Android push delivery reliable before the next CyanZone test build.

**Architecture:** Shared policies and widgets will own repeated validation and safe-area behavior. UI pages will consume those shared units, notification reads will update local state immediately after the server confirms the write, and Supabase will enforce the same name invariant as Flutter. Firebase Admin credentials remain deployment-only and will be corrected in Vercel without entering source control.

**Tech Stack:** Flutter/Dart, Flutter widget tests, Supabase/PostgreSQL, Node/Firebase Admin, Vercel, Firebase Cloud Messaging

---

## File structure

### New files

- `apps/mobile/lib/src/core/validation/profile_name_policy.dart` — normalization, limits, helper copy, and validation messages for profile names.
- `apps/mobile/lib/src/core/widgets/profile_name_form_field.dart` — reusable form field that applies the shared policy and formatter.
- `apps/mobile/lib/src/core/widgets/bottom_safe_surface.dart` — paints a bottom surface to the physical edge and applies the safe inset inside it.
- `apps/mobile/lib/src/core/theme/app_system_ui.dart` — shared Android edge-to-edge system-bar configuration.
- `apps/mobile/test/profile_name_policy_test.dart` — profile-name boundary tests.
- `apps/mobile/test/profile_name_form_field_test.dart` — helper, formatter, and inline-error widget tests.
- `apps/mobile/test/bottom_safe_surface_test.dart` — internal safe-area padding and viewport tests.
- `apps/mobile/test/app_system_ui_test.dart` — transparent navigation bar and disabled contrast-scrim contract.
- `apps/mobile/test/profile_name_sql_test.dart` — fresh-schema and hosted-project migration contract tests.
- `supabase/profile_name_policy.sql` — rerunnable existing-project migration with a preflight data check.

### Modified files

- `apps/mobile/lib/src/features/auth/presentation/auth_page.dart` — use the shared name field during registration.
- `apps/mobile/lib/src/features/profile/presentation/edit_profile_page.dart` — validate the Edit Profile form before saving.
- `apps/mobile/lib/src/features/profile/presentation/edit_profile_widgets.dart` — use the shared name field and show helper/error copy.
- `supabase/schema.sql` — enforce trimmed profile-name length in fresh projects.
- `supabase/README.md` — document the existing-project name migration and verification query.
- `apps/mobile/lib/main.dart` — apply the shared edge-to-edge system UI configuration at startup.
- `apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart` — move the device inset inside an opaque bottom surface.
- `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart` — extend the composer/permission surface to the physical bottom.
- `apps/mobile/test/cyanzone_bottom_navigation_test.dart` — verify surface ownership and stable geometry across insets.
- `apps/mobile/test/chat_widgets_test.dart` — verify chat composer bottom behavior and immediate notification badge clearing.
- `apps/mobile/lib/src/core/theme/app_design_tokens.dart` — reduce snackbar bottom spacing.
- `apps/mobile/lib/src/core/theme/app_theme.dart` — reduce theme-level snackbar elevation.
- `apps/mobile/lib/src/core/widgets/app_feedback.dart` — reduce shared snackbar elevation.
- `apps/mobile/test/app_design_tokens_test.dart` — assert the new feedback geometry.
- `apps/mobile/test/app_feedback_test.dart` — assert the new snackbar margin and elevation.
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart` — return the successfully read section and retain the page on failure.
- `apps/mobile/lib/src/features/chat/presentation/chat_page.dart` — apply an optimistic zero count, invalidate stale loads, and refresh in the background.
- `docs/setup.md` — record the Firebase-project matching and delivery verification procedure.

## Task 1: Build the shared profile-name policy and field

**Files:**
- Create: `apps/mobile/lib/src/core/validation/profile_name_policy.dart`
- Create: `apps/mobile/lib/src/core/widgets/profile_name_form_field.dart`
- Create: `apps/mobile/test/profile_name_policy_test.dart`
- Create: `apps/mobile/test/profile_name_form_field_test.dart`

- [ ] **Step 1: Write failing policy boundary tests**

```dart
import 'package:cyanzone_mobile/src/core/validation/profile_name_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes surrounding whitespace', () {
    expect(ProfileNamePolicy.normalize('  Ken Chan  '), 'Ken Chan');
  });

  test('accepts one through twenty-four trimmed characters', () {
    expect(ProfileNamePolicy.validate('K'), isNull);
    expect(ProfileNamePolicy.validate(List.filled(24, 'K').join()), isNull);
  });

  test('rejects empty, whitespace-only, and overlong names', () {
    expect(ProfileNamePolicy.validate(''), ProfileNamePolicy.requiredError);
    expect(ProfileNamePolicy.validate('   '), ProfileNamePolicy.requiredError);
    expect(
      ProfileNamePolicy.validate(List.filled(25, 'K').join()),
      ProfileNamePolicy.lengthError,
    );
  });
}
```

- [ ] **Step 2: Run the policy test and confirm it fails because the policy does not exist**

Run: `cd apps/mobile && flutter test test/profile_name_policy_test.dart`

Expected: FAIL with an import or undefined-class error for `ProfileNamePolicy`.

- [ ] **Step 3: Implement the minimal shared policy**

```dart
abstract final class ProfileNamePolicy {
  static const minLength = 1;
  static const maxLength = 24;
  static const helperText = '1–24 characters';
  static const requiredError = 'Name is required.';
  static const lengthError = 'Name must be 1–24 characters.';

  static String normalize(String value) => value.trim();

  static String? validate(String? value) {
    final normalized = normalize(value ?? '');
    if (normalized.isEmpty) return requiredError;
    if (normalized.length > maxLength) return lengthError;
    return null;
  }
}
```

- [ ] **Step 4: Write failing widget tests for helper text, empty validation, and the 24-character formatter**

```dart
testWidgets('shows the name policy and validates an empty value', (tester) async {
  final formKey = GlobalKey<FormState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Form(
        key: formKey,
        child: ProfileNameFormField(
          controller: TextEditingController(),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ),
    ),
  ));

  expect(find.text('1–24 characters'), findsOneWidget);
  formKey.currentState!.validate();
  await tester.pump();
  expect(find.text('Name is required.'), findsOneWidget);
});

testWidgets('limits entered names to twenty-four characters', (tester) async {
  final controller = TextEditingController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ProfileNameFormField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    ),
  ));

  await tester.enterText(
    find.byType(TextFormField),
    List.filled(25, 'K').join(),
  );
  expect(controller.text.length, 24);
});
```

- [ ] **Step 5: Implement the reusable form field**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../validation/profile_name_policy.dart';

class ProfileNameFormField extends StatelessWidget {
  const ProfileNameFormField({
    required this.controller,
    required this.decoration,
    this.fieldKey,
    this.enabled = true,
    this.textInputAction,
    this.autofillHints,
    super.key,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: const [
        LengthLimitingTextInputFormatter(ProfileNamePolicy.maxLength),
      ],
      decoration: decoration.copyWith(
        helperText: decoration.helperText ?? ProfileNamePolicy.helperText,
      ),
      validator: ProfileNamePolicy.validate,
    );
  }
}
```

- [ ] **Step 6: Run both focused tests**

Run: `cd apps/mobile && flutter test test/profile_name_policy_test.dart test/profile_name_form_field_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit the shared name units**

```bash
git add apps/mobile/lib/src/core/validation/profile_name_policy.dart apps/mobile/lib/src/core/widgets/profile_name_form_field.dart apps/mobile/test/profile_name_policy_test.dart apps/mobile/test/profile_name_form_field_test.dart
git commit -m "feat(mobile): add shared profile name policy"
```

## Task 2: Apply name validation to registration and Edit Profile

**Files:**
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/edit_profile_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/edit_profile_widgets.dart`
- Modify: `apps/mobile/test/features/auth/presentation/auth_page_test.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`

- [ ] **Step 1: Add failing registration tests for helper/error copy and a valid one-character name**

```dart
testWidgets('registration shows and enforces the shared name policy',
    (tester) async {
  await pumpAuthPage(tester);
  await tester.tap(find.text('Create account'));
  await tester.pump();

  expect(find.text('1–24 characters'), findsOneWidget);
  await tester.enterText(
    find.byKey(const ValueKey('register-name-field')),
    '   ',
  );
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Create account'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pump();

  expect(find.text('Name is required.'), findsOneWidget);
  expect(authGateway.registrationRequest, isNull);
});

testWidgets('registration accepts and normalizes a one-character name',
    (tester) async {
  authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;
  await pumpAuthPage(tester);
  await tester.tap(find.text('Create account'));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey('register-name-field')),
    ' K ',
  );
  await tester.enterText(
    find.byKey(const ValueKey('register-email-field')),
    'ken@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('register-password-field')),
    'StrongPass12!',
  );
  await tester.enterText(
    find.byKey(const ValueKey('register-confirm-password-field')),
    'StrongPass12!',
  );
  await tester.tap(
    find.byKey(const ValueKey('registration-consent-checkbox')),
  );
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Create account'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();

  expect(authGateway.registrationRequest?.name, 'K');
});
```

- [ ] **Step 2: Add a failing profile presentation contract test**

```dart
test('Edit Profile validates the shared name field before saving', () {
  final page = _read('edit_profile_page.dart');
  final widgets = _read('edit_profile_widgets.dart');

  expect(page, contains('final _formKey = GlobalKey<FormState>()'));
  expect(page, contains('_formKey.currentState?.validate()'));
  expect(widgets, contains('ProfileNameFormField('));
  expect(widgets, contains('formKey: formKey'));
});
```

- [ ] **Step 3: Run the two focused test files and confirm the new expectations fail**

Run: `cd apps/mobile && flutter test test/features/auth/presentation/auth_page_test.dart test/profile_presentation_decomposition_test.dart`

Expected: FAIL because registration still requires two characters and Edit Profile has no form validation.

- [ ] **Step 4: Replace the registration name field with `ProfileNameFormField`**

```dart
ProfileNameFormField(
  fieldKey: const ValueKey('register-name-field'),
  enabled: !isLoading,
  controller: nameController,
  textInputAction: TextInputAction.next,
  autofillHints: const [AutofillHints.name],
  decoration: const InputDecoration(
    labelText: 'Name',
    prefixIcon: Icon(Icons.badge_outlined),
  ),
),
```

In `_submit`, normalize through the policy:

```dart
name: ProfileNamePolicy.normalize(_nameController.text),
```

- [ ] **Step 5: Convert Edit Profile to a validated form**

Add `final _formKey = GlobalKey<FormState>();` to `_EditProfilePageState`. At the start of `_saveProfile`, before setting `_isSaving`, use:

```dart
if (!(_formKey.currentState?.validate() ?? false)) return;
final normalizedName = ProfileNamePolicy.normalize(_nameController.text);
```

Pass `formKey: _formKey` to `_EditProfileBody`, then use this structure while keeping `_EditProfileInput` for the bio:

```dart
Form(
  key: formKey,
  child: SingleChildScrollView(
    child: Column(
      children: [
        const SizedBox(height: 32),
        _EditProfileAvatar(
          profile: profile,
          selectedImage: selectedImage,
          onTap: onPickImage,
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ProfileNameFormField(
            controller: nameController,
            decoration: appInputDecoration(hintText: 'Enter your name')
                .copyWith(labelText: 'Username'),
          ),
        ),
        _EditProfileInput(
          label: 'Bio',
          controller: bioController,
          hint: 'Add a bio to your profile',
          maxLines: 5,
          maxLength: 150,
        ),
      ],
    ),
  ),
)
```

- [ ] **Step 6: Run the focused tests**

Run: `cd apps/mobile && flutter test test/features/auth/presentation/auth_page_test.dart test/profile_presentation_decomposition_test.dart test/profile_name_policy_test.dart test/profile_name_form_field_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit the two form integrations**

```bash
git add apps/mobile/lib/src/features/auth/presentation/auth_page.dart apps/mobile/lib/src/features/profile/presentation/edit_profile_page.dart apps/mobile/lib/src/features/profile/presentation/edit_profile_widgets.dart apps/mobile/test/features/auth/presentation/auth_page_test.dart apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "fix(mobile): validate profile names consistently"
```

## Task 3: Enforce profile-name length in Supabase

**Files:**
- Create: `supabase/profile_name_policy.sql`
- Modify: `supabase/schema.sql`
- Modify: `supabase/README.md`
- Create: `apps/mobile/test/profile_name_sql_test.dart`

- [ ] **Step 1: Write a failing SQL contract test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh schema and migration enforce trimmed names of 1–24 characters', () {
    final schema = File('../../supabase/schema.sql').readAsStringSync();
    final migration = File('../../supabase/profile_name_policy.sql').readAsStringSync();
    const check = 'char_length(btrim(name)) between 1 and 24';

    expect(schema, contains(check));
    expect(migration, contains(check));
    expect(migration, contains('if exists'));
    expect(migration.indexOf('if exists'), lessThan(migration.indexOf('add constraint profiles_name_length_check')));
    expect(migration, contains('validate constraint profiles_name_length_check'));
  });
}
```

- [ ] **Step 2: Run the SQL test and confirm it fails because the migration is absent**

Run: `cd apps/mobile && flutter test test/profile_name_sql_test.dart`

Expected: FAIL with a missing-file error.

- [ ] **Step 3: Add the fresh-schema constraint and rerunnable migration**

Use this migration order:

```sql
do $$
begin
  if exists (
    select 1
    from public.profiles
    where char_length(btrim(name)) not between 1 and 24
  ) then
    raise exception 'Profiles contain names outside the 1-24 character policy';
  end if;
end;
$$;

alter table public.profiles
  drop constraint if exists profiles_name_length_check;

alter table public.profiles
  add constraint profiles_name_length_check
  check (char_length(btrim(name)) between 1 and 24)
  not valid;

alter table public.profiles
  validate constraint profiles_name_length_check;
```

In `schema.sql`, define `name` as:

```sql
name text not null
  check (char_length(btrim(name)) between 1 and 24),
```

- [ ] **Step 4: Document the hosted-project preflight and verification query**

Add the exact command order to `supabase/README.md`, including:

```sql
select id, name, char_length(btrim(name)) as trimmed_length
from public.profiles
where char_length(btrim(name)) not between 1 and 24;
```

The migration must be run only when this returns zero rows.

- [ ] **Step 5: Run the SQL test**

Run: `cd apps/mobile && flutter test test/profile_name_sql_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit the database policy**

```bash
git add supabase/profile_name_policy.sql supabase/schema.sql supabase/README.md apps/mobile/test/profile_name_sql_test.dart
git commit -m "fix(database): enforce profile name length"
```

## Task 4: Create a global bottom-safe surface and Android edge-to-edge policy

**Files:**
- Create: `apps/mobile/lib/src/core/widgets/bottom_safe_surface.dart`
- Create: `apps/mobile/lib/src/core/theme/app_system_ui.dart`
- Create: `apps/mobile/test/bottom_safe_surface_test.dart`
- Create: `apps/mobile/test/app_system_ui_test.dart`
- Modify: `apps/mobile/lib/main.dart`

- [ ] **Step 1: Write failing tests for internal bottom padding**

```dart
for (final viewport in const [Size(360, 800), Size(412, 915)]) {
  testWidgets('owns the physical bottom at $viewport', (tester) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: BottomSafeSurface(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: SizedBox(height: 62),
              ),
            ),
          ),
        ),
      ),
    );

    final surface = find.byType(BottomSafeSurface);
    final padding = tester.widget<Padding>(
      find.descendant(of: surface, matching: find.byType(Padding)).first,
    );
    expect(padding.padding, const EdgeInsets.fromLTRB(12, 8, 12, 46));
    expect(tester.getSize(surface).height, 116);
    expect(tester.getBottomLeft(surface).dy, viewport.height);
  });
}
```

- [ ] **Step 2: Write the failing system UI contract test**

```dart
test('system UI keeps edge-to-edge navigation transparent without a contrast scrim', () {
  expect(cyanZoneSystemUiOverlayStyle.systemNavigationBarColor, Colors.transparent);
  expect(cyanZoneSystemUiOverlayStyle.systemNavigationBarDividerColor, Colors.transparent);
  expect(cyanZoneSystemUiOverlayStyle.systemNavigationBarContrastEnforced, isFalse);
  expect(cyanZoneSystemUiOverlayStyle.systemNavigationBarIconBrightness, Brightness.dark);
});
```

- [ ] **Step 3: Run both tests and confirm missing-symbol failures**

Run: `cd apps/mobile && flutter test test/bottom_safe_surface_test.dart test/app_system_ui_test.dart`

Expected: FAIL because the shared surface and overlay style do not exist.

- [ ] **Step 4: Implement `BottomSafeSurface`**

```dart
class BottomSafeSurface extends StatelessWidget {
  const BottomSafeSurface({
    required this.child,
    this.color = AppColors.background,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: padding.copyWith(bottom: padding.bottom + safeBottom),
        child: child,
      ),
    );
  }
}
```

- [ ] **Step 5: Implement and apply the system UI policy**

```dart
const cyanZoneSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

Future<void> configureCyanZoneSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(cyanZoneSystemUiOverlayStyle);
}
```

Call `await configureCyanZoneSystemUi();` in `_initializeProductionApp()` before locking portrait orientation.

- [ ] **Step 6: Run the focused tests**

Run: `cd apps/mobile && flutter test test/bottom_safe_surface_test.dart test/app_system_ui_test.dart test/cyanzone_startup_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit the shared responsive infrastructure**

```bash
git add apps/mobile/lib/src/core/widgets/bottom_safe_surface.dart apps/mobile/lib/src/core/theme/app_system_ui.dart apps/mobile/lib/main.dart apps/mobile/test/bottom_safe_surface_test.dart apps/mobile/test/app_system_ui_test.dart
git commit -m "fix(mobile): define edge-to-edge bottom surfaces"
```

## Task 5: Apply physical-bottom ownership to navigation and chat

**Files:**
- Modify: `apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/test/cyanzone_bottom_navigation_test.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Update navigation tests to require an opaque edge-reaching surface**

```dart
for (final bottomInset in const [0.0, 34.0]) {
  testWidgets('navigation owns the bottom with $bottomInset inset',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
        child: const Scaffold(
          bottomNavigationBar: CyanZoneBottomNavigation(
            selectedIndex: 0,
            onTap: _noop,
          ),
        ),
      ),
    ));

    final navigation = find.byType(CyanZoneBottomNavigation);
    final surface = tester.widget<BottomSafeSurface>(
      find.descendant(
        of: navigation,
        matching: find.byType(BottomSafeSurface),
      ),
    );
    expect(surface.color, AppColors.background);
    expect(tester.getBottomLeft(navigation).dy, 915);
    expect(
      tester.getSize(navigation).height,
      AppLayout.floatingNavigationClearance + bottomInset,
    );
  });
}
```

- [ ] **Step 2: Add a failing chat composer test**

```dart
testWidgets('chat composer owns the physical bottom and insets controls',
    (tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
      child: ChatRoomPage(
        conversation: ChatConversation.fromMap({
          'id': 'responsive-room',
          'type': 'direct',
          'request_status': 'accepted',
          'unread_count': 0,
          'other_user_name': 'Ming',
        }),
        loadMessages: () async => const [],
        markRead: (_) async {},
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final surfaceFinder = find.byType(BottomSafeSurface);
  final surface = tester.widget<BottomSafeSurface>(surfaceFinder);
  expect(surface.color, chatWhatsappBackground);
  expect(tester.getBottomLeft(surfaceFinder).dy, 915);
  expect(
    tester.getBottomLeft(surfaceFinder).dy -
        tester.getBottomLeft(find.byType(TextField)).dy,
    greaterThanOrEqualTo(34),
  );
});
```

- [ ] **Step 3: Run both test files and confirm the new bottom-surface expectations fail**

Run: `cd apps/mobile && flutter test test/cyanzone_bottom_navigation_test.dart test/chat_widgets_test.dart`

Expected: FAIL because the inset currently sits outside the painted navigation/composer surfaces.

- [ ] **Step 4: Move navigation spacing inside `BottomSafeSurface`**

Replace the root `Padding` in `CyanZoneBottomNavigation` with:

```dart
return BottomSafeSurface(
  color: AppColors.background,
  padding: const EdgeInsets.all(AppLayout.floatingNavigationOuterMargin),
  child: SizedBox(
    height: AppLayout.floatingNavigationHeight,
    child: DecoratedBox(
      decoration: navigationDecoration,
      child: navigationButtons,
    ),
  ),
);
```

Keep the existing pill decoration, buttons, badge, and selected indicator unchanged.

- [ ] **Step 5: Move chat composer and permission-state spacing inside `BottomSafeSurface`**

For the sendable branch, use:

```dart
BottomSafeSurface(
  key: _composerKey,
  color: chatWhatsappBackground,
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      SizedBox.square(
        dimension: 44,
        child: IconButton(
          onPressed: _isPickingImage ? null : _sendImage,
          icon: Icon(
            _isPickingImage
                ? Icons.hourglass_empty_rounded
                : Icons.image_outlined,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: _controller,
          focusNode: _inputFocusNode,
          minLines: 1,
          maxLines: 4,
          onChanged: _handleComposerChanged,
          decoration: InputDecoration(
            hintText: 'Message...',
            filled: true,
            fillColor: chatInput,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox.square(
        dimension: 44,
        child: IconButton(
          onPressed: _isSending ? null : _send,
          color: const Color(0xFF128C7E),
          icon: Icon(
            _isSending ? Icons.hourglass_empty_rounded : Icons.send_rounded,
          ),
        ),
      ),
    ],
  ),
)
```

Apply the same surface and padding to `chat-send-permission-state`, moving its former margin into the surface padding. Keep `_composerKey` on the sendable surface so mention positioning measures the complete height.

- [ ] **Step 6: Run responsive tests at both viewport sizes**

Run: `cd apps/mobile && flutter test test/bottom_safe_surface_test.dart test/cyanzone_bottom_navigation_test.dart test/navigation_clearance_test.dart test/chat_widgets_test.dart`

Expected: PASS with no overflow at `320x640` or `412x915`, with zero and non-zero bottom insets.

- [ ] **Step 7: Commit the responsive screen integrations**

```bash
git add apps/mobile/lib/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart apps/mobile/test/cyanzone_bottom_navigation_test.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix(mobile): anchor bottom controls responsively"
```

## Task 6: Soften and lower shared snackbars

**Files:**
- Modify: `apps/mobile/lib/src/core/theme/app_design_tokens.dart`
- Modify: `apps/mobile/lib/src/core/theme/app_theme.dart`
- Modify: `apps/mobile/lib/src/core/widgets/app_feedback.dart`
- Modify: `apps/mobile/test/app_design_tokens_test.dart`
- Modify: `apps/mobile/test/app_feedback_test.dart`

- [ ] **Step 1: Add failing exact-value assertions**

```dart
expect(AppInsets.snackbar, const EdgeInsets.fromLTRB(16, 0, 16, 8));
expect(theme.snackBarTheme.elevation, 4);
expect(snackbar.elevation, 4);
expect(snackbar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 8));
```

- [ ] **Step 2: Run focused tests and confirm the old 10-elevation/18-margin values fail**

Run: `cd apps/mobile && flutter test test/app_design_tokens_test.dart test/app_feedback_test.dart`

Expected: FAIL with actual elevation 10 and bottom margin 18.

- [ ] **Step 3: Apply the shared values**

```dart
abstract final class AppInsets {
  static const page = EdgeInsets.symmetric(horizontal: AppSpacing.page);
  static const compact = EdgeInsets.all(AppSpacing.md);
  static const component = EdgeInsets.all(AppSpacing.lg);
  static const snackbar = EdgeInsets.fromLTRB(16, 0, 16, 8);
}
```

Set `elevation: 4` in both `AppTheme.light.snackBarTheme` and the `SnackBar` constructed by `AppFeedback.show`.

- [ ] **Step 4: Run feedback tests**

Run: `cd apps/mobile && flutter test test/app_design_tokens_test.dart test/app_feedback_test.dart test/mobile_feedback_consistency_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the snackbar adjustment**

```bash
git add apps/mobile/lib/src/core/theme/app_design_tokens.dart apps/mobile/lib/src/core/theme/app_theme.dart apps/mobile/lib/src/core/widgets/app_feedback.dart apps/mobile/test/app_design_tokens_test.dart apps/mobile/test/app_feedback_test.dart
git commit -m "fix(mobile): soften shared snackbar presentation"
```

## Task 7: Clear read notification badges immediately and safely

**Files:**
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add a failing successful-read result test**

```dart
testWidgets('successful section read returns the read section', (tester) async {
  NotificationSection? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await Navigator.of(context).push<NotificationSection>(
            MaterialPageRoute(
              builder: (_) => NotificationSectionsPage(
                initialSection: NotificationSection.system,
                loadNotifications: (_) async => const [],
                markSectionRead: (_) async {},
              ),
            ),
          );
        },
        child: const Text('Open'),
      ),
    ),
  ));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
  await tester.pumpAndSettle();

  expect(result, NotificationSection.system);
});
```

- [ ] **Step 2: Add a failing read-error test**

```dart
testWidgets('failed section read keeps the page open and allows retry',
    (tester) async {
  var shouldFail = true;
  await tester.pumpWidget(MaterialApp(
    home: NotificationSectionsPage(
      initialSection: NotificationSection.system,
      loadNotifications: (_) async => const [],
      markSectionRead: (_) async {
        if (shouldFail) throw Exception('offline');
      },
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
  await tester.pump();

  expect(find.text('System Notifications'), findsOneWidget);
  expect(
    find.text('Could not mark notifications as read. Please try again.'),
    findsOneWidget,
  );

  shouldFail = false;
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
  await tester.pumpAndSettle();
  expect(find.text('System Notifications'), findsNothing);
});
```

- [ ] **Step 3: Add a failing ChatPage immediate-badge test**

```dart
testWidgets('confirmed read clears shortcut and shell badge before refresh',
    (tester) async {
  final refreshCounts = Completer<Map<NotificationSection, int>>();
  var loads = 0;
  final badgeCounts = <int>[];
  await tester.pumpWidget(MaterialApp(
    home: ChatPage(
      loadConversations: () async => const [],
      loadCounts: () {
        loads += 1;
        if (loads == 1) {
          return Future.value(const {NotificationSection.system: 1});
        }
        return refreshCounts.future;
      },
      onBadgeCountChanged: badgeCounts.add,
      openNotificationSection: (_, section) async => section,
    ),
  ));
  await tester.pumpAndSettle();
  expect(badgeCounts.last, 1);

  await tester.tap(find.text('System'));
  await tester.pump();

  expect(badgeCounts.last, 0);
  expect(find.text('1'), findsNothing);
  refreshCounts.complete(const {NotificationSection.system: 0});
  await tester.pumpAndSettle();
  expect(badgeCounts.last, 0);
});
```

- [ ] **Step 4: Run the focused notification tests and confirm failure**

Run: `cd apps/mobile && flutter test test/chat_widgets_test.dart --plain-name "notification"`

Expected: FAIL because the page returns `true`, swallows read failures, and waits for a full reload.

- [ ] **Step 5: Return the section only after a successful RPC**

Move `_markedRead = true` to after the injected/repository marker succeeds. In `_close`, show the shared error and reset `_isClosing` on failure; do not pop. On success, call:

```dart
setState(() => _allowPop = true);
Navigator.of(context).pop(_section);
```

- [ ] **Step 6: Add an injectable opener and guarded home-load generation**

Define:

```dart
typedef NotificationSectionOpener = Future<NotificationSection?> Function(
  BuildContext context,
  NotificationSection section,
);
```

Add it as an optional `ChatPage` constructor dependency. Track `_latestHomeState` and `_homeLoadGeneration`; each `_load` captures its generation and only publishes cached state/badge callbacks when still current.

- [ ] **Step 7: Apply the confirmed read locally before background refresh**

```dart
void _applySectionReadLocally(NotificationSection section) {
  final counts = Map<NotificationSection, int>.of(_latestHomeState.counts)
    ..[section] = 0;
  final next = _ChatHomeState(
    conversations: _latestHomeState.conversations,
    counts: counts,
  );
  _homeLoadGeneration += 1;
  _latestHomeState = next;
  _cachedCounts = counts;
  setState(() => _future = Future.value(next));
  widget.onBadgeCountChanged?.call(
    ChatRepository.bottomChatBadgeCount(
      notificationCounts: counts,
      conversations: next.conversations,
    ),
  );
  unawaited(_saveCountsCache(counts));
}
```

After `_openNotifications` receives a non-null section, call this method synchronously and then `unawaited(_refresh(includeEligiblePeople: false))`.

- [ ] **Step 8: Run chat and repository tests**

Run: `cd apps/mobile && flutter test test/chat_widgets_test.dart test/chat_refresh_coordinator_test.dart test/chat_repository_test.dart`

Expected: PASS, including immediate zero counts and preserved badges after read failure.

- [ ] **Step 9: Commit the notification-state fix**

```bash
git add apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart apps/mobile/lib/src/features/chat/presentation/chat_page.dart apps/mobile/test/chat_widgets_test.dart
git commit -m "fix(mobile): reconcile read notification badges immediately"
```

## Task 8: Correct Firebase Admin deployment credentials

**Files:**
- Modify: `docs/setup.md`
- External configuration: Firebase Console project `fyp040605`
- External configuration: Vercel API project for `services/api`
- External verification: Supabase `push_deliveries`

- [ ] **Step 1: Add the project-matching diagnostic to setup documentation**

Add this text under the Vercel push configuration section:

```markdown
### Firebase credential mismatch recovery

`messaging/mismatched-credential` means the Firebase Admin service account and
the Android registration token belong to different Firebase projects. CyanZone
Android is registered with Firebase project `fyp040605`. Set
`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` from
one service-account JSON created in that project, preserve the private key's
newline escapes, and redeploy the API. Never commit or print the credential.

After redeployment, generate fresh Chat, System, and Follower events and confirm
their newest `push_deliveries` rows are `delivered` with `success_count > 0`.
```

- [ ] **Step 2: Verify documentation contains no credentials**

Run: `rg -n "BEGIN PRIVATE KEY|private_key_id|firebase-adminsdk.*@" docs services/api/.env.example`

Expected: only documented placeholders/examples; no real private key, private-key ID, or production service-account address.

- [ ] **Step 3: Commit the diagnostic runbook**

```bash
git add docs/setup.md
git commit -m "docs: add Firebase credential mismatch recovery"
```

- [ ] **Step 4: Pause for explicit authorization before changing cloud secrets**

Request confirmation immediately before opening the Firebase service-account screen or replacing Vercel environment values. Do not display secret values in chat, terminal output, screenshots, or commits.

- [ ] **Step 5: Replace the deployed Firebase Admin variables and redeploy**

In Firebase Console, select `fyp040605` and generate/select a Firebase Admin service account. In the Vercel API project, replace `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` for Preview and Production with fields from that one credential. Trigger a fresh API deployment.

- [ ] **Step 6: Verify API health and physical delivery**

Confirm `/health` is online. With two physical Android accounts, create one Chat, one System, and one Follower event while the recipient app is in the background or normally terminated. Do not force-stop the app.

Run this read-only Supabase query after the events:

```sql
select event_type, status, success_count, failure_count, error, updated_at
from public.push_deliveries
order by updated_at desc
limit 20;
```

Expected: the three new events are `delivered`, each has `success_count > 0`, and none has `messaging/mismatched-credential`.

## Task 9: Full regression and database rollout

**Files:**
- Verify all modified mobile, SQL, API-documentation, and plan files.

- [ ] **Step 1: Format all changed Dart files**

Run: `cd apps/mobile && dart format lib test`

Expected: formatter exits successfully.

- [ ] **Step 2: Run static analysis**

Run: `cd apps/mobile && flutter analyze`

Expected: `No issues found!`.

- [ ] **Step 3: Run the complete Flutter test suite**

Run: `cd apps/mobile && flutter test`

Expected: all tests pass.

- [ ] **Step 4: Run API tests to ensure deployment configuration documentation did not mask a server regression**

Run: `cd services/api && npm test`

Expected: all Node tests pass.

- [ ] **Step 5: Review the complete branch diff for secrets and unrelated files**

Run: `git diff --check origin/main...HEAD` and `git status --short`.

Expected: no whitespace errors, no secret files, and no unrelated working-tree changes.

- [ ] **Step 6: Apply the Supabase name migration after the preflight returns zero rows**

Run the documented preflight query. If it returns any row, stop and correct that data deliberately. If it returns zero rows, run the complete `supabase/profile_name_policy.sql`, then verify:

```sql
select conname, convalidated
from pg_constraint
where conrelid = 'public.profiles'::regclass
  and conname = 'profiles_name_length_check';
```

Expected: one row with `convalidated = true`.

- [ ] **Step 7: Perform the device matrix**

On the original phone and the taller phone, test Android navigation keys and full-screen gestures. Inspect Home, Profile, Messages, System notifications, a nested page, and an active chat. Confirm bottom surfaces reach the physical edge, controls remain clear of system UI, no gray strip grows with screen height, snackbars have a softer shadow and smaller gap, and System badges clear after the first exit.

- [ ] **Step 8: Build the release APK only after all verification passes**

Run: `cd apps/mobile && flutter build apk --release`

Expected: `build/app/outputs/flutter-apk/app-release.apk` is produced successfully.

- [ ] **Step 9: Commit any formatting-only changes caused by the verified formatter**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "style(mobile): format reliability fixes"
```

Skip this commit when `git status --short` shows no formatter changes.
