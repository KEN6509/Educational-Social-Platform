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
            'profile_header_widgets.dart')
        .existsSync(), isTrue);
    expect(page, contains('class _ProfilePageState'));
    expect(page, isNot(contains('class _ProfileHeader')));
  });

  test('Profile page delegates post-grid presentation', () {
    final page = _read('profile_page.dart');
    expect(page, contains("part 'profile_post_grid.dart';"));
    expect(File('lib/src/features/profile/presentation/'
            'profile_post_grid.dart')
        .existsSync(), isTrue);
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
