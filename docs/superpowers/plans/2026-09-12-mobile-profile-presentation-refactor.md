# Mobile Profile Presentation Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose CyanZone's mobile profile presentation into focused,
reusable units and standardize its temporary feedback without changing current
profile behaviour or visual layout.

**Architecture:** Stateful pages remain workflow and data coordinators.
Cohesive private widgets move into feature-local Dart part files so privacy and
existing constructors remain intact. Existing repositories, caches, injected
strategies, navigation, and post-interaction observers remain authoritative.

**Tech Stack:** Flutter/Dart, Supabase Flutter, SharedPreferences, existing
CyanZone repositories, caches, design tokens, confirmation dialog, and feedback
facade.

---

## Execution Constraints

- Work on the existing `refactor/mobile-architecture-optimization` branch in
  the original CyanZone directory. Do not create a Git worktree.
- Use test-driven changes: add or strengthen a failing structural or behaviour
  regression before each production extraction.
- Do not change public navigation routes or remove existing constructor
  parameters.
- Do not change Supabase SQL, policies, RPCs, storage rules, API contracts, the
  Administration Portal, or the deployed API.
- Do not introduce Riverpod or another dependency.
- Do not refactor `set_password_page.dart`; it belongs to Phase 5C.
- Preserve all current text, post ordering, caching, optimistic updates,
  rollback, message eligibility, and visual dimensions.
- Replace raw design values only when the existing token has the exact same
  value.
- Defer device/manual testing until every Phase 5 checkpoint is complete.

## Planned File Structure

### Phase 5B.1

- `profile_page.dart`: profile workflow, lifecycle, repositories, caches,
  navigation, refresh signals, and follow coordination.
- `profile_header_widgets.dart`: profile header, stats, actions, loading/error
  presentation, and tab-header delegate.
- `profile_post_grid.dart`: profile-grid state, cache integration,
  post-interaction observer, and grid presentation.
- `edit_profile_page.dart`: edit workflow, controllers, connectivity, image
  selection/upload, persistence, and navigation result.
- `edit_profile_widgets.dart`: edit body, avatar editor, inputs, and persistent
  load error.
- `follow_list_page.dart`: tabs, search, repository ownership, list future,
  optimistic follow coordination, and navigation.
- `follow_list_widgets.dart`: rows, buttons, skeleton blocks, empty and error
  presentation.

### Phase 5B.2

- `settings_page.dart`: settings navigation and logout workflow.
- `settings_widgets.dart`: settings section and tile presentation.
- `notification_settings_page.dart`: preference state, load, optimistic save,
  rollback, and push coordinator interaction.
- `notification_settings_widgets.dart`: settings groups, dividers, labels, and
  preference switches.
- `verified_badge_page.dart`: verification data state, input ownership,
  submission, and retry coordination.
- `verified_badge_widgets.dart`: requirements, notices, body, bottom action,
  and persistent load error.
- `profile_presentation_decomposition_test.dart`: structural ownership,
  dependency direction, and direct-feedback audits.

---

### Task 1: Establish the Phase 5B structural regression gate

**Files:**

- Create: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Verify: `apps/mobile/lib/src/features/profile/presentation/*.dart`

- [ ] **Step 1: Verify the existing branch and baseline**

Run from `apps/mobile`:

```powershell
git branch --show-current
git status --short
flutter test test/profile_message_action_test.dart test/profile_repository_test.dart test/user_profile_test.dart test/post_collection_order_test.dart test/post_interaction_sync_test.dart test/settings_page_test.dart test/verified_badge_page_test.dart test/app_feedback_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter expanded
flutter analyze --no-pub
```

Expected: branch is `refactor/mobile-architecture-optimization`, Git is clean,
all selected tests pass, and analysis reports no issues.

- [ ] **Step 2: Add failing decomposition contracts**

Create `profile_presentation_decomposition_test.dart` with file-level helpers
and these initial tests:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String name) => File(
      'lib/src/features/profile/presentation/$name',
    ).readAsStringSync();

