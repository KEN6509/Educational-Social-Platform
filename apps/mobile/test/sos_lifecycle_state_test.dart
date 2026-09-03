import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/domain/sos_lifecycle_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a live location and adapts it to a shared location capture', () {
    final location = SosLiveLocation.fromMap({
      'sos_id': 'sos-1',
      'child_id': 'child-1',
      'latitude': 2.03454,
      'longitude': 103.29548,
      'accuracy_meters': 9.5,
      'captured_at': '2026-09-03T07:01:00Z',
      'updated_at': '2026-09-03T07:01:01Z',
    });

    final capture = location.toLocationCapture();
    expect(location.sosId, 'sos-1');
    expect(location.updatedAt, DateTime.utc(2026, 9, 3, 7, 1, 1));
    expect(capture.status, LocationStatus.available);
    expect(capture.latitude, 2.03454);
    expect(capture.longitude, 103.29548);
    expect(capture.accuracyMeters, 9.5);
  });

  test('SOS detail sorts timeline events and finds a parent acknowledgement',
      () {
    final alert = SosAlert.fromMap({
      'id': 'sos-1',
      'child_id': 'child-1',
      'status': 'acknowledged',
      'location_status': 'unavailable',
      'created_at': '2026-09-03T07:00:00Z',
    });
    SosEvent event({
      required String id,
      required String type,
      required String actorId,
      required String actorName,
      required String createdAt,
    }) =>
        SosEvent.fromMap({
          'id': id,
          'sos_id': 'sos-1',
          'event_type': type,
          'actor_id': actorId,
          'actor_name': actorName,
          'created_at': createdAt,
        });

    final detail = SosDetail(
      alert: alert,
      events: [
        event(
          id: 'event-2',
          type: 'acknowledged',
          actorId: 'parent-1',
          actorName: 'Parent One',
          createdAt: '2026-09-03T07:02:00Z',
        ),
        event(
          id: 'event-1',
          type: 'triggered',
          actorId: 'child-1',
          actorName: 'Child One',
          createdAt: '2026-09-03T07:00:00Z',
        ),
      ],
    );

    expect(detail.events.map((event) => event.id), ['event-1', 'event-2']);
    expect(detail.hasAcknowledgementFrom('parent-1'), isTrue);
    expect(detail.hasAcknowledgementFrom('parent-2'), isFalse);
  });

  test('lifecycle State objects enforce tracking and parent action rules', () {
    expect(
      const OpenSosState().actionFor(hasCurrentParentAcknowledged: false),
      SosParentAction.acknowledge,
    );
    expect(
      const AcknowledgedSosState()
          .actionFor(hasCurrentParentAcknowledged: false),
      SosParentAction.acknowledge,
    );
    expect(
      const AcknowledgedSosState()
          .actionFor(hasCurrentParentAcknowledged: true),
      SosParentAction.resolve,
    );
    expect(
      const ResolvedSosState().actionFor(hasCurrentParentAcknowledged: true),
      SosParentAction.none,
    );
    expect(const ResolvedSosState().trackingAllowed, isFalse);
    expect(sosLifecycleStateFor(SosStatus.open), isA<OpenSosState>());
    expect(
      sosLifecycleStateFor(SosStatus.acknowledged),
      isA<AcknowledgedSosState>(),
    );
    expect(sosLifecycleStateFor(SosStatus.resolved), isA<ResolvedSosState>());
  });
}
