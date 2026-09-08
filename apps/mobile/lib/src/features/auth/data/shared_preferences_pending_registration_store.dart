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
