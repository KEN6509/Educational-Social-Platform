import 'dart:io';

import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/screen_time_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('main shell owns foreground tracker lifecycle', () {
    final source = File(
      'lib/src/features/shell/presentation/main_shell.dart',
    ).readAsStringSync();
    expect(source, contains('ForegroundScreenTimeTracker? _screenTimeTracker'));
    expect(source, contains('_screenTimeTracker?.onResumed()'));
    expect(source, contains('_screenTimeTracker?.onPaused()'));
    expect(source, contains('_screenTimeTracker?.flush()'));
    expect(source, contains('_screenTimeTracker?.dispose()'));
  });

  test('pause persists and synchronizes one foreground interval', () async {
    SharedPreferences.setMockInitialValues({});
    final clock = FakeClock(DateTime(2026, 8, 2, 8));
    final synced = <ScreenTimeSession>[];
    final tracker = await ForegroundScreenTimeTracker.create(
      userId: 'user-1',
      sync: (session) async {
        synced.add(session);
        return const ScreenTimeSyncResult(
          dailySeconds: 300,
          nextThresholdHours: 3,
          applied: true,
        );
      },
      now: clock.call,
      startCheckpointTimer: false,
    );

    tracker.onResumed();
    clock.advance(const Duration(minutes: 5));
    await tracker.onPaused();

    expect(synced, hasLength(1));
    expect(synced.single.secondsUsed, 300);
    expect(tracker.pendingSessionCount, 0);
  });

  test('failed sync survives restart and retries once', () async {
    SharedPreferences.setMockInitialValues({});
    final clock = FakeClock(DateTime(2026, 8, 2, 8));
    var shouldFail = true;
    var successfulSyncs = 0;

    Future<ScreenTimeSyncResult> sync(ScreenTimeSession session) async {
      if (shouldFail) throw Exception('offline');
      successfulSyncs += 1;
      return const ScreenTimeSyncResult(
        dailySeconds: 300,
        nextThresholdHours: 3,
        applied: true,
      );
    }

    final tracker = await ForegroundScreenTimeTracker.create(
      userId: 'user-1',
      sync: sync,
      now: clock.call,
      startCheckpointTimer: false,
    );
    tracker.onResumed();
    clock.advance(const Duration(minutes: 5));
    await tracker.onPaused();
    expect(tracker.pendingSessionCount, 1);

    shouldFail = false;
    final restarted = await ForegroundScreenTimeTracker.create(
      userId: 'user-1',
      sync: sync,
      now: clock.call,
      startCheckpointTimer: false,
    );
    expect(restarted.pendingSessionCount, 1);
    await restarted.flush();
    expect(restarted.pendingSessionCount, 0);
    expect(successfulSyncs, 1);
  });

  test('duplicate lifecycle calls do not double count', () async {
    SharedPreferences.setMockInitialValues({});
    final clock = FakeClock(DateTime(2026, 8, 2, 8));
    final synced = <ScreenTimeSession>[];
    final tracker = await ForegroundScreenTimeTracker.create(
      userId: 'user-1',
      sync: (session) async {
        synced.add(session);
        return const ScreenTimeSyncResult(
          dailySeconds: 60,
          nextThresholdHours: 3,
          applied: true,
        );
      },
      now: clock.call,
      startCheckpointTimer: false,
    );

    tracker.onResumed();
    tracker.onResumed();
    clock.advance(const Duration(minutes: 1));
    await tracker.onPaused();
    await tracker.onPaused();

    expect(synced, hasLength(1));
    expect(synced.single.secondsUsed, 60);
  });
}

final class FakeClock {
  FakeClock(this.value);
  DateTime value;
  DateTime call() => value;
  void advance(Duration duration) => value = value.add(duration);
}
