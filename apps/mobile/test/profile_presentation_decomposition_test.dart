import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _presentationPath = 'lib/src/features/profile/presentation';

String _read(String name) =>
    File('$_presentationPath/$name').readAsStringSync();

void _expectClasses(String source, Iterable<String> classNames) {
  for (final className in classNames) {
    expect(source, contains('class $className'),
        reason: '$className is missing');
  }
}

void _expectOwnerDoesNotContainClasses(
  String source,
  Iterable<String> classNames,
) {
  for (final className in classNames) {
    expect(
      source,
      isNot(contains('class $className')),
      reason: '$className still belongs to the page file',
    );
    expect(
      source,
      isNot(contains('class ${className}Legacy')),
      reason: '$className was renamed instead of extracted',
    );
  }
}

void main() {
  test('Profile page delegates header presentation', () {
    final page = _read('profile_page.dart');
    final header = _read('profile_header_widgets.dart');
    const classes = [
      '_ProfileHeader',
      '_ProfileSkeleton',
      '_ProfileLoadError',
      '_StatItem',
      '_ProfileActionButton',
      '_SliverAppBarDelegate',
    ];

    expect(page, contains("part 'profile_header_widgets.dart';"));
    expect(header, contains("part of 'profile_page.dart';"));
    _expectClasses(header, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, contains('class _ProfilePageState'));
    expect(page, contains('Future<void> _loadData()'));
    expect(page, contains('Future<void> _refreshProfile()'));
    expect(page, contains('Future<void> _toggleFollow()'));
  });

  test('Profile page delegates post-grid presentation', () {
    final page = _read('profile_page.dart');
    final grid = _read('profile_post_grid.dart');
    const classes = [
      '_ProfilePostGrid',
      '_ProfilePostGridState',
      '_ProfileGridError',
    ];

    expect(page, contains("part 'profile_post_grid.dart';"));
    expect(grid, contains("part of 'profile_page.dart';"));
    expect(grid, contains('enum _ProfilePostGridMode'));
    _expectClasses(grid, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, isNot(contains('enum _ProfilePostGridMode')));
    expect(grid, contains('PostInteractionSync.latest.addListener'));
    expect(grid, contains('PostInteractionSync.latest.removeListener'));
    expect(grid, contains('orderProfilePosts('));
  });

  test('Edit Profile delegates detailed widgets', () {
    final page = _read('edit_profile_page.dart');
    final widgets = _read('edit_profile_widgets.dart');
    const classes = [
      '_EditProfileBody',
      '_EditProfileAvatar',
      '_EditProfileInput',
      '_EditProfileLoadError',
    ];

    expect(page, contains("part 'edit_profile_widgets.dart';"));
    expect(widgets, contains("part of 'edit_profile_page.dart';"));
    _expectClasses(widgets, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, contains('Future<void> _pickImage()'));
    expect(page, contains('Future<void> _saveProfile()'));
    expect(page, contains('Future<void> _checkConnection()'));
  });

  test('Follow Lists delegate detailed widgets', () {
    final page = _read('follow_list_page.dart');
    final widgets = _read('follow_list_widgets.dart');
    const classes = [
      '_FollowListSkeleton',
      '_FollowListError',
      '_FollowSkeletonBlock',
      '_FollowTile',
      '_SmallFollowButton',
    ];

    expect(page, contains("part 'follow_list_widgets.dart';"));
    expect(widgets, contains("part of 'follow_list_page.dart';"));
    _expectClasses(widgets, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, contains('class _FollowListState'));
  });

  test('Settings delegates presentation widgets', () {
    final page = _read('settings_page.dart');
    final widgets = _read('settings_widgets.dart');
    const classes = [
      '_SettingsSectionHeader',
      '_SettingsSection',
      '_SettingsTile',
    ];

    expect(page, contains("part 'settings_widgets.dart';"));
    expect(widgets, contains("part of 'settings_page.dart';"));
    _expectClasses(widgets, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, contains('Future<void> _confirmLogout()'));
  });

  test('Notification Settings delegates presentation widgets', () {
    final page = _read('notification_settings_page.dart');
    final widgets = _read('notification_settings_widgets.dart');
    const classes = [
      '_SectionHeader',
      '_SettingsGroup',
      '_SettingsDivider',
      '_PreferenceSwitch',
    ];

    expect(page, contains("part 'notification_settings_widgets.dart';"));
    expect(widgets, contains("part of 'notification_settings_page.dart';"));
    _expectClasses(widgets, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, contains('class _NotificationPreferenceState'));
    expect(page, contains('Future<void> _updatePreference('));
  });

  test('Verified Badge delegates presentation widgets', () {
    final page = _read('verified_badge_page.dart');
    final widgets = _read('verified_badge_widgets.dart');
    const classes = [
      '_BadgePageBody',
      '_VerificationBottomAction',
      '_Requirement',
      '_StatusNotice',
      '_LoadError',
    ];

    expect(page, contains("part 'verified_badge_widgets.dart';"));
    expect(widgets, contains("part of 'verified_badge_page.dart';"));
    _expectClasses(widgets, classes);
    _expectOwnerDoesNotContainClasses(page, classes);
    expect(page, contains('class _VerifiedBadgePageState'));
    expect(page, contains('Future<void> _submit('));
  });

  test('Phase 5B profile presentation uses the shared feedback facade', () {
    final offenders = <String>[];

    for (final entity in Directory(_presentationPath).listSync()) {
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

  test('Phase 5B files use shared tokens for exact design values', () {
    const files = [
      'profile_page.dart',
      'profile_header_widgets.dart',
      'profile_post_grid.dart',
      'edit_profile_page.dart',
      'edit_profile_widgets.dart',
      'follow_list_page.dart',
      'follow_list_widgets.dart',
      'settings_page.dart',
      'settings_widgets.dart',
      'notification_settings_page.dart',
      'notification_settings_widgets.dart',
      'verified_badge_page.dart',
      'verified_badge_widgets.dart',
    ];
    const rawValues = [
      'Color(0xFF4490AD)',
      'Color(0xFF0B1F3E)',
      'Color(0xFF64748B)',
      'Color(0xFF94A3B8)',
      'Color(0xFFE2E8F0)',
      'Color(0xFFF1F5F9)',
      'Color(0xFFE11D48)',
    ];
    final offenders = <String>[];

    for (final file in files) {
      final source = _read(file);
      for (final value in rawValues) {
        if (source.contains(value)) offenders.add('$file: $value');
      }
    }

    expect(offenders, isEmpty);
  });

  test('Pure profile presentation parts do not access data services', () {
    const pureParts = [
      'profile_header_widgets.dart',
      'edit_profile_widgets.dart',
      'follow_list_widgets.dart',
      'settings_widgets.dart',
      'notification_settings_widgets.dart',
      'verified_badge_widgets.dart',
    ];
    final offenders = <String>[];

    for (final file in pureParts) {
      final source = _read(file);
      if (source.contains('Supabase.instance') ||
          source.contains('ProfileRepository(') ||
          source.contains('PostsRepository(')) {
        offenders.add(file);
      }
    }

    expect(offenders, isEmpty);
  });
}
