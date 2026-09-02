import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending link does not establish role before acceptance', () {
    final state = SupervisionDashboardState.fromParts(
      currentUserId: 'child-1',
      links: [
        FamilyLink.fromMap({
          'id': 'link-1',
          'parent_id': 'parent-1',
          'child_id': 'child-1',
          'requested_by': 'parent-1',
          'status': 'pending',
          'created_at': '2026-08-02T08:00:00Z',
        }),
      ],
      ownScreenTime: ScreenTimeSummary.zero('child-1', DateTime(2026, 8, 2)),
      notifications: const [],
    );

    expect(state.role, isNull);
    expect(state.activeLinkCount, 0);
    expect(state.canUseSafetyActions, isFalse);
  });

  test('active same-role links are counted and mixed roles are rejected', () {
    FamilyLink link(String id, String parentId, String childId) =>
        FamilyLink.fromMap({
          'id': id,
          'parent_id': parentId,
          'child_id': childId,
          'requested_by': parentId,
          'status': 'active',
          'created_at': '2026-08-02T08:00:00Z',
        });

    final parentState = SupervisionDashboardState.fromParts(
      currentUserId: 'parent-1',
      links: [
        link('one', 'parent-1', 'child-1'),
        link('two', 'parent-1', 'child-2'),
      ],
      ownScreenTime: ScreenTimeSummary.zero('parent-1', DateTime(2026, 8, 2)),
      notifications: const [],
    );
    expect(parentState.role, FamilyRole.parent);
    expect(parentState.activeLinkCount, 2);

    expect(
      () => SupervisionDashboardState.fromParts(
        currentUserId: 'parent-1',
        links: [
          link('one', 'parent-1', 'child-1'),
          link('conflict', 'other-parent', 'parent-1'),
        ],
        ownScreenTime: ScreenTimeSummary.zero('parent-1', DateTime(2026, 8, 2)),
        notifications: const [],
      ),
      throwsStateError,
    );
  });

  test('dashboard keeps only the ten newest supervision notifications', () {
    final notifications = List.generate(
      12,
      (index) => SupervisionNotification.fromMap({
        'id': 'event-$index',
        'event_type': 'link_request',
        'title': 'Request $index',
        'body': 'Body',
        'link_id': 'link-$index',
        'created_at': DateTime.utc(2026, 8, 2, 0, index).toIso8601String(),
      }),
    );

    final state = SupervisionDashboardState.fromParts(
      currentUserId: 'user-1',
      links: const [],
      ownScreenTime: ScreenTimeSummary.zero('user-1', DateTime(2026, 8, 2)),
      notifications: notifications,
    );

    expect(state.notifications, hasLength(10));
    expect(state.notifications.first.id, 'event-11');
    expect(state.notifications.last.id, 'event-2');
  });

  test('cancelled links and unavailable SOS locations parse safely', () {
    final link = FamilyLink.fromMap({
      'id': 'link-1',
      'parent_id': 'parent-1',
      'child_id': 'child-1',
      'requested_by': 'parent-1',
      'status': 'cancelled',
      'created_at': '2026-08-02T08:00:00Z',
      'cancelled_at': '2026-08-02T08:05:00Z',
    });
    final sos = SosAlert.fromMap({
      'id': 'sos-1',
      'child_id': 'child-1',
      'status': 'open',
      'location_status': 'unavailable',
      'location_failure': 'permission_denied',
      'created_at': '2026-08-02T08:00:00Z',
    });

    expect(link.status, FamilyLinkStatus.cancelled);
    expect(link.cancelledAt, isNotNull);
    expect(sos.hasLocation, isFalse);
    expect(sos.location.failureCode, 'permission_denied');
  });

  test('active link tracks a pending unlink request without ending the role',
      () {
    final link = FamilyLink.fromMap({
      'id': 'link-1',
      'parent_id': 'parent-1',
      'child_id': 'child-1',
      'requested_by': 'parent-1',
      'status': 'active',
      'created_at': '2026-08-02T08:00:00Z',
      'unlink_requested_by': 'child-1',
      'unlink_requested_at': '2026-08-02T08:10:00Z',
    });
    final state = SupervisionDashboardState.fromParts(
      currentUserId: 'child-1',
      links: [link],
      ownScreenTime: ScreenTimeSummary.zero('child-1', DateTime(2026, 8, 2)),
      notifications: const [],
    );

    expect(link.hasPendingUnlinkRequest, isTrue);
    expect(link.unlinkRequestedBy, 'child-1');
    expect(link.unlinkRequestedAt, isNotNull);
    expect(state.role, FamilyRole.child);
    expect(state.activeLinkCount, 1);
  });

  test('unknown server enum values fail fast', () {
    expect(
      () => SupervisionNotification.fromMap({
        'id': 'event-1',
        'event_type': 'unexpected',
        'title': 'Unexpected',
        'body': 'Unexpected',
        'created_at': '2026-08-02T08:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
