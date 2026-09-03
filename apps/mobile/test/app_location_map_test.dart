import 'package:cyanzone_mobile/src/core/widgets/app_location_map.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LocationCapture location(double latitude, double longitude) =>
      LocationCapture.available(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: 12,
        capturedAt: DateTime.utc(2026, 9, 3, 7),
      );

  testWidgets('renders fixed marker and OpenStreetMap attribution',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppLocationMap(
            location: location(2.03454, 103.29548),
            mode: AppLocationMapMode.fixed,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('app-location-map')), findsOneWidget);
    expect(find.byKey(const Key('app-location-marker')), findsOneWidget);
    expect(find.byKey(const Key('app-location-attribution')), findsOneWidget);
    expect(find.text('flutter_map | © '), findsOneWidget);
    expect(find.text('OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('live marker receives rebuilt coordinates', (tester) async {
    Widget build(LocationCapture value) => MaterialApp(
          home: Scaffold(
            body: AppLocationMap(
              location: value,
              mode: AppLocationMapMode.live,
            ),
          ),
        );

    await tester.pumpWidget(build(location(2.03454, 103.29548)));
    var marker =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
    expect(marker.point.latitude, 2.03454);
    expect(marker.point.longitude, 103.29548);

    await tester.pumpWidget(build(location(2.035, 103.296)));
    marker =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
    expect(marker.point.latitude, 2.035);
    expect(marker.point.longitude, 103.296);
  });
}
