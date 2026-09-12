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