void main() {
  test('Profile page delegates header presentation', () {
    final page = _read('profile_page.dart');
    expect(page, contains("part 'profile_header_widgets.dart';"));
    expect(File('lib/src/features/profile/presentation/'
            'profile_header_widgets.dart').existsSync(), isTrue);
    expect(page, contains('class _ProfilePageState'));
    expect(page, isNot(contains('class _ProfileHeader')));
  });

  test('Profile page delegates post-grid presentation', () {
    final page = _read('profile_page.dart');
    expect(page, contains("part 'profile_post_grid.dart';"));
    expect(File('lib/src/features/profile/presentation/'
            'profile_post_grid.dart').existsSync(), isTrue);
    expect(page, contains('class _ProfilePageState'));
    expect(page, isNot(contains('class _ProfilePostGrid')));
  });

  test('Edit Profile delegates detailed widgets', () {
    final edit = _read('edit_profile_page.dart');
    expect(edit, contains("part 'edit_profile_widgets.dart';"));
    expect(edit, isNot(contains('class _EditProfileLoadError')));
  });

  test('Follow Lists delegate detailed widgets', () {
    final follows = _read('follow_list_page.dart');
    expect(follows, contains("part 'follow_list_widgets.dart';"));
    expect(follows, isNot(contains('class _FollowTile')));
  });

  test('Settings delegates presentation widgets', () {
    expect(
      _read('settings_page.dart'),
      contains("part 'settings_widgets.dart';"),
    );
  });

  test('Notification Settings delegates presentation widgets', () {
    expect(
      _read('notification_settings_page.dart'),
      contains("part 'notification_settings_widgets.dart';"),
    );
  });

  test('Verified Badge delegates presentation widgets', () {
    expect(
      _read('verified_badge_page.dart'),
      contains("part 'verified_badge_widgets.dart';"),
    );
  });
}
```

- [ ] **Step 3: Run the structural test and verify the expected failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL because none of the Phase 5B part files exists yet.

- [ ] **Step 4: Commit the failing regression gate**

```powershell
git add apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "test(mobile): define profile presentation boundaries"
```

---

### Task 2: Extract Profile header and page-state presentation

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/profile_header_widgets.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`

- [ ] **Step 1: Strengthen the failing header ownership contract**

Extend the Profile header test:

```dart
final header = _read('profile_header_widgets.dart');
expect(header, contains("part of 'profile_page.dart';"));
expect(header, contains('class _ProfileHeader'));
expect(header, contains('class _ProfileSkeleton'));
expect(header, contains('class _ProfileLoadError'));
expect(header, contains('class _StatItem'));
expect(header, contains('class _ProfileActionButton'));
expect(header, contains('class _SliverAppBarDelegate'));
expect(page, contains('Future<void> _loadData()'));
expect(page, contains('Future<void> _refreshProfile()'));
expect(page, contains('Future<void> _toggleFollow()'));
```

- [ ] **Step 2: Run the targeted test and verify it fails**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Profile page delegates header presentation"
```

Expected: FAIL because `profile_header_widgets.dart` does not exist.

- [ ] **Step 3: Add the part and move the exact private widgets**

Add after the imports in `profile_page.dart`:

```dart
part 'profile_header_widgets.dart';
```

Create the part with:

```dart
part of 'profile_page.dart';
```

Move these existing implementations byte-for-byte before formatting:

- `_ProfileHeader`;
- `_ProfileSkeleton`;
- `_ProfileLoadError`;
- `_StatItem`;
- `_ProfileActionButton`; and
- `_SliverAppBarDelegate`.

Keep `ProfilePage`, `_ProfilePageState`, `_ProfilePostGridMode`,
`_ProfilePostGrid`, `_ProfilePostGridState`, and `_ProfileGridError` in
`profile_page.dart` during this checkpoint. Do not move navigation or follow
logic into a widget.

- [ ] **Step 4: Format and run focused regressions**

```powershell
dart format lib/src/features/profile/presentation/profile_page.dart lib/src/features/profile/presentation/profile_header_widgets.dart test/profile_presentation_decomposition_test.dart
flutter test test/profile_presentation_decomposition_test.dart test/profile_message_action_test.dart --no-pub --reporter expanded
```

Expected: the header assertions pass; the overall decomposition test may still
fail only on later part files.

- [ ] **Step 5: Commit the Profile header extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/profile_page.dart apps/mobile/lib/src/features/profile/presentation/profile_header_widgets.dart apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract profile header widgets"
```

---

### Task 3: Extract Profile post-grid state and presentation

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/profile_post_grid.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Verify: `apps/mobile/test/post_collection_order_test.dart`
- Verify: `apps/mobile/test/post_interaction_sync_test.dart`
- Verify: `apps/mobile/test/feed_post_test.dart`

- [ ] **Step 1: Add the failing post-grid ownership assertions**

Extend the Profile post-grid test:

