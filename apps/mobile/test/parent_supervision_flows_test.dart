import 'dart:async';

import 'package:cyanzone_mobile/src/core/widgets/app_confirmation_dialog.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/check_in_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/family_links_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/link_candidates_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/parent_child_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/safety_records_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/sos_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/sos_tracking_scope.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/supervision_notification_router.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/location_service.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/sos_tracking_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('link candidate exposes typed request state', () {
    const profile = ProfileSummary(id: 'candidate-1', name: 'Alex Tan');
    const available = LinkCandidate(
      profile: profile,
      isFollower: true,
      isFollowing: false,
    );

    expect(available.isEligible, isTrue);
    expect(
      available.copyWith(linkState: LinkCandidateState.pending).isEligible,
      isFalse,
    );
    expect(
      available.copyWith(linkState: LinkCandidateState.linked).isEligible,
      isFalse,
    );
  });

  testWidgets('unlinked request uses shared Child and Parent role actions',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: LinkCandidatesPage(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Request Account Linking'), findsOneWidget);
    expect(find.text('Followers & Following'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('I am the parent'), findsNothing);
    expect(find.text('I am the child'), findsNothing);
    expect(find.byIcon(Icons.supervisor_account_outlined), findsNothing);
    expect(find.byIcon(Icons.child_care_rounded), findsNothing);

    await tester.tap(find.text('Child'));
    await tester.pumpAndSettle();
    expect(repository.createdRole, FamilyRole.child);
    expect(repository.createdCandidateId, 'candidate-1');
    expect(find.byType(LinkCandidatesPage), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('established role sends request without asking again',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: LinkCandidatesPage(
        repository: repository,
        establishedRole: FamilyRole.child,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your role'), findsNothing);
    expect(repository.createdRole, FamilyRole.child);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('candidate list uses an indented divider', (tester) async {
    final repository = FlowFakeRepository(
      candidates: const [
        LinkCandidate(
          profile: ProfileSummary(id: 'candidate-1', name: 'Alex Tan'),
          isFollower: true,
          isFollowing: true,
        ),
        LinkCandidate(
          profile: ProfileSummary(id: 'candidate-2', name: 'Jamie Lee'),
          isFollower: true,
          isFollowing: false,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: LinkCandidatesPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final divider = tester.widget<Divider>(
      find.byKey(const Key('link-candidate-divider-0')),
    );
    expect(divider.indent, 58);
    expect(divider.color, const Color(0xFFE2E8F0));
  });

  testWidgets('pending candidate uses a disabled soft-grey action',
      (tester) async {
    final repository = FlowFakeRepository(
      candidates: const [
        LinkCandidate(
          profile: ProfileSummary(id: 'candidate-1', name: 'Alex Tan'),
          isFollower: true,
          isFollowing: true,
          linkState: LinkCandidateState.pending,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: LinkCandidatesPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Pending'),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.disabled}),
      const Color(0xFFF1F5F9),
    );
    expect(
      button.style?.foregroundColor?.resolve({WidgetState.disabled}),
      const Color(0xFF4490AD),
    );
  });

  testWidgets('candidate rows fit narrow screens with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 760),
          textScaler: TextScaler.linear(2),
        ),
        child: LinkCandidatesPage(repository: FlowFakeRepository()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Alex Tan'), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family links page exposes pending accept and reject actions',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_pendingLink(requestedBy: 'other-user')],
      ),
    ));
    expect(find.text('PENDING REQUESTS'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Cancel request'), findsNothing);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-accept-family-link')));
    await tester.pumpAndSettle();
    expect(repository.acceptedLinkId, 'link-1');
  });

  testWidgets('family links page hides outgoing requests from pending section',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_pendingLink(requestedBy: 'user-1')],
      ),
    ));
    expect(find.text('PENDING REQUESTS'), findsNothing);
    expect(find.text('Request sent'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('dashboard add icon opens candidates with established role',
      (tester) async {
    final repository = FlowFakeRepository(
      dashboardRole: FamilyRole.child,
    );
    await tester.pumpWidget(MaterialApp(
      home: ParentChildPage(
        repository: repository,
        subscribeToRealtime: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add family link'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Request Account Linking'), findsOneWidget);

    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your role'), findsNothing);
    expect(repository.createdRole, FamilyRole.child);
    expect(find.text('Pending'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(repository.dashboardFetchCalls, 2);
  });

  testWidgets('dashboard add sheet stays visible while candidates load',
      (tester) async {
    final candidates = Completer<List<LinkCandidate>>();
    final repository = FlowFakeRepository(pendingCandidates: candidates);
    await tester.pumpWidget(MaterialApp(
      home: ParentChildPage(
        repository: repository,
        subscribeToRealtime: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add family link'));
    await tester.pump();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Request Account Linking'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    candidates.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('check in requires a message and skips unselected location',
      (tester) async {
    final repository = FlowFakeRepository();
    final location = FlowFakeLocationService();
    await tester.pumpWidget(MaterialApp(
      home: CheckInPage(repository: repository, locationService: location),
    ));

    await tester.tap(find.text('Send Check-In'));
    await tester.pump();
    expect(find.text('Enter a short safety message.'), findsOneWidget);
    expect(repository.submittedCheckIn, isNull);

    await tester.enterText(find.byType(TextFormField), 'I arrived safely.');
    await tester.tap(find.text('Send Check-In'));
    await tester.pumpAndSettle();
    expect(location.calls, 0);
    expect(repository.submittedCheckIn?.message, 'I arrived safely.');
    expect(
      repository.submittedCheckIn?.location.status,
      LocationStatus.notRequested,
    );
  });

  testWidgets('check in location failure preserves message and offers choices',
      (tester) async {
    final repository = FlowFakeRepository();
    final location = FlowFakeLocationService(
      results: [const LocationCapture.unavailable('permission_denied')],
    );
    await tester.pumpWidget(MaterialApp(
      home: CheckInPage(repository: repository, locationService: location),
    ));

    await tester.enterText(find.byType(TextFormField), 'Waiting at the lobby.');
    await tester.tap(find.text('Share my location'));
    await tester.tap(find.text('Send Check-In'));
    await tester.pumpAndSettle();

    expect(find.text('Retry location'), findsOneWidget);
    expect(find.text('Continue without location'), findsOneWidget);
    expect(find.text('Waiting at the lobby.'), findsOneWidget);
    expect(repository.submittedCheckIn, isNull);

    await tester.tap(find.text('Continue without location'));
    await tester.pumpAndSettle();
    expect(repository.submittedCheckIn?.message, 'Waiting at the lobby.');
    expect(
      repository.submittedCheckIn?.location.status,
      LocationStatus.notRequested,
    );
  });

  testWidgets('check in rejects messages over 280 characters', (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: CheckInPage(
        repository: repository,
        locationService: FlowFakeLocationService(),
      ),
    ));

    await tester.enterText(find.byType(TextFormField), 'x' * 281);
    await tester.tap(find.text('Send Check-In'));
    await tester.pump();

    expect(
        find.text('Keep your message within 280 characters.'), findsOneWidget);
    expect(repository.submittedCheckIn, isNull);
  });

  testWidgets('check in preserves its message after repository failure',
      (tester) async {
    final repository = FlowFakeRepository(checkInFailures: 1);
    await tester.pumpWidget(MaterialApp(
      home: CheckInPage(
        repository: repository,
        locationService: FlowFakeLocationService(),
      ),
    ));

    await tester.enterText(find.byType(TextFormField), 'Still waiting safely.');
    await tester.tap(find.text('Send Check-In'));
    await tester.pumpAndSettle();
    expect(find.text('Still waiting safely.'), findsOneWidget);
    expect(find.textContaining('Unable to send Check-In'), findsOneWidget);

    await tester.tap(find.text('Send Check-In'));
    await tester.pumpAndSettle();
    expect(repository.submittedCheckIn?.message, 'Still waiting safely.');
  });

  testWidgets('SOS confirms, attempts location, and waits for server success',
      (tester) async {
    final pending = Completer<SosAlert>();
    final repository = FlowFakeRepository(pendingSos: pending);
    final location = FlowFakeLocationService(
      results: [_availableLocation()],
    );
    await tester.pumpWidget(MaterialApp(
      home: SosPage(repository: repository, locationService: location),
    ));

    await tester.tap(find.text('Send SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Share location and alert parents?'), findsOneWidget);
    await tester.tap(find.text('Send SOS').last);
    await tester.pump();
    expect(location.calls, 1);
    expect(find.text('Sent'), findsNothing);

    pending.complete(_sosAlert(location: _availableLocation()));
    await tester.pumpAndSettle();
    expect(find.text('Sent'), findsOneWidget);
    expect(repository.submittedSos?.location.status, LocationStatus.available);
  });

  testWidgets('successful SOS starts the app-scoped tracking callback',
      (tester) async {
    final repository = FlowFakeRepository();
    SosAlert? startedAlert;
    await tester.pumpWidget(MaterialApp(
      home: SosPage(
        repository: repository,
        locationService: FlowFakeLocationService(
          results: [_availableLocation()],
        ),
        onSosStarted: (alert) async => startedAlert = alert,
      ),
    ));

    await tester.tap(find.text('Send SOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send SOS').last);
    await tester.pumpAndSettle();

    expect(startedAlert?.id, 'sos-1');
  });

  testWidgets('SOS tracking host forwards app lifecycle changes',
      (tester) async {
    final repository = _TrackingHostRepository();
    final schedule = _TrackingHostSchedule();
    final coordinator = SosTrackingCoordinator(
      repository: repository,
      locationService: FlowFakeLocationService(),
      schedule: schedule,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SosTrackingHost(
          coordinator: coordinator,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(repository.fetchActiveCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(schedule.stopCalls, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.fetchActiveCalls, 2);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(schedule.stopCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('SOS still submits when location is unavailable', (tester) async {
    final repository = FlowFakeRepository();
    final location = FlowFakeLocationService(
      results: [const LocationCapture.unavailable('services_disabled')],
    );
    await tester.pumpWidget(MaterialApp(
      home: SosPage(repository: repository, locationService: location),
    ));

    await tester.tap(find.text('Send SOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send SOS').last);
    await tester.pumpAndSettle();

    expect(location.calls, 1);
    expect(
        repository.submittedSos?.location.status, LocationStatus.unavailable);
    expect(repository.submittedSos?.location.failureCode, 'services_disabled');
    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('SOS remains retryable after repository failure', (tester) async {
    final repository = FlowFakeRepository(sosFailures: 1);
    final location = FlowFakeLocationService(results: [_availableLocation()]);
    await tester.pumpWidget(MaterialApp(
      home: SosPage(repository: repository, locationService: location),
    ));

    await tester.tap(find.text('Send SOS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send SOS').last);
    await tester.pumpAndSettle();
    expect(find.text('Sent'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Sent'), findsOneWidget);
    expect(location.calls, 1);
  });

  testWidgets('child dashboard safety cards open their flows as pages',
      (tester) async {
    _usePhoneViewport(tester);
    final repository = FlowFakeRepository(dashboardRole: FamilyRole.child);
    await tester.pumpWidget(MaterialApp(
      home: ParentChildPage(
        repository: repository,
        subscribeToRealtime: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Safety Check-In'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(CheckInPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('SOS'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(SosPage), findsOneWidget);
  });

  testWidgets('acknowledged SOS shows winner, time, and resolve action',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: SosPage(
        repository: repository,
        initialAlert: _sosAlert(
          location: _availableLocation(),
          status: SosStatus.acknowledged,
          acknowledgedBy: 'parent-2',
          acknowledgedAt: DateTime.utc(2026, 8, 2, 8),
        ),
        canManage: true,
      ),
    ));

    expect(find.text('parent-2'), findsOneWidget);
    expect(find.text('2 Aug 2026, 4:00 PM'), findsOneWidget);
    expect(find.text('Resolve SOS'), findsOneWidget);

    await tester.tap(find.text('Resolve SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Resolve SOS'), findsNothing);
  });

  testWidgets('open SOS uses the server-returned acknowledgement winner',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: SosPage(
        repository: repository,
        initialAlert: _sosAlert(location: _availableLocation()),
        canManage: true,
      ),
    ));

    await tester.tap(find.text('Acknowledge SOS'));
    await tester.pumpAndSettle();
    expect(find.text('Acknowledged'), findsOneWidget);
    expect(find.text('parent-2'), findsOneWidget);
    expect(find.text('Resolve SOS'), findsOneWidget);
  });

  testWidgets('safety records use grouped 100-record card layout and filters',
      (tester) async {
    final manyCheckIns = List.generate(
      101,
      (index) => _checkIn(
        id: 'check-in-$index',
        message: 'Check in $index',
        createdAt:
            DateTime.utc(2026, 8, 3, 12).subtract(Duration(minutes: index)),
      ),
    );
    final repository = FlowFakeRepository(
      checkIns: manyCheckIns,
      sosAlerts: [
        _sosAlert(
          location: _availableLocation(),
          createdAt: DateTime.utc(2026, 8, 3, 13),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: SafetyRecordsPage(repository: repository),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Check-In & SOS Records'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Check-Ins'), findsOneWidget);
    expect(find.text('SOS Alerts'), findsOneWidget);
    expect(find.text('AUG 3, 2026'), findsOneWidget);
    expect(find.text('CHECK-IN'), findsWidgets);
    expect(find.text('SOS'), findsOneWidget);
    final sosTop = tester.getTopLeft(find.text('SOS')).dy;
    final checkInTop = tester.getTopLeft(find.text('CHECK-IN').first).dy;
    expect(sosTop, lessThan(checkInTop));

    await tester.tap(find.text('Check-Ins'));
    await tester.pumpAndSettle();
    expect(find.text('SOS'), findsNothing);
    expect(find.text('CHECK-IN'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('safety-record-check-in-check-in-99')),
      500,
    );
    expect(
      find.byKey(const ValueKey('safety-record-check-in-check-in-100')),
      findsNothing,
    );

    await tester
        .tap(find.byKey(const ValueKey('safety-record-check-in-check-in-99')));
    await tester.pumpAndSettle();
    expect(find.text('Check-In detail'), findsOneWidget);
    expect(find.text('Check in 99'), findsOneWidget);
  });

  testWidgets('safety records show an empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SafetyRecordsPage(repository: FlowFakeRepository()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No Check-In or SOS records yet.'), findsOneWidget);
  });

  test('every supervision event has an exhaustive typed destination', () {
    final router = SupervisionNotificationRouter(
      repository: FlowFakeRepository(),
      currentUserId: 'user-1',
    );
    const expected = {
      SupervisionEventType.linkRequest: SupervisionDestination.familyLink,
      SupervisionEventType.linkAccepted: SupervisionDestination.familyLink,
      SupervisionEventType.linkRejected: SupervisionDestination.familyLink,
      SupervisionEventType.linkCancelled: SupervisionDestination.familyLink,
      SupervisionEventType.checkInSent: SupervisionDestination.checkIn,
      SupervisionEventType.checkInReceived: SupervisionDestination.checkIn,
      SupervisionEventType.sosOpened: SupervisionDestination.sos,
      SupervisionEventType.sosAcknowledged: SupervisionDestination.sos,
      SupervisionEventType.sosResolved: SupervisionDestination.sos,
      SupervisionEventType.screenTimeThreshold:
          SupervisionDestination.screenTime,
    };

    for (final entry in expected.entries) {
      expect(
        router.destinationFor(_notification(entry.key)),
        entry.value,
        reason: entry.key.name,
      );
    }
  });

  testWidgets('read-mark failure does not block Check-In destination',
      (tester) async {
    final repository = FlowFakeRepository(
      checkIns: [
        _checkIn(
          id: 'check-in-1',
          message: 'Reached home safely.',
          createdAt: DateTime.utc(2026, 8, 2, 8),
        ),
      ],
      failMarkRead: true,
    );
    final router = SupervisionNotificationRouter(
      repository: repository,
      currentUserId: 'user-1',
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => router.open(
            context,
            _notification(SupervisionEventType.checkInReceived),
          ),
          child: const Text('Open notification'),
        ),
      ),
    ));

    await tester.tap(find.text('Open notification'));
    await tester.pumpAndSettle();
    expect(repository.markedNotificationId, 'notification-1');
    expect(find.text('Check-In detail'), findsOneWidget);
    expect(find.text('Reached home safely.'), findsOneWidget);
  });

  testWidgets('parent records card opens merged safety records',
      (tester) async {
    _usePhoneViewport(tester);
    final repository = FlowFakeRepository(
      dashboardRole: FamilyRole.parent,
      checkIns: [
        _checkIn(
          id: 'check-in-1',
          message: 'Safe at home.',
          createdAt: DateTime.utc(2026, 8, 2, 8),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: ParentChildPage(
        repository: repository,
        subscribeToRealtime: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('safety-records-card')));
    await tester.pumpAndSettle();
    expect(find.byType(SafetyRecordsPage), findsOneWidget);
    expect(find.text('Jamie Tan'), findsOneWidget);
  });

  testWidgets('dashboard notification marks read and uses typed route',
      (tester) async {
    _usePhoneViewport(tester);
    final notification = _notification(SupervisionEventType.checkInReceived);
    final repository = FlowFakeRepository(
      dashboardRole: FamilyRole.parent,
      dashboardNotifications: [notification],
      checkIns: [
        _checkIn(
          id: 'check-in-1',
          message: 'Reached the library.',
          createdAt: DateTime.utc(2026, 8, 2, 8),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: ParentChildPage(
        repository: repository,
        subscribeToRealtime: false,
      ),
    ));
    await tester.pumpAndSettle();

    final tile = find.byKey(
      const Key('supervision-notification-tile-notification-1'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(repository.markedNotificationId, 'notification-1');
    expect(find.text('Check-In detail'), findsOneWidget);
    expect(find.text('Reached the library.'), findsOneWidget);
  });

  testWidgets('link notification opens the family links page', (tester) async {
    final repository = FlowFakeRepository(
      links: [_pendingLink(requestedBy: 'other-user')],
    );
    final router = SupervisionNotificationRouter(
      repository: repository,
      currentUserId: 'user-1',
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => router.open(
            context,
            _notification(SupervisionEventType.linkRequest),
          ),
          child: const Text('Open notification'),
        ),
      ),
    ));

    await tester.tap(find.text('Open notification'));
    await tester.pumpAndSettle();
    expect(repository.markedNotificationId, 'notification-1');
    expect(find.byType(FamilyLinksPage), findsOneWidget);
    expect(find.text('PENDING REQUESTS'), findsOneWidget);
  });

  testWidgets('linked account row opens the selected user profile',
      (tester) async {
    final repository = FlowFakeRepository(screenTimeSeconds: 3900);
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.parent)],
        profilePageBuilder: (profile) => Scaffold(
          body: Text('Profile: ${profile.name}'),
        ),
      ),
    ));

    await tester.tap(find.text('Jamie Tan'));
    await tester.pumpAndSettle();
    expect(find.text('Profile: Jamie Tan'), findsOneWidget);
  });

  testWidgets('pending request row opens the selected user profile',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_pendingLink(requestedBy: 'other-user')],
        profilePageBuilder: (profile) => Scaffold(
          body: Text('Profile: ${profile.name}'),
        ),
      ),
    ));

    await tester.tap(find.text('Parent Tan'));
    await tester.pumpAndSettle();
    expect(find.text('Profile: Parent Tan'), findsOneWidget);
  });

  testWidgets('parent linked account row uses child screen time and avatar',
      (tester) async {
    final repository = FlowFakeRepository(screenTimeSeconds: 3900);
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.parent)],
      ),
    ));
    await tester.pumpAndSettle();

    expect(repository.screenTimeUserIds, ['other-user']);
    expect(
      find.textContaining('Screen time today:', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Last active'), findsNothing);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.foregroundImage, isA<NetworkImage>());
  });

  testWidgets('child linked account row hides parent screen time',
      (tester) async {
    final repository = FlowFakeRepository(screenTimeSeconds: 3900);
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.child)],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Parent Tan'), findsOneWidget);
    expect(
      find.textContaining('Screen time today:', findRichText: true),
      findsNothing,
    );
    expect(repository.screenTimeUserIds, isEmpty);
  });

  testWidgets('child linked account row centers the name and unlink action',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.child)],
      ),
    ));
    await tester.pumpAndSettle();

    final avatarCenter = tester.getCenter(find.byType(CircleAvatar).first);
    final nameCenter = tester.getCenter(find.text('Parent Tan'));
    final unlinkCenter = tester.getCenter(find.text('Unlink'));
    expect((nameCenter.dy - avatarCenter.dy).abs(), lessThanOrEqualTo(2));
    expect((unlinkCenter.dy - avatarCenter.dy).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('unlink action sends a cancel request and switches to pending',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.child)],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-unlink-family-link')));
    await tester.pumpAndSettle();

    expect(repository.requestedUnlinkId, 'active-link');
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Unlink'), findsNothing);
  });

  testWidgets('unlink action requires confirmation before sending request',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.child)],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm unlink'), findsOneWidget);
    expect(repository.requestedUnlinkId, isNull);

    await tester.tap(find.byKey(const ValueKey('confirm-unlink-family-link')));
    await tester.pumpAndSettle();

    expect(repository.requestedUnlinkId, 'active-link');
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('unlink preserves account profile data immediately',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.child)],
        profilePageBuilder: (profile) => Scaffold(
          body: Text('Profile: ${profile.name}'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-unlink-family-link')));
    await tester.pumpAndSettle();

    expect(find.text('Parent Tan'), findsOneWidget);
    expect(find.text('Family member'), findsNothing);
    await tester.tap(find.text('Parent Tan'));
    await tester.pumpAndSettle();
    expect(find.text('Profile: Parent Tan'), findsOneWidget);
  });

  testWidgets('accepting link request preserves account profile data',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_pendingLink(requestedBy: 'other-user')],
        profilePageBuilder: (profile) => Scaffold(
          body: Text('Profile: ${profile.name}'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-accept-family-link')));
    await tester.pumpAndSettle();

    expect(find.text('Parent Tan'), findsOneWidget);
    expect(find.text('Family member'), findsNothing);
    await tester.tap(find.text('Parent Tan'));
    await tester.pumpAndSettle();
    expect(find.text('Profile: Parent Tan'), findsOneWidget);
  });

  testWidgets('accept link request requires confirmation before accepting',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_pendingLink(requestedBy: 'other-user')],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Accept family link?'), findsOneWidget);
    expect(repository.acceptedLinkId, isNull);

    await tester.tap(find.byKey(const ValueKey('confirm-accept-family-link')));
    await tester.pumpAndSettle();

    expect(repository.acceptedLinkId, 'link-1');
    expect(find.text('Parent Tan'), findsOneWidget);
  });

  testWidgets('unlink request failure appears as a supervision notification',
      (tester) async {
    final repository = FlowFakeRepository(failUnlinkRequest: true);
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [_activeLink(role: FamilyRole.child)],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-unlink-family-link')));
    await tester.pumpAndSettle();

    expect(find.text('Unable to request unlink'), findsOneWidget);
    expect(find.textContaining('Try again later'), findsOneWidget);
    expect(find.text('Unlink'), findsOneWidget);
  });

  testWidgets('incoming unlink request appears in pending requests and accepts',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [
          _activeLink(
            role: FamilyRole.child,
            unlinkRequestedBy: 'other-user',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Unlink Request:'), findsOneWidget);
    expect(find.text('End family link'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('confirm-accept-unlink-family-link')));
    await tester.pumpAndSettle();

    expect(repository.acceptedUnlinkId, 'active-link');
    expect(find.text('0 parents'), findsOneWidget);
  });

  testWidgets('incoming unlink request can be rejected and returns to unlink',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: FamilyLinksPage(
        repository: repository,
        currentUserId: 'user-1',
        initialLinks: [
          _activeLink(
            role: FamilyRole.child,
            unlinkRequestedBy: 'other-user',
          ),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(repository.rejectedUnlinkId, 'active-link');
    expect(find.text('Unlink Request:'), findsNothing);
    expect(find.text('Unlink'), findsOneWidget);
  });

  testWidgets('check in detail copies available location on long press',
      (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(MaterialApp(
      home: CheckInDetailPage(
        checkIn: _checkIn(
          id: 'check-in-copy',
          message: 'Arrived safely',
          createdAt: DateTime.utc(2026, 8, 2, 8),
          location: _availableLocation(),
        ),
      ),
    ));

    await tester.longPress(find.text('3.13900, 101.68690'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(copiedText, '3.13900, 101.68690');
    expect(find.text('Location copied'), findsOneWidget);
  });
}

FamilyLink _pendingLink({required String requestedBy}) => FamilyLink.fromMap({
      'id': 'link-1',
      'parent_id': 'other-user',
      'child_id': 'user-1',
      'requested_by': requestedBy,
      'status': 'pending',
      'created_at': '2026-08-02T08:00:00Z',
      'parent': const {
        'id': 'other-user',
        'name': 'Parent Tan',
        'avatar_url': 'https://example.com/parent.png',
      },
      'child': const {
        'id': 'user-1',
        'name': 'Jamie Tan',
        'avatar_url': 'https://example.com/jamie.png',
      },
    });

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final class FlowFakeRepository implements ParentChildRepositoryContract {
  FlowFakeRepository({
    this.dashboardRole,
    this.pendingCandidates,
    this.pendingSos,
    this.checkInFailures = 0,
    this.sosFailures = 0,
    this.checkIns = const [],
    this.sosAlerts = const [],
    this.failMarkRead = false,
    this.dashboardNotifications = const [],
    this.screenTimeSeconds = 0,
    this.links = const [],
    this.failUnlinkRequest = false,
    this.candidates = const [
      LinkCandidate(
        profile: ProfileSummary(id: 'candidate-1', name: 'Alex Tan'),
        isFollower: true,
        isFollowing: true,
      ),
    ],
  });

  final FamilyRole? dashboardRole;
  final Completer<List<LinkCandidate>>? pendingCandidates;
  final Completer<SosAlert>? pendingSos;
  int checkInFailures;
  int sosFailures;
  int dashboardFetchCalls = 0;
  final List<SafetyCheckIn> checkIns;
  final List<SosAlert> sosAlerts;
  final bool failMarkRead;
  final List<SupervisionNotification> dashboardNotifications;
  final int screenTimeSeconds;
  final List<FamilyLink> links;
  final bool failUnlinkRequest;
  final List<LinkCandidate> candidates;
  String? markedNotificationId;
  String? acceptedLinkId;
  String? rejectedLinkId;
  String? cancelledLinkId;
  String? requestedUnlinkId;
  String? acceptedUnlinkId;
  String? rejectedUnlinkId;
  final List<String> screenTimeUserIds = [];
  FamilyRole? createdRole;
  String? createdCandidateId;
  CheckInDraft? submittedCheckIn;
  SosDraft? submittedSos;

  @override
  Future<SupervisionDashboardState> fetchDashboard({
    required DateTime localDay,
  }) async {
    dashboardFetchCalls += 1;
    return SupervisionDashboardState.fromParts(
      currentUserId: 'user-1',
      links: dashboardRole == null
          ? const []
          : [_activeLink(role: dashboardRole!)],
      ownScreenTime: ScreenTimeSummary.zero('user-1', localDay),
      notifications: dashboardNotifications,
    );
  }

  @override
  Future<List<LinkCandidate>> fetchLinkCandidates() =>
      pendingCandidates?.future ?? Future.value(candidates);

  @override
  Future<List<FamilyLink>> fetchLinks() async => links;

  @override
  Future<FamilyLink> createLinkRequest(
    String candidateId,
    FamilyRole requesterRole,
  ) async {
    createdCandidateId = candidateId;
    createdRole = requesterRole;
    return _pendingLink(requestedBy: 'user-1');
  }

  @override
  Future<FamilyLink> acceptLinkRequest(String linkId) async {
    acceptedLinkId = linkId;
    return _activeLink(role: FamilyRole.child, includeProfiles: false);
  }

  @override
  Future<FamilyLink> rejectLinkRequest(String linkId) async {
    rejectedLinkId = linkId;
    return _pendingLink(requestedBy: 'other-user');
  }

  @override
  Future<FamilyLink> cancelLinkRequest(String linkId) async {
    cancelledLinkId = linkId;
    return _pendingLink(requestedBy: 'user-1');
  }

  @override
  Future<FamilyLink> requestUnlink(String linkId) async {
    requestedUnlinkId = linkId;
    if (failUnlinkRequest) {
      throw Exception('network unavailable');
    }
    return _activeLink(
      role: FamilyRole.child,
      unlinkRequestedBy: 'user-1',
      includeProfiles: false,
    );
  }

  @override
  Future<FamilyLink> acceptUnlink(String linkId) async {
    acceptedUnlinkId = linkId;
    return _activeLink(role: FamilyRole.child, status: 'revoked');
  }

  @override
  Future<FamilyLink> rejectUnlink(String linkId) async {
    rejectedUnlinkId = linkId;
    return _activeLink(role: FamilyRole.child, includeProfiles: false);
  }

  @override
  Future<SafetyCheckIn> submitCheckIn(CheckInDraft draft) async {
    if (checkInFailures > 0) {
      checkInFailures -= 1;
      throw Exception('offline');
    }
    submittedCheckIn = draft;
    return SafetyCheckIn(
      id: 'check-in-1',
      childId: 'user-1',
      message: draft.message,
      location: draft.location,
      createdAt: DateTime.utc(2026, 8, 2, 8),
    );
  }

  @override
  Future<SosAlert> submitSos(SosDraft draft) {
    submittedSos = draft;
    if (sosFailures > 0) {
      sosFailures -= 1;
      return Future.error(Exception('offline'));
    }
    return pendingSos?.future ??
        Future.value(_sosAlert(location: draft.location));
  }

  @override
  Future<SosAlert> acknowledgeSos(String sosId) async => _sosAlert(
        location: _availableLocation(),
        status: SosStatus.acknowledged,
        acknowledgedBy: 'parent-2',
        acknowledgedAt: DateTime.utc(2026, 8, 2, 8),
      );

  @override
  Future<SosAlert> resolveSos(String sosId) async => _sosAlert(
        location: _availableLocation(),
        status: SosStatus.resolved,
        acknowledgedBy: 'parent-2',
        acknowledgedAt: DateTime.utc(2026, 8, 2, 8),
      );

  @override
  Future<List<SafetyCheckIn>> fetchCheckIns() async => checkIns;

  @override
  Future<List<SosAlert>> fetchSosAlerts() async => sosAlerts;

  @override
  Future<void> markNotificationRead(String notificationId) async {
    markedNotificationId = notificationId;
    if (failMarkRead) throw Exception('read state unavailable');
  }

  @override
  Future<ScreenTimeSummary> fetchScreenTime(
    String userId,
    DateTime localDay,
  ) async {
    screenTimeUserIds.add(userId);
    return ScreenTimeSummary(
      userId: userId,
      localDay: localDay,
      secondsUsed: screenTimeSeconds,
      nextThresholdHours: 3,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class FlowFakeLocationService implements LocationService {
  FlowFakeLocationService({List<LocationCapture>? results})
      : _results = results ?? [const LocationCapture.notRequested()];

  final List<LocationCapture> _results;
  int calls = 0;

  @override
  Future<LocationCapture> capture() async {
    final index = calls.clamp(0, _results.length - 1);
    calls += 1;
    return _results[index];
  }
}

final class _TrackingHostSchedule implements SosTrackingSchedule {
  int stopCalls = 0;

  @override
  void start(Duration interval, void Function() onTick) {}

  @override
  void stop() => stopCalls += 1;
}

final class _TrackingHostRepository implements ParentChildRepositoryContract {
  int fetchActiveCalls = 0;

  @override
  Future<SosAlert?> fetchActiveSos() async {
    fetchActiveCalls += 1;
    return null;
  }

  @override
  RealtimeChannel subscribeToSosDetailChanges({
    required String sosId,
    required void Function() onChange,
  }) =>
      throw UnimplementedError('No active alert is returned by this fake');

  @override
  Future<void> unsubscribe(RealtimeChannel channel) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LocationCapture _availableLocation() => LocationCapture.available(
      latitude: 3.139,
      longitude: 101.6869,
      accuracyMeters: 8,
      capturedAt: DateTime.utc(2026, 8, 2, 8),
    );

SosAlert _sosAlert({
  required LocationCapture location,
  SosStatus status = SosStatus.open,
  String? acknowledgedBy,
  DateTime? acknowledgedAt,
  DateTime? createdAt,
}) =>
    SosAlert(
      id: 'sos-1',
      childId: 'user-1',
      status: status,
      location: location,
      createdAt: createdAt ?? DateTime.utc(2026, 8, 2, 8),
      acknowledgedBy: acknowledgedBy,
      acknowledgedAt: acknowledgedAt,
    );

SafetyCheckIn _checkIn({
  required String id,
  required String message,
  required DateTime createdAt,
  LocationCapture location = const LocationCapture.notRequested(),
}) =>
    SafetyCheckIn(
      id: id,
      childId: 'child-1',
      message: message,
      location: location,
      createdAt: createdAt,
      child: const ProfileSummary(id: 'child-1', name: 'Jamie Tan'),
    );

SupervisionNotification _notification(SupervisionEventType type) =>
    SupervisionNotification(
      id: 'notification-1',
      eventType: type,
      title: type.name,
      body: 'Supervision update',
      createdAt: DateTime.utc(2026, 8, 2, 9),
      linkId: 'link-1',
      checkInId: 'check-in-1',
      sosId: 'sos-1',
      childId: 'child-1',
    );

FamilyLink _activeLink({
  required FamilyRole role,
  String? unlinkRequestedBy,
  String status = 'active',
  bool includeProfiles = true,
}) {
  final map = <String, dynamic>{
    'id': 'active-link',
    'parent_id': role == FamilyRole.parent ? 'user-1' : 'other-user',
    'child_id': role == FamilyRole.child ? 'user-1' : 'other-user',
    'requested_by': 'user-1',
    'status': status,
    'unlink_requested_by': unlinkRequestedBy,
    'unlink_requested_at':
        unlinkRequestedBy == null ? null : '2026-08-02T10:00:00Z',
    'created_at': '2026-08-01T08:00:00Z',
    'linked_at': '2026-08-01T09:00:00Z',
  };
  if (includeProfiles) {
    map.addAll({
      'parent': {
        'id': role == FamilyRole.parent ? 'user-1' : 'other-user',
        'name': 'Parent Tan',
        'avatar_url': 'https://example.com/parent.png',
      },
      'child': {
        'id': role == FamilyRole.child ? 'user-1' : 'other-user',
        'name': 'Jamie Tan',
        'avatar_url': 'https://example.com/jamie.png',
      },
    });
  }
  return FamilyLink.fromMap(map);
}
