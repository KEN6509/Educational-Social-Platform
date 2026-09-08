import 'dart:collection';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pending_moderation_retry.dart';

typedef CurrentUserIdReader = String? Function();

final class SharedPreferencesPendingModerationRetryStore
    implements PendingModerationRetryStore {
  SharedPreferencesPendingModerationRetryStore({
    required this.currentUserId,
  });

  static const _keyPrefix = 'pending_moderation_targets_v1';

  final CurrentUserIdReader currentUserId;

  @override
  Future<List<PendingModerationTarget>> load() async {
    final key = _currentKey();
    if (key == null) return const [];
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(key) ?? const <String>[])
        .map(PendingModerationTarget.tryParse)
        .whereType<PendingModerationTarget>()
        .toList(growable: false);
  }

  @override
  Future<void> save(PendingModerationTarget target) async {
    final key = _currentKey();
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    final values = LinkedHashSet<String>.from(
      preferences.getStringList(key) ?? const <String>[],
    )..add(target.storageValue);
    await preferences.setStringList(key, values.toList(growable: false));
  }

  @override
  Future<void> remove(PendingModerationTarget target) async {
    final key = _currentKey();
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    final values = List<String>.from(
      preferences.getStringList(key) ?? const <String>[],
    )..removeWhere((value) => value == target.storageValue);
    await preferences.setStringList(key, values);
  }

  String? _currentKey() {
    final userId = currentUserId()?.trim();
    if (userId == null || userId.isEmpty) return null;
    return '$_keyPrefix:$userId';
  }
}