```dart
final grid = _read('profile_post_grid.dart');
expect(grid, contains("part of 'profile_page.dart';"));
expect(grid, contains('enum _ProfilePostGridMode'));
expect(grid, contains('class _ProfilePostGrid'));
expect(grid, contains('class _ProfilePostGridState'));
expect(grid, contains('class _ProfileGridError'));
expect(grid, contains('PostInteractionSync.latest.addListener'));
expect(grid, contains('PostInteractionSync.latest.removeListener'));
expect(grid, contains('orderProfilePosts('));
expect(page, isNot(contains('class _ProfileGridError')));
```

- [ ] **Step 2: Run and verify the expected failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Profile page delegates post-grid presentation"
```

Expected: FAIL because the post-grid types remain in `profile_page.dart`.

- [ ] **Step 3: Add the post-grid part and move its cohesive block**

Add to `profile_page.dart`:

```dart
part 'profile_post_grid.dart';
```

Create:

```dart
part of 'profile_page.dart';
```

Move these existing implementations unchanged:

- `_ProfilePostGridMode`;
- `_ProfilePostGrid`;
- `_ProfilePostGridState`; and
- `_ProfileGridError`.

The moved state remains the sole owner of its future, in-memory post list,
posted-post cache, SharedPreferences cache, connectivity check, ratio
preloading, image cache requests, and `PostInteractionSync.latest` listener.
Do not alter `orderProfilePosts`, saved/liked repository order, deletion
filtering, the five-second timeout, or listener disposal.

- [ ] **Step 4: Run the ordering and interaction regressions**

```powershell
dart format lib/src/features/profile/presentation/profile_page.dart lib/src/features/profile/presentation/profile_post_grid.dart test/profile_presentation_decomposition_test.dart
flutter test test/profile_presentation_decomposition_test.dart test/post_collection_order_test.dart test/post_interaction_sync_test.dart test/feed_post_test.dart --no-pub --reporter expanded
```

Expected: all selected tests pass except structural tests for later Phase 5B
files.

- [ ] **Step 5: Commit the Profile grid extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/profile_page.dart apps/mobile/lib/src/features/profile/presentation/profile_post_grid.dart apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "refactor(mobile): separate profile post grid"
```

---

### Task 4: Extract Edit Profile presentation widgets

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/edit_profile_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/edit_profile_widgets.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`

- [ ] **Step 1: Add the failing Edit Profile boundary assertions**

Extend the Edit Profile test:

```dart
final editWidgets = _read('edit_profile_widgets.dart');
expect(editWidgets, contains("part of 'edit_profile_page.dart';"));
expect(editWidgets, contains('class _EditProfileBody'));
expect(editWidgets, contains('class _EditProfileAvatar'));
expect(editWidgets, contains('class _EditProfileInput'));
expect(editWidgets, contains('class _EditProfileLoadError'));
expect(edit, contains('Future<void> _pickImage()'));
expect(edit, contains('Future<void> _saveProfile()'));
expect(edit, contains('Future<void> _checkConnection()'));
```

- [ ] **Step 2: Run and verify the expected failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Edit Profile delegates detailed widgets"
```

Expected: FAIL because `edit_profile_widgets.dart` and its widgets do not
exist.

- [ ] **Step 3: Add the part and extract immutable edit presentation**

Add to `edit_profile_page.dart`:

```dart
part 'edit_profile_widgets.dart';
```

Create the part with:

```dart
part of 'edit_profile_page.dart';
```

Move `_EditProfileLoadError` unchanged. Replace the state method
`_buildModernInput` with a private stateless `_EditProfileInput` that receives
the same label, controller, hint, maximum lines, and maximum length. Extract
the avatar stack into `_EditProfileAvatar` with these immutable inputs:

```dart
const _EditProfileAvatar({
  required this.profile,
  required this.selectedImage,
  required this.onTap,
});
```

Extract the connected form column into `_EditProfileBody`:

```dart
const _EditProfileBody({
  required this.profile,
  required this.selectedImage,
  required this.nameController,
  required this.bioController,
  required this.onPickImage,
});
```

Keep the Scaffold, AppBar, loading/error selection, controllers, image picker,
crop navigation, temporary file, upload, repository call, and navigation result
inside `_EditProfilePageState`. Preserve all current sizes, labels,
formatters, and counter alignment.

- [ ] **Step 4: Format and run the focused structural gate**

