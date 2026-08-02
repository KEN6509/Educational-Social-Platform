import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/parent_child_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved unlinked dashboard', (tester) async {
    await _pump(tester, _state(role: null, activeLinks: 0));
    expect(find.text('Parent Supervision'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('My screen time'), findsOneWidget);
    expect(find.text('No active family links yet.'), findsOneWidget);
    expect(find.text('Safety Check-In'), findsNothing);
    expect(find.text('SOS'), findsNothing);
  });

  testWidgets('renders the approved linked child dashboard', (tester) async {
    await _pump(tester, _state(role: FamilyRole.child, activeLinks: 2));
    expect(find.text('Child role · 2 linked parents'), findsOneWidget);
    expect(find.text('Safety Check-In'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
  });

  testWidgets('keeps parent summary cards side by side at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, _state(role: FamilyRole.parent, activeLinks: 2));
    final family = tester.getRect(find.byKey(const Key('family-links-card')));
    final records = tester.getRect(find.byKey(const Key('safety-records-card')));
    expect(family.top, records.top);
    expect(family.width, closeTo(records.width, 0.1));
    expect(find.text('Parent role · 2 linked children'), findsOneWidget);
    expect(find.text('Check-In & SOS records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only ten supervision notifications', (tester) async {
    await _pump(
      tester,
      _state(role: null, activeLinks: 0, notificationCount: 12),
    );
    expect(
      find.byWidgetPredicate((widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>)
              .value
              .startsWith('supervision-notification-tile-')),
      findsNWidgets(10),
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  SupervisionDashboardState state,
) async {
  await tester.pumpWidget(MaterialApp(
    home: ParentChildPage(
      repository: FakeParentChildRepository(state),
      subscribeToRealtime: false,
    ),
  ));
  await tester.pumpAndSettle();
}

SupervisionDashboardState _state({
  required FamilyRole? role,
  required int activeLinks,
  int notificationCount = 0,
}) {
  const currentUserId = 'user-1';
  final links = List.generate(activeLinks, (index) {
    final parentId = role == FamilyRole.parent ? currentUserId : 'parent-$index';
    final childId = role == FamilyRole.child ? currentUserId : 'child-$index';
    return FamilyLink.fromMap({
      'id': 'link-$index',
      'parent_id': parentId,
      'child_id': childId,
      'requested_by': parentId,
      'status': 'active',
      'created_at': '2026-08-02T08:00:00Z',
    });
  });
  final notifications = List.generate(
    notificationCount,
    (index) => SupervisionNotification.fromMap({
      'id': 'notification-$index',
      'event_type': 'link_request',
      'title': 'Link request $index',
      'body': 'Open request',
      'link_id': 'link-$index',
      'created_at': DateTime.utc(2026, 8, 2, 8, index).toIso8601String(),
    }),
  );
  return SupervisionDashboardState.fromParts(
    currentUserId: currentUserId,
    links: links,
    ownScreenTime: ScreenTimeSummary.zero(currentUserId, DateTime(2026, 8, 2)),
    notifications: notifications,
  );
}

final class FakeParentChildRepository implements ParentChildRepositoryContract {
  FakeParentChildRepository(this.state);
  final SupervisionDashboardState state;

  @override
  Future<SupervisionDashboardState> fetchDashboard({
    required DateTime localDay,
  }) async =>
      state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
