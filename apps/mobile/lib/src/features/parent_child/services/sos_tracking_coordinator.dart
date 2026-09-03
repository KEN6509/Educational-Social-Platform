import 'dart:async';

import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/domain/sos_lifecycle_state.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SosTrackingSchedule {
  void start(Duration interval, void Function() onTick);
  void stop();
}

final class TimerSosTrackingSchedule implements SosTrackingSchedule {
  Timer? _timer;

  @override
  void start(Duration interval, void Function() onTick) {
    stop();
    _timer = Timer.periodic(interval, (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

final class SosTrackingSnapshot {
  const SosTrackingSnapshot({
    this.alert,
    this.latestLocation,
    this.isRunning = false,
    this.hasPendingUpload = false,
    this.lastError,
  });

  final SosAlert? alert;
  final SosLiveLocation? latestLocation;
  final bool isRunning;
  final bool hasPendingUpload;
  final Object? lastError;
}

final class SosTrackingCoordinator extends ChangeNotifier {
  SosTrackingCoordinator({
    required ParentChildRepositoryContract repository,
    required LocationService locationService,
    SosTrackingSchedule? schedule,
  })  : _repository = repository,
        _locationService = locationService,
        _schedule = schedule ?? TimerSosTrackingSchedule();

  static const trackingInterval = Duration(seconds: 10);

  final ParentChildRepositoryContract _repository;
  final LocationService _locationService;
  final SosTrackingSchedule _schedule;

  SosAlert? _alert;
  SosLiveLocation? _latestLocation;
  LocationCapture? _pendingLocation;
  RealtimeChannel? _channel;
  Object? _lastError;
  bool _foreground = true;
  bool _captureInFlight = false;
  bool _disposed = false;

  SosTrackingSnapshot get snapshot => SosTrackingSnapshot(
        alert: _alert,
        latestLocation: _latestLocation,
        isRunning: _foreground &&
            _alert != null &&
            sosLifecycleStateFor(_alert!.status).trackingAllowed,
        hasPendingUpload: _pendingLocation != null,
        lastError: _lastError,
      );

  Future<void> start(SosAlert alert) async {
    if (_disposed) return;
    if (!sosLifecycleStateFor(alert.status).trackingAllowed) {
      await stop();
      return;
    }

    _foreground = true;
    _alert = alert;
    _lastError = null;
    await _replaceSubscription(alert.id);
    _schedule.start(trackingInterval, () => unawaited(_captureAndUpload()));
    _notify();
    await _captureAndUpload();
  }

  Future<void> onForeground() async {
    if (_disposed) return;
    _foreground = true;
    try {
      final activeAlert = await _repository.fetchActiveSos();
      if (activeAlert == null) {
        await stop();
        return;
      }
      await start(activeAlert);
    } catch (error) {
      _lastError = error;
      _notify();
    }
  }

  void onBackground() {
    if (_disposed) return;
    _foreground = false;
    _schedule.stop();
    _notify();
  }

  Future<void> stop() async {
    _schedule.stop();
    final channel = _channel;
    _channel = null;
    _alert = null;
    _pendingLocation = null;
    if (channel != null) {
      await _repository.unsubscribe(channel);
    }
    _notify();
  }

  Future<void> _captureAndUpload() async {
    final alert = _alert;
    if (_disposed ||
        !_foreground ||
        alert == null ||
        _captureInFlight ||
        !sosLifecycleStateFor(alert.status).trackingAllowed) {
      return;
    }

    _captureInFlight = true;
    try {
      final pending = _pendingLocation;
      if (pending != null) {
        await _upload(alert.id, pending);
        return;
      }

      final captured = await _locationService.capture();
      if (_alert?.id != alert.id || !_foreground) return;
      if (captured.status != LocationStatus.available) {
        _lastError = captured.failureCode ?? 'location_unavailable';
        _notify();
        return;
      }
      _pendingLocation = captured;
      await _upload(alert.id, captured);
    } catch (error) {
      if (_alert?.id == alert.id) {
        _lastError = error;
        _notify();
      }
    } finally {
      _captureInFlight = false;
    }
  }

  Future<void> _upload(String sosId, LocationCapture location) async {
    try {
      final uploaded = await _repository.updateSosLocation(sosId, location);
      if (_alert?.id != sosId) return;
      _latestLocation = uploaded;
      _pendingLocation = null;
      _lastError = null;
      _notify();
    } catch (_) {
      _pendingLocation = location;
      rethrow;
    }
  }

  Future<void> _replaceSubscription(String sosId) async {
    final previous = _channel;
    if (previous != null) {
      await _repository.unsubscribe(previous);
    }
    if (_disposed || _alert?.id != sosId) return;
    _channel = _repository.subscribeToSosDetailChanges(
      sosId: sosId,
      onChange: () => unawaited(_refreshFromServer()),
    );
  }

  Future<void> _refreshFromServer() async {
    if (_disposed) return;
    try {
      final activeAlert = await _repository.fetchActiveSos();
      if (activeAlert == null || activeAlert.status == SosStatus.resolved) {
        await stop();
        return;
      }
      _alert = activeAlert;
      _notify();
    } catch (error) {
      _lastError = error;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _schedule.stop();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_repository.unsubscribe(channel));
    }
    super.dispose();
  }
}