```powershell
dart format lib/src/features/profile/presentation/edit_profile_page.dart lib/src/features/profile/presentation/edit_profile_widgets.dart test/profile_presentation_decomposition_test.dart
flutter test test/profile_presentation_decomposition_test.dart test/user_profile_test.dart test/profile_repository_test.dart --no-pub --reporter expanded
```

Expected: Edit Profile assertions pass; later support-page assertions may
remain red.

- [ ] **Step 5: Commit the Edit Profile extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/edit_profile_page.dart apps/mobile/lib/src/features/profile/presentation/edit_profile_widgets.dart apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract edit profile widgets"
```

---

### Task 5: Extract Follow List presentation widgets

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/follow_list_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/follow_list_widgets.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Verify: `apps/mobile/test/profile_repository_test.dart`

- [ ] **Step 1: Add failing Follow List boundary assertions**

Extend the Follow Lists test:

```dart
final followWidgets = _read('follow_list_widgets.dart');
expect(followWidgets, contains("part of 'follow_list_page.dart';"));
expect(followWidgets, contains('class _FollowListSkeleton'));
expect(followWidgets, contains('class _FollowListError'));
expect(followWidgets, contains('class _FollowSkeletonBlock'));
expect(followWidgets, contains('class _FollowTile'));
expect(followWidgets, contains('class _SmallFollowButton'));
expect(follows, contains('class _FollowListState'));
expect(follows, isNot(contains('class _FollowListSkeleton')));
```

- [ ] **Step 2: Run and verify the expected failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Follow Lists delegate detailed widgets"
```

Expected: FAIL because the pure Follow List widgets remain in the page.

- [ ] **Step 3: Move only pure Follow List presentation**

Add:

```dart
part 'follow_list_widgets.dart';
```

Create:

```dart
part of 'follow_list_page.dart';
```

Move these implementations unchanged:

- `_FollowListSkeleton`;
- `_FollowListError`;
- `_FollowSkeletonBlock`;
- `_FollowTile`; and
- `_SmallFollowButton`.

Keep `_FollowList`, `_FollowListState`, its future, search filtering, optimistic
row replacement, repository callback, rollback, and profile navigation in
`follow_list_page.dart`. Keep the repository `created_at DESC` order and do not
sort search results independently.

- [ ] **Step 4: Format and run Follow List regressions**

```powershell
dart format lib/src/features/profile/presentation/follow_list_page.dart lib/src/features/profile/presentation/follow_list_widgets.dart test/profile_presentation_decomposition_test.dart
flutter test test/profile_presentation_decomposition_test.dart test/profile_repository_test.dart test/profile_message_action_test.dart --no-pub --reporter expanded
```

Expected: all Phase 5B.1 structural assertions and selected behaviour tests
pass; Phase 5B.2 structural assertions remain red.

- [ ] **Step 5: Commit the Follow List extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/follow_list_page.dart apps/mobile/lib/src/features/profile/presentation/follow_list_widgets.dart apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract follow list widgets"
```

---

### Task 6: Complete the Phase 5B.1 automated checkpoint

**Files:**

- Verify: all Phase 5B.1 production and test files
- Modify only if a verified Phase 5B.1 regression is found

- [ ] **Step 1: Run the complete core-profile suite**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Profile page delegates header presentation"
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Profile page delegates post-grid presentation"
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Edit Profile delegates detailed widgets"
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Follow Lists delegate detailed widgets"
flutter test test/profile_message_action_test.dart test/profile_repository_test.dart test/user_profile_test.dart test/post_collection_order_test.dart test/post_interaction_sync_test.dart test/feed_post_test.dart test/feed_card_test.dart test/posts_repository_test.dart --no-pub --reporter expanded
```

Expected: all four Phase 5B.1 structural tests and the selected core-profile
and post behaviour tests pass. Phase 5B.2 structural tests are intentionally
not run at this checkpoint.

- [ ] **Step 2: Run analysis and strict formatting for Phase 5B.1 files**

```powershell
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib/src/features/profile/presentation/profile_page.dart lib/src/features/profile/presentation/profile_header_widgets.dart lib/src/features/profile/presentation/profile_post_grid.dart lib/src/features/profile/presentation/edit_profile_page.dart lib/src/features/profile/presentation/edit_profile_widgets.dart lib/src/features/profile/presentation/follow_list_page.dart lib/src/features/profile/presentation/follow_list_widgets.dart test/profile_presentation_decomposition_test.dart
git diff --check
```

