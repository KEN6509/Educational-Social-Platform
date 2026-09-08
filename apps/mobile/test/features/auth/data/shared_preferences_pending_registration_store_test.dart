import 'package:cyanzone_mobile/src/features/auth/data/shared_preferences_pending_registration_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
