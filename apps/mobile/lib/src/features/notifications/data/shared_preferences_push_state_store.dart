import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/push_destination.dart';

class SharedPreferencesPushStateStore {
  static const _installationIdKey = 'notifications.push.installation_id';
  static const _promptShownKey = 'notifications.push.prompt_shown';
  static const _pushEnabledKey = 'notifications.push.enabled';
  static const _pendingDestinationKey =
      'notifications.push.pending_destination';

  Future<String> installationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final value = 'cz_${base64UrlEncode(bytes)}';
    await preferences.setString(_installationIdKey, value);
    return value;
  }

  Future<bool> promptWasShown() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_promptShownKey) ?? false;
  }

  Future<void> markPromptShown() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_promptShownKey, true);
  }

  Future<bool> pushEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_pushEnabledKey) ?? false;
  }

  Future<void> setPushEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_pushEnabledKey, value);
  }

  Future<void> savePendingDestination(PushDestination destination) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingDestinationKey,
      jsonEncode(destination.toData()),
    );
  }

  Future<PushDestination?> readPendingDestination() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pendingDestinationKey);
    if (raw == null) return null;
    try {
      return PushDestination.tryParse(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingDestination() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingDestinationKey);
  }
}