Expected: no analyzer issues, no formatting changes, and no whitespace errors.

- [ ] **Step 3: Record only verified corrective work**

If a regression is found, first add a focused failing assertion, verify the
failure, make the smallest correction, rerun the focused suite, and commit:

```powershell
git add apps/mobile
git commit -m "fix(mobile): close core profile refactor gap"
```

Do not create an empty commit when no correction is required.

---

### Task 7: Extract Settings presentation widgets

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/settings_widgets.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Verify: `apps/mobile/test/settings_page_test.dart`

- [ ] **Step 1: Add failing Settings ownership assertions**

Extend the Settings test:

```dart
final settings = _read('settings_page.dart');
final widgets = _read('settings_widgets.dart');
expect(widgets, contains("part of 'settings_page.dart';"));
expect(widgets, contains('class _SettingsSectionHeader'));
expect(widgets, contains('class _SettingsSection'));
expect(widgets, contains('class _SettingsTile'));
expect(settings, contains('Future<void> _confirmLogout()'));
expect(settings, isNot(contains('class _SettingsTile')));
```

- [ ] **Step 2: Run and verify the expected failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Settings delegates presentation widgets"
```

Expected: FAIL because the Settings part does not exist.

- [ ] **Step 3: Extract Settings sections and tiles**

Add to `settings_page.dart`:

```dart
part 'settings_widgets.dart';
```

Create:

```dart
part of 'settings_page.dart';
```

Move `_SettingsTile` unchanged. Convert `_buildSectionHeader` and
`_buildSection` into immutable `_SettingsSectionHeader` and `_SettingsSection`
widgets with the same padding, margin, colours, radius, shadow, and child
ordering. Replace only the call sites; keep navigation and `_confirmLogout`
inside the page state.

- [ ] **Step 4: Run Settings regressions**

```powershell
dart format lib/src/features/profile/presentation/settings_page.dart lib/src/features/profile/presentation/settings_widgets.dart test/profile_presentation_decomposition_test.dart
flutter test test/settings_page_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter expanded
```

Expected: Verified Badge navigation, Notification navigation and persistence,
logout cancellation, single sign-out, and failed logout tests all pass.

- [ ] **Step 5: Commit the Settings extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/settings_page.dart apps/mobile/lib/src/features/profile/presentation/settings_widgets.dart apps/mobile/test/profile_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract settings widgets"
```

---

### Task 8: Extract Notification Settings presentation widgets

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/notification_settings_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/notification_settings_widgets.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Modify: `apps/mobile/test/settings_page_test.dart`

- [ ] **Step 1: Add a failing rollback regression**

Add this import to `settings_page_test.dart`:

```dart
import 'package:cyanzone_mobile/src/features/profile/presentation/notification_settings_page.dart';
```

Then add:

```dart
testWidgets('failed notification save restores the previous switch value',
    (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationSettingsPage(
        loadNotificationPreferences: () async => const {
          'in_app_enabled': true,
          'push_enabled': false,
          'chat_enabled': true,
          'activity_enabled': true,
          'system_enabled': true,
          'followers_enabled': true,
        },
        saveNotificationPreferences: (_) async => throw Exception('offline'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final inApp = find.widgetWithText(SwitchListTile, 'In-app notifications');
  await tester.tap(inApp);
  await tester.pumpAndSettle();

  expect(tester.widget<SwitchListTile>(inApp).value, isTrue);
  expect(find.text('Could not update notification setting.'), findsOneWidget);
});
```

This test documents the current optimistic rollback before presentation moves.
It may already pass; if so, retain it as a characterization test and continue
to the failing structural assertion.

- [ ] **Step 2: Add failing Notification Settings ownership assertions**

Extend the Notification Settings test:

```dart
final notifications = _read('notification_settings_page.dart');
final notificationWidgets = _read('notification_settings_widgets.dart');
expect(notificationWidgets,
    contains("part of 'notification_settings_page.dart';"));
expect(notificationWidgets, contains('class _SectionHeader'));
expect(notificationWidgets, contains('class _SettingsGroup'));
expect(notificationWidgets, contains('class _SettingsDivider'));
expect(notificationWidgets, contains('class _PreferenceSwitch'));
expect(notifications, contains('class _NotificationPreferenceState'));
expect(notifications, contains('Future<void> _updatePreference('));
expect(notifications, isNot(contains('class _PreferenceSwitch')));
```

