import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled services become an unavailable capture', () async {
    final result = await GeolocatorLocationService(
      platform: FakeLocationPlatform(serviceEnabled: false),
    ).capture();
    expect(result.status, LocationStatus.unavailable);
    expect(result.failureCode, 'services_disabled');
  });

  test('permission denial becomes an unavailable capture', () async {
    final result = await GeolocatorLocationService(
      platform: FakeLocationPlatform(
        permission: LocationPermissionState.denied,
        requestedPermission: LocationPermissionState.denied,
      ),
    ).capture();
    expect(result.failureCode, 'permission_denied');
  });

  test('permanent permission denial is distinguished', () async {
    final result = await GeolocatorLocationService(
      platform: FakeLocationPlatform(
        permission: LocationPermissionState.deniedForever,
      ),
    ).capture();
    expect(result.failureCode, 'permission_denied_forever');
  });

  test('successful capture preserves coordinates and accuracy', () async {
    final capturedAt = DateTime.utc(2026, 8, 2, 8);
    final result = await GeolocatorLocationService(
      platform: FakeLocationPlatform(
        position: PlatformPosition(
          latitude: 3.139,
          longitude: 101.6869,
          accuracyMeters: 8,
          capturedAt: capturedAt,
        ),
      ),
    ).capture();
    expect(result.status, LocationStatus.available);
    expect(result.latitude, 3.139);
    expect(result.longitude, 101.6869);
    expect(result.accuracyMeters, 8);
    expect(result.capturedAt, capturedAt);
  });

  test('platform failures become capture_failed', () async {
    final result = await GeolocatorLocationService(
      platform: FakeLocationPlatform(error: Exception('gps failed')),
    ).capture();
    expect(result.failureCode, 'capture_failed');
  });
}

final class FakeLocationPlatform implements LocationPlatform {
  FakeLocationPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermissionState.whileInUse,
    this.requestedPermission = LocationPermissionState.whileInUse,
    this.position,
    this.error,
  });

  final bool serviceEnabled;
  final LocationPermissionState permission;
  final LocationPermissionState requestedPermission;
  final PlatformPosition? position;
  final Object? error;

  @override
  Future<LocationPermissionState> checkPermission() async => permission;

  @override
  Future<PlatformPosition> getCurrentPosition() async {
    if (error != null) throw error!;
    return position ??
        PlatformPosition(
          latitude: 3,
          longitude: 101,
          accuracyMeters: 10,
          capturedAt: DateTime.utc(2026, 8, 2),
        );
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionState> requestPermission() async =>
      requestedPermission;
}
