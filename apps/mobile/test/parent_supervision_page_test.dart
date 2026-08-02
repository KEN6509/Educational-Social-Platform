import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/parent_child_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the approved unlinked dashboard', (tester) async {
    _usePhoneViewport(tester);
    await _pump(tester, _state(role: null, activeLinks: 0));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(find.text('Parent Supervision'), findsOneWidget);
    expect(find.text('Family Connection'), findsNothing);
    expect(scaffold.backgroundColor, const Color(0xFFF1F5F9));
    expect(appBar.backgroundColor, Colors.white);
    expect(appBar.titleSpacing, 16);
    expect(appBar.elevation, 0);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.centerTitle, isFalse);
    expect(appBar.toolbarHeight, isNull);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
    expect(find.byKey(const Key('screen-time-hero')), findsOneWidget);
    expect(find.text('My screen time · Today'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('No active family links yet.'), findsOneWidget);
    expect(find.text('View links'), findsOneWidget);
    expect(find.text('Live · Latest 10'), findsOneWidget);
    expect(find.text('Safety Check-In'), findsNothing);
    expect(find.text('SOS'), findsNothing);

    final hero = tester.getRect(find.byKey(const Key('screen-time-hero')));
    final family = tester.getRect(find.byKey(const Key('family-links-card')));
    expect(hero.height, closeTo(family.height, .1));
    expect(
      tester
          .widget<Container>(
            find.byKey(const Key('supervision-notifications-empty')),
          )
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        const Color(0xFFF1F5F9),
      ),
    );
  });

  testWidgets('renders the approved linked child dashboard', (tester) async {
    _usePhoneViewport(tester);
    await _pump(tester, _state(role: FamilyRole.child, activeLinks: 2));
    expect(find.text('Child role · 2 linked parents'), findsOneWidget);
    expect(find.text('Safety Check-In'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    final hero = tester.getRect(find.byKey(const Key('screen-time-hero')));
    final checkIn =
        tester.getRect(find.byKey(const Key('safety-check-in-card')));
    final sos = tester.getRect(find.byKey(const Key('sos-card')));
    expect(checkIn.top, sos.top);
    expect(checkIn.width, closeTo(checkIn.height, .1));
    expect(sos.width, closeTo(sos.height, .1));
    expect(hero.height, closeTo(checkIn.height, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps parent summary cards side by side at phone width',
      (tester) async {
    _usePhoneViewport(tester);

    await _pump(tester, _state(role: FamilyRole.parent, activeLinks: 2));
    final family = tester.getRect(find.byKey(const Key('family-links-card')));
    final records =
        tester.getRect(find.byKey(const Key('safety-records-card')));
    expect(family.top, records.top);
    expect(family.width, closeTo(records.width, 0.1));
    expect(family.width, closeTo(family.height, 0.1));
    expect(records.width, closeTo(records.height, 0.1));
    final hero = tester.getRect(find.byKey(const Key('screen-time-hero')));
    expect(hero.height, closeTo(family.height, 0.1));
    expect(find.text('Parent role · 2 linked children'), findsOneWidget);
    expect(find.text('Check-In & SOS records'), findsOneWidget);
    expect(find.text('View links'), findsOneWidget);
    expect(find.text('View records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only ten supervision notifications', (tester) async {
    _usePhoneViewport(tester);
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

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
    final parentId =
        role == FamilyRole.parent ? currentUserId : 'parent-$index';
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