- [ ] **Step 3: Run and verify the structural failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Notification Settings delegates presentation widgets"
```

Expected: FAIL because the notification widgets remain in the page.

- [ ] **Step 4: Move only immutable notification presentation**

Add:

```dart
part 'notification_settings_widgets.dart';
```

Create:

```dart
part of 'notification_settings_page.dart';
```

Move `_SectionHeader`, `_SettingsGroup`, `_SettingsDivider`, and
`_PreferenceSwitch` unchanged. Keep `_NotificationPreferenceState`,
`_preferencesFuture`, `_loadPreferences`, and `_updatePreference` in the page
file. Preserve optimistic state assignment before saving, push enable/disable
handling, and rollback to `current` on every failure.

- [ ] **Step 5: Format and run notification regressions**

```powershell
dart format lib/src/features/profile/presentation/notification_settings_page.dart lib/src/features/profile/presentation/notification_settings_widgets.dart test/profile_presentation_decomposition_test.dart test/settings_page_test.dart
flutter test test/settings_page_test.dart test/push_notification_coordinator_test.dart --no-pub --reporter expanded
```

Expected: all Settings and notification preference tests pass.

- [ ] **Step 6: Commit Notification Settings extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/notification_settings_page.dart apps/mobile/lib/src/features/profile/presentation/notification_settings_widgets.dart apps/mobile/test/profile_presentation_decomposition_test.dart apps/mobile/test/settings_page_test.dart
git commit -m "refactor(mobile): extract notification settings widgets"
```

---

