import 'dart:async';

import 'package:cyanzone_mobile/src/core/application/async_refresh_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces scheduled requests inside the debounce window', () async {
    var refreshCount = 0;
    final coordinator = AsyncRefreshCoordinator(
      debounce: const Duration(milliseconds: 10),
      refresh: () async {
        refreshCount += 1;
      },
    );

    coordinator.schedule();
    coordinator.schedule();
    coordinator.schedule();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(refreshCount, 1);
    coordinator.dispose();
  });

  test('serializes refreshes and allows one trailing refresh', () async {
    final firstRefresh = Completer<void>();
    var refreshCount = 0;
    var activeRefreshes = 0;
    var maximumActiveRefreshes = 0;
    final coordinator = AsyncRefreshCoordinator(
      debounce: Duration.zero,
      refresh: () async {
        refreshCount += 1;
        activeRefreshes += 1;
        maximumActiveRefreshes = activeRefreshes > maximumActiveRefreshes
            ? activeRefreshes
            : maximumActiveRefreshes;
        if (refreshCount == 1) await firstRefresh.future;
        activeRefreshes -= 1;
      },
    );

    final cycle = coordinator.refreshNow();
    await Future<void>.delayed(Duration.zero);
    coordinator.refreshNow();
    coordinator.refreshNow();

    expect(refreshCount, 1);
    firstRefresh.complete();
    await cycle;

    expect(refreshCount, 2);
    expect(maximumActiveRefreshes, 1);
    coordinator.dispose();
  });

  test('serializes a refresh request behind the initial page load', () async {
    final initialRefresh = Completer<void>();
    var refreshCount = 0;
    var activeRefreshes = 1;
    var maximumActiveRefreshes = 1;
    final coordinator = AsyncRefreshCoordinator(
      refresh: () async {
        refreshCount += 1;
        activeRefreshes += 1;
        maximumActiveRefreshes = activeRefreshes > maximumActiveRefreshes
            ? activeRefreshes
            : maximumActiveRefreshes;
        activeRefreshes -= 1;
      },
    );

    coordinator.trackInitialRefresh(initialRefresh.future.whenComplete(() {
      activeRefreshes -= 1;
    }));
    final cycle = coordinator.refreshNow();
    await Future<void>.delayed(Duration.zero);

    expect(refreshCount, 0);
    initialRefresh.complete();
    await cycle;

    expect(refreshCount, 1);
    expect(maximumActiveRefreshes, 1);
    coordinator.dispose();
  });

  test('immediate refresh cancels a pending debounce', () async {
    var refreshCount = 0;
    final coordinator = AsyncRefreshCoordinator(
      debounce: const Duration(milliseconds: 20),
      refresh: () async {
        refreshCount += 1;
      },
    );

    coordinator.schedule();
    await coordinator.refreshNow();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(refreshCount, 1);
    coordinator.dispose();
  });

  test('dispose cancels delayed and future refresh work', () async {
    var refreshCount = 0;
    final coordinator = AsyncRefreshCoordinator(
      debounce: const Duration(milliseconds: 10),
      refresh: () async {
        refreshCount += 1;
      },
    );

    coordinator.schedule();
    coordinator.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await coordinator.refreshNow();

    expect(refreshCount, 0);
  });

  test('a failed refresh does not prevent the next refresh', () async {
    var refreshCount = 0;
    final errors = <Object>[];
    final coordinator = AsyncRefreshCoordinator(
      refresh: () async {
        refreshCount += 1;
        if (refreshCount == 1) throw StateError('temporary failure');
      },
      onError: (error, _) => errors.add(error),
    );

    await coordinator.refreshNow();
    await coordinator.refreshNow();

    expect(refreshCount, 2);
    expect(errors, hasLength(1));
    coordinator.dispose();
  });
}
