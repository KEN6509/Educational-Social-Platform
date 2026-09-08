import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../data/parent_supervision_models.dart';

enum LocationPermissionState { denied, deniedForever, whileInUse, always }

final class PlatformPosition {
  const PlatformPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

abstract interface class LocationPlatform {
  Future<bool> isServiceEnabled();
  Future<LocationPermissionState> checkPermission();
  Future<LocationPermissionState> requestPermission();
  Future<PlatformPosition> getCurrentPosition();
}

abstract interface class LocationService {
  Future<LocationCapture> capture();
}

final class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({LocationPlatform? platform})
      : _platform = platform ?? const _GeolocatorPlatform();

  final LocationPlatform _platform;

  @override
  Future<LocationCapture> capture() async {
    try {
      if (!await _platform.isServiceEnabled()) {
        return const LocationCapture.unavailable('services_disabled');
      }

      var permission = await _platform.checkPermission();
      if (permission == LocationPermissionState.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermissionState.denied) {
        return const LocationCapture.unavailable('permission_denied');
      }
      if (permission == LocationPermissionState.deniedForever) {
        return const LocationCapture.unavailable('permission_denied_forever');
      }

      final position = await _platform
          .getCurrentPosition()
          .timeout(const Duration(seconds: 10));
      return LocationCapture.available(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracyMeters,
        capturedAt: position.capturedAt.toUtc(),
      );
    } on TimeoutException {
      return const LocationCapture.unavailable('timeout');
    } catch (_) {
      return const LocationCapture.unavailable('capture_failed');
    }
  }
}

final class _GeolocatorPlatform implements LocationPlatform {
  const _GeolocatorPlatform();

  @override
  Future<LocationPermissionState> checkPermission() async =>
      _mapPermission(await Geolocator.checkPermission());

  @override
  Future<PlatformPosition> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return PlatformPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
    );
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionState> requestPermission() async =>
      _mapPermission(await Geolocator.requestPermission());

  static LocationPermissionState _mapPermission(LocationPermission value) =>
      switch (value) {
        LocationPermission.denied => LocationPermissionState.denied,
        LocationPermission.deniedForever =>
          LocationPermissionState.deniedForever,
        LocationPermission.whileInUse => LocationPermissionState.whileInUse,
        LocationPermission.always => LocationPermissionState.always,
        LocationPermission.unableToDetermine => LocationPermissionState.denied,
      };
}
