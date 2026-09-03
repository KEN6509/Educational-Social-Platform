import 'dart:async';

import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/location_service.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/sos_tracking_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  SosAlert alert({SosStatus status = SosStatus.open}) => SosAlert(
        id: 'sos-1',
        childId: 'child-1',
        status: status,
        location: const LocationCapture.unavailable('initial_unavailable'),
        createdAt: DateTime.utc(2026, 9, 3, 7),
      );

  LocationCapture point({double latitude = 2.03454}) =>
      LocationCapture.available(
        latitude: latitude,
        longitude: 103.29548,
        accuracyMeters: 8,
        capturedAt: DateTime.utc(2026, 9, 3, 7, 1),
      );

  test('start captures immediately and schedules ten-second updates', () async {
    final repository = _FakeRepository(activeAlert: alert());
    final locations = _FakeLocationService([point()]);
    final schedule = _FakeSchedule();
    final coordinator = SosTrackingCoordinator(
      repository: repository,
      locationService: locations,
      schedule: schedule,
    );

    await coordinator.start(alert());

    expect(locations.captureCount, 1);
    expect(repository.uploadedLocations, hasLength(1));
    expect(schedule.interval, const Duration(seconds: 10));
    expect(coordinator.snapshot.isRunning, isTrue);
    expect(coordinator.snapshot.latestLocation?.latitude, 2.03454);
  });

  test('ticks never overlap an in-flight location capture', () async {
    final pendingCapture = Completer<LocationCapture>();
    final repository = _FakeRepository(activeAlert: alert());
    final locations = _FakeLocationService([], pending: pendingCapture.future);
    final schedule = _FakeSchedule();
    final coordinator = SosTrackingCoordinator(
      repository: repository,
      locationService: locations,
      schedule: schedule,
    );

    final start = coordinator.start(alert());
    await Future<void>.delayed(Duration.zero);
    schedule.tick();
    schedule.tick();
    expect(locations.captureCount, 1);

    pendingCapture.complete(point());
    await start;
    expect(repository.uploadedLocations, hasLength(1));
  });

  test('failed upload retains the point and retries it before recapturing',
      () async {
    final repository = _FakeRepository(
      activeAlert: alert(),
      remainingUploadFailures: 1,
    );
    final locations = _FakeLocationService([point()]);
    final schedule = _FakeSchedule();
    final coordinator = SosTrackingCoordinator(
      repository: repository,
      locationService: locations,
      schedule: schedule,
    );

    await coordinator.start(alert());
    expect(coordinator.snapshot.hasPendingUpload, isTrue);

    schedule.tick();
    await Future<void>.delayed(Duration.zero);
    expect(repository.uploadAttempts, 2);
    expect(locations.captureCount, 1);
    expect(coordinator.snapshot.hasPendingUpload, isFalse);
  });

  test('background pauses and foreground recovers an active SOS', () async {
    final repository = _FakeRepository(activeAlert: alert());
    final locations = _FakeLocationService([point(), point(latitude: 2.04)]);
    final schedule = _FakeSchedule();
    final coordinator = SosTrackingCoordinator(
      repository: repository,
      locationService: locations,
      schedule: schedule,
    );

    await coordinator.start(alert());
    coordinator.onBackground();
    expect(schedule.isRunning, isFalse);
    expect(coordinator.snapshot.isRunning, isFalse);

    await coordinator.onForeground();
    expect(repository.fetchActiveCount, 1);
    expect(schedule.isRunning, isTrue);
    expect(locations.captureCount, 2);
  });

  test('resolved realtime refresh stops tracking and dispose cleans up',
      () async {
    final repository = _FakeRepository(activeAlert: alert());
    final schedule = _FakeSchedule();
    final coordinator = SosTrackingCoordinator(
      repository: repository,
      locationService: _FakeLocationService([point()]),
      schedule: schedule,
    );
    await coordinator.start(alert());

    repository.activeAlert = null;
    repository.emitRealtimeChange();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.snapshot.isRunning, isFalse);
    expect(schedule.isRunning, isFalse);
    expect(repository.unsubscribeCount, 1);

    coordinator.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(schedule.isRunning, isFalse);
  });
}

final class _FakeSchedule implements SosTrackingSchedule {
  Duration? interval;
  void Function()? callback;
  bool isRunning = false;

  @override
  void start(Duration interval, void Function() onTick) {
    this.interval = interval;
    callback = onTick;
    isRunning = true;
  }

  @override
  void stop() {
    isRunning = false;
  }

  void tick() {
    if (isRunning) callback?.call();
  }
}

final class _FakeLocationService implements LocationService {
  _FakeLocationService(this.locations, {this.pending});

  final List<LocationCapture> locations;
  final Future<LocationCapture>? pending;
  int captureCount = 0;

  @override
  Future<LocationCapture> capture() {
    captureCount += 1;
    if (pending != null) return pending!;
    return Future.value(locations.removeAt(0));
  }
}

final class _FakeRepository implements ParentChildRepositoryContract {
  _FakeRepository({
    required this.activeAlert,
    this.remainingUploadFailures = 0,
  });

  final SupabaseClient client = SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
  );
  SosAlert? activeAlert;
  int remainingUploadFailures;
  int fetchActiveCount = 0;
  int uploadAttempts = 0;
  int unsubscribeCount = 0;
  final List<LocationCapture> uploadedLocations = [];
  void Function()? onRealtimeChange;

  @override
  Future<SosAlert?> fetchActiveSos() async {
    fetchActiveCount += 1;
    return activeAlert;
  }

  @override
  Future<SosLiveLocation> updateSosLocation(
    String sosId,
    LocationCapture location,
  ) async {
    uploadAttempts += 1;
    if (remainingUploadFailures > 0) {
      remainingUploadFailures -= 1;
      throw StateError('upload failed');
    }
    uploadedLocations.add(location);
    return SosLiveLocation(
      sosId: sosId,
      childId: 'child-1',
      latitude: location.latitude!,
      longitude: location.longitude!,
      accuracyMeters: location.accuracyMeters!,
      capturedAt: location.capturedAt!,
      updatedAt: location.capturedAt!,
    );
  }

  @override
  RealtimeChannel subscribeToSosDetailChanges({
    required String sosId,
    required void Function() onChange,
  }) {
    onRealtimeChange = onChange;
    return client.channel('test-$sosId');
  }

  @override
  Future<void> unsubscribe(RealtimeChannel channel) async {
    unsubscribeCount += 1;
  }

  void emitRealtimeChange() => onRealtimeChange?.call();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
