import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/parent_supervision_models.dart';

typedef ScreenTimeSessionSync = Future<ScreenTimeSyncResult> Function(
  ScreenTimeSession session,
);

final class ForegroundScreenTimeTracker {
  ForegroundScreenTimeTracker._({
    required String userId,
    required ScreenTimeSessionSync sync,
    required SharedPreferences preferences,
    required DateTime Function() now,
    required bool startCheckpointTimer,
    required List<ScreenTimeSession> pending,
  })  : _userId = userId,
        _sync = sync,
        _preferences = preferences,
        _now = now,
        _startCheckpointTimer = startCheckpointTimer,
        _pending = pending;

  static Future<ForegroundScreenTimeTracker> create({
    required String userId,
    required ScreenTimeSessionSync sync,
    SharedPreferences? preferences,
    DateTime Function()? now,
    bool startCheckpointTimer = true,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey(userId));
    final pending = <ScreenTimeSession>[];
    if (raw != null) {
      try {
        final items = jsonDecode(raw) as List<dynamic>;
        pending.addAll(items.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return ScreenTimeSession(
            clientSessionId: map['client_session_id'] as String,
            localDay: DateTime.parse(map['local_day'] as String),
            secondsUsed: map['seconds_used'] as int,
            timezoneOffsetMinutes: map['timezone_offset_minutes'] as int,
          );
        }));
      } on FormatException {
        await prefs.remove(_queueKey(userId));
      }
    }
    return ForegroundScreenTimeTracker._(
      userId: userId,
      sync: sync,
      preferences: prefs,
      now: now ?? DateTime.now,
      startCheckpointTimer: startCheckpointTimer,
      pending: pending,
    );
  }

  final String _userId;
  final ScreenTimeSessionSync _sync;
  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final bool _startCheckpointTimer;
  final List<ScreenTimeSession> _pending;
  DateTime? _startedAt;
  Timer? _checkpointTimer;
  bool _flushing = false;

  int get pendingSessionCount => _pending.length;

  void onResumed() {
    if (_startedAt != null) return;
    _startedAt = _now();
    if (_startCheckpointTimer) {
      _checkpointTimer ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(_checkpointAndContinue()),
      );
    }
  }

  Future<void> onPaused() async {
    if (_startedAt == null) return;
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    await _closeCurrentInterval(continueTracking: false);
    await flush();
  }

  Future<void> _checkpointAndContinue() async {
    if (_startedAt == null) return;
    await _closeCurrentInterval(continueTracking: true);
    await flush();
  }

  Future<void> _closeCurrentInterval({required bool continueTracking}) async {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    final endedAt = _now();
    _startedAt = continueTracking ? endedAt : null;
    final seconds = endedAt.difference(startedAt).inSeconds;
    if (seconds < 1) return;

    _pending.add(ScreenTimeSession(
      clientSessionId:
          '$_userId:${startedAt.toUtc().microsecondsSinceEpoch}:${endedAt.toUtc().microsecondsSinceEpoch}',
      localDay: DateTime(startedAt.year, startedAt.month, startedAt.day),
      secondsUsed: seconds.clamp(1, 86400),
      timezoneOffsetMinutes: startedAt.timeZoneOffset.inMinutes,
    ));
    await _persist();
  }

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        try {
          await _sync(_pending.first);
        } catch (_) {
          break;
        }
        _pending.removeAt(0);
        await _persist();
      }
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
  }

  Future<void> _persist() => _preferences.setString(
        _queueKey(_userId),
        jsonEncode(_pending
            .map((session) => {
                  'client_session_id': session.clientSessionId,
                  'local_day': session.localDay.toIso8601String(),
                  'seconds_used': session.secondsUsed,
                  'timezone_offset_minutes': session.timezoneOffsetMinutes,
                })
            .toList()),
      );

  static String _queueKey(String userId) =>
      'parent_supervision_screen_time_queue_$userId';
}