### Task 9: Extract Creator Verification presentation widgets

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/verified_badge_page.dart`
- Create: `apps/mobile/lib/src/features/profile/presentation/verified_badge_widgets.dart`
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Modify: `apps/mobile/test/verified_badge_page_test.dart`

- [ ] **Step 1: Add failure and validation characterization tests**

Add to `verified_badge_page_test.dart`:

```dart
testWidgets('empty verification statement shows validation feedback',
    (tester) async {
  await pumpPage(
    tester,
    state: const CreatorVerificationState(),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Apply for verification'));
  await tester.pump();
  expect(
    find.text('Tell us why you would like to be verified.'),
    findsOneWidget,
  );
});

testWidgets('failed verification submission keeps the application available',
    (tester) async {
  await pumpPage(
    tester,
    state: const CreatorVerificationState(),
    submitApplication: (_) async => throw Exception('offline'),
  );
  await tester.enterText(
    find.byKey(const ValueKey('creator-application-statement')),
    'I publish original science lessons.',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Apply for verification'));
  await tester.pumpAndSettle();
  expect(
    find.text('Could not submit your request. Please try again.'),
    findsOneWidget,
  );
  expect(
    find.widgetWithText(FilledButton, 'Apply for verification'),
    findsOneWidget,
  );
});
```

These characterize existing behaviour and may pass before extraction.

- [ ] **Step 2: Add failing Creator Verification ownership assertions**

Extend the Verified Badge test:

```dart
final badge = _read('verified_badge_page.dart');
final badgeWidgets = _read('verified_badge_widgets.dart');
expect(badgeWidgets, contains("part of 'verified_badge_page.dart';"));
expect(badgeWidgets, contains('class _BadgePageBody'));
expect(badgeWidgets, contains('class _VerificationBottomAction'));
expect(badgeWidgets, contains('class _Requirement'));
expect(badgeWidgets, contains('class _StatusNotice'));
expect(badgeWidgets, contains('class _LoadError'));
expect(badge, contains('class _VerifiedBadgePageState'));
expect(badge, contains('Future<void> _submit()'));
expect(badge, isNot(contains('class _BadgePageBody')));
```

- [ ] **Step 3: Run and verify the expected structural failure**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Verified Badge delegates presentation widgets"
```

Expected: FAIL because the creator-verification part does not exist.

- [ ] **Step 4: Move body widgets and extract the bottom action**

Add:

```dart
part 'verified_badge_widgets.dart';
```

Create:

```dart
part of 'verified_badge_page.dart';
```

Move `_BadgePageBody`, `_Requirement`, `_StatusNotice`, and `_LoadError`
unchanged. Extract the current bottom `SafeArea` into:

```dart
class _VerificationBottomAction extends StatelessWidget {
  const _VerificationBottomAction({
    required this.state,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final CreatorVerificationState state;
  final bool isSubmitting;
  final VoidCallback onSubmit;
}
```

Its build method must retain the exact current verified, pending, rejected,
submitting, disabled, label, SafeArea, size, colour, and radius rules. Keep the
FutureBuilders, input controller, load request, status mapping, submission, and
retry inside `_VerifiedBadgePageState`.

- [ ] **Step 5: Format and run creator-verification regressions**

```powershell
dart format lib/src/features/profile/presentation/verified_badge_page.dart lib/src/features/profile/presentation/verified_badge_widgets.dart test/profile_presentation_decomposition_test.dart test/verified_badge_page_test.dart
flutter test test/profile_presentation_decomposition_test.dart test/verified_badge_page_test.dart --no-pub --reporter expanded
```

Expected: every structural test now passes and all creator-verification states
remain unchanged.

- [ ] **Step 6: Commit Creator Verification extraction**

```powershell
git add apps/mobile/lib/src/features/profile/presentation/verified_badge_page.dart apps/mobile/lib/src/features/profile/presentation/verified_badge_widgets.dart apps/mobile/test/profile_presentation_decomposition_test.dart apps/mobile/test/verified_badge_page_test.dart
git commit -m "refactor(mobile): extract verification widgets"
```

---

### Task 10: Standardize profile feedback and exact token matches

**Files:**

- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_message_action.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/edit_profile_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/follow_list_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/notification_settings_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/verified_badge_page.dart`
- Modify: applicable Phase 5B Dart parts containing exact raw token matches
- Modify: `apps/mobile/test/profile_presentation_decomposition_test.dart`
- Verify: `apps/mobile/test/app_feedback_test.dart`

- [ ] **Step 1: Add the failing direct-feedback audit**

Append:

```dart
test('Phase 5B profile presentation uses the shared feedback facade', () {
  final directory = Directory('lib/src/features/profile/presentation');
  final offenders = <String>[];

  for (final entity in directory.listSync()) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('set_password_page.dart')) continue;
    final source = entity.readAsStringSync();
    if (source.contains('ScaffoldMessenger.of(') ||
        source.contains('SnackBar(')) {
      offenders.add(entity.path);
    }
  }

  expect(offenders, isEmpty);
});
```

- [ ] **Step 2: Run the audit and verify the current offenders**

```powershell
flutter test test/profile_presentation_decomposition_test.dart --no-pub --plain-name "Phase 5B profile presentation uses the shared feedback facade"
```

Expected: FAIL and list `profile_page.dart`, `profile_message_action.dart`,
`edit_profile_page.dart`, `follow_list_page.dart`, `settings_page.dart`,
`notification_settings_page.dart`, and `verified_badge_page.dart`.

- [ ] **Step 3: Route temporary messages through `AppFeedback`**

Import where required:

```dart
import '../../../core/widgets/app_feedback.dart';
```

Use these exact mappings while preserving every message string:

- Profile follow rollback: `AppFeedback.showError`.
- Profile message eligibility or open failure: `AppFeedback.showError`.
- Edit Profile save failure: `AppFeedback.showError`.
- Follow List optimistic rollback: `AppFeedback.showError`.
- Settings logout failure: `AppFeedback.showError`.
- Phone notification not enabled: `AppFeedback.showError`.
- Phone notification setting failure: `AppFeedback.showError`.
- General notification setting failure: `AppFeedback.showError`.
- Empty creator statement: `AppFeedback.showError`.
- Creator request submitted: `AppFeedback.showSuccess`.
- Creator submission failure: `AppFeedback.showError`.

Do not modify inline loading/error widgets or `set_password_page.dart`.

- [ ] **Step 4: Replace only exact shared design values**

In files already touched by Phase 5B, use only these exact mappings:

```dart
const Color(0xFF4490AD) -> AppColors.cyan
const Color(0xFF0B1F3E) -> AppColors.navy
const Color(0xFF64748B) -> AppColors.textSecondary
const Color(0xFF94A3B8) -> AppColors.textMuted
const Color(0xFFE2E8F0) -> AppColors.border
const Color(0xFFF1F5F9) -> AppColors.surfaceMuted
const Color(0xFFE11D48) -> AppColors.error
EdgeInsets.all(16) -> EdgeInsets.all(AppSpacing.lg)
EdgeInsets.symmetric(horizontal: 20) -> AppInsets.page
BorderRadius.circular(14) -> BorderRadius.circular(AppRadii.compact)
```

Add `app_design_tokens.dart` to the owning library for Dart parts. Do not
replace nonmatching values such as `0xFF0D2344`, `0xFF1E293B`, `0xFF7A879B`,
`0xFF2C7189`, or layout-specific dimensions. Do not normalize all uses of the
number 16 or 20 when they are sizes rather than approved spacing tokens.

- [ ] **Step 5: Run feedback, profile, settings, and creator regressions**

```powershell
dart format lib/src/features/profile/presentation test/profile_presentation_decomposition_test.dart test/settings_page_test.dart test/verified_badge_page_test.dart
flutter test test/profile_presentation_decomposition_test.dart test/profile_message_action_test.dart test/settings_page_test.dart test/verified_badge_page_test.dart test/app_feedback_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter expanded
```

Expected: no direct snackbar construction outside the deferred password page,
and all existing feedback text remains discoverable in widget tests.

- [ ] **Step 6: Commit shared feedback and exact token migration**

```powershell
git add apps/mobile/lib/src/features/profile/presentation apps/mobile/test/profile_presentation_decomposition_test.dart apps/mobile/test/settings_page_test.dart apps/mobile/test/verified_badge_page_test.dart
git commit -m "refactor(mobile): standardize profile feedback"
```

---

### Task 11: Complete the Phase 5B verification gate

**Files:**

- Verify: all Phase 5B production and test files
- Modify only if a verified regression is found

- [ ] **Step 1: Run the complete related profile suite**

```powershell
flutter test test/profile_presentation_decomposition_test.dart test/profile_message_action_test.dart test/profile_repository_test.dart test/user_profile_test.dart test/post_collection_order_test.dart test/post_interaction_sync_test.dart test/feed_post_test.dart test/feed_card_test.dart test/posts_repository_test.dart test/settings_page_test.dart test/verified_badge_page_test.dart test/push_notification_coordinator_test.dart test/app_feedback_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter expanded
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 2: Run Flutter analysis**

```powershell
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 3: Run strict formatting**

```powershell
dart format --output=none --set-exit-if-changed lib/src/features/profile/presentation/profile_page.dart lib/src/features/profile/presentation/profile_header_widgets.dart lib/src/features/profile/presentation/profile_post_grid.dart lib/src/features/profile/presentation/profile_message_action.dart lib/src/features/profile/presentation/edit_profile_page.dart lib/src/features/profile/presentation/edit_profile_widgets.dart lib/src/features/profile/presentation/follow_list_page.dart lib/src/features/profile/presentation/follow_list_widgets.dart lib/src/features/profile/presentation/settings_page.dart lib/src/features/profile/presentation/settings_widgets.dart lib/src/features/profile/presentation/notification_settings_page.dart lib/src/features/profile/presentation/notification_settings_widgets.dart lib/src/features/profile/presentation/verified_badge_page.dart lib/src/features/profile/presentation/verified_badge_widgets.dart test/profile_presentation_decomposition_test.dart test/settings_page_test.dart test/verified_badge_page_test.dart
```

Expected: zero files changed.

- [ ] **Step 4: Audit structure, feedback exclusions, and dependency direction**

```powershell
rg -n "ScaffoldMessenger\.of|SnackBar\(" lib/src/features/profile/presentation -g "*.dart"
rg -n "part '|part of '" lib/src/features/profile/presentation -g "*.dart"
rg -n "Supabase\.instance|ProfileRepository\(|PostsRepository\(" lib/src/features/profile/presentation/*_widgets.dart lib/src/features/profile/presentation/profile_post_grid.dart
git diff --check
git status --short
```

Expected:

- only `set_password_page.dart` contains direct snackbar construction;
- every new part and owner pair is present;
- pure presentation parts do not construct repositories or access Supabase;
- `profile_post_grid.dart` may access Supabase only for its preserved current
  user interaction-insertion check;
- no whitespace errors; and
- only intentional Phase 5B files are changed before the final commit.

- [ ] **Step 5: Correct only evidence-backed defects**

For any verified defect, add a failing regression first, make the smallest
change, and rerun the focused and complete related suites. Commit corrections:

```powershell
git add apps/mobile
git commit -m "fix(mobile): close profile presentation refactor gap"
```

Do not create an empty commit if no correction is required.

- [ ] **Step 6: Record the deferred manual gate**

Do not claim physical-device verification. Report that the project owner will
manually check own/other profiles, all three post tabs, follow/message actions,
edit/avatar flow, follow lists, settings/logout, notification preferences, and
creator verification after all Phase 5 work is complete.

Phase 5B is complete only when the automated gate passes, the working tree is
clean after commits, and no manual-device claim is made.
