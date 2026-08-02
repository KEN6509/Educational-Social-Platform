import 'dart:async';

import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/check_in_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/link_candidates_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/link_request_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/parent_child_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/sos_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unlinked candidate request asks for requester role',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: LinkCandidatesPage(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Followers & Following'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Link Request'));
    await tester.pumpAndSettle();
    expect(find.text('I am the parent'), findsOneWidget);
    expect(find.text('I am the child'), findsOneWidget);

    await tester.tap(find.text('I am the parent'));
    await tester.pumpAndSettle();
    expect(repository.createdRole, FamilyRole.parent);
    expect(repository.createdCandidateId, 'candidate-1');
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
    await tester.tap(find.text('Link Request'));
    await tester.pumpAndSettle();
    expect(find.text('I am the parent'), findsNothing);
    expect(repository.createdRole, FamilyRole.child);
  });

  testWidgets('incoming request exposes accept and reject actions',
      (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: LinkRequestPage(
        repository: repository,
        link: _pendingLink(requestedBy: 'other-user'),
        currentUserId: 'user-1',
      ),
    ));
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Cancel request'), findsNothing);
  });

  testWidgets('outgoing request exposes only cancellation', (tester) async {
    final repository = FlowFakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: LinkRequestPage(
        repository: repository,
        link: _pendingLink(requestedBy: 'user-1'),
        currentUserId: 'user-1',
      ),
    ));
    expect(find.text('Cancel request'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Reject'), findsNothing);
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
    expect(find.text('Followers & Following'), findsOneWidget);

    await tester.tap(find.text('Link Request'));
    await tester.pumpAndSettle();
    expect(find.text('I am the parent'), findsNothing);
    expect(repository.createdRole, FamilyRole.child);
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

  testWidgets('child dashboard safety cards open their flows', (tester) async {
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
    expect(find.byType(CheckInPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();
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
}

FamilyLink _pendingLink({required String requestedBy}) => FamilyLink.fromMap({
      'id': 'link-1',
      'parent_id': 'other-user',
      'child_id': 'user-1',
      'requested_by': requestedBy,
      'status': 'pending',
      'created_at': '2026-08-02T08:00:00Z',
    });

final class FlowFakeRepository implements ParentChildRepositoryContract {
  FlowFakeRepository({
    this.dashboardRole,
    this.pendingSos,
    this.checkInFailures = 0,
    this.sosFailures = 0,
  });

  final FamilyRole? dashboardRole;
  final Completer<SosAlert>? pendingSos;
  int checkInFailures;
  int sosFailures;
  FamilyRole? createdRole;
  String? createdCandidateId;
  CheckInDraft? submittedCheckIn;
  SosDraft? submittedSos;

  @override
  Future<SupervisionDashboardState> fetchDashboard({
    required DateTime localDay,
  }) async =>
      SupervisionDashboardState.fromParts(
        currentUserId: 'user-1',
        links: dashboardRole == null
            ? const []
            : [_activeLink(role: dashboardRole!)],
        ownScreenTime: ScreenTimeSummary.zero('user-1', localDay),
        notifications: const [],
      );

  @override
  Future<List<LinkCandidate>> fetchLinkCandidates() async => [
        const LinkCandidate(
          profile: ProfileSummary(id: 'candidate-1', name: 'Alex Tan'),
          isFollower: true,
          isFollowing: true,
        ),
      ];

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
}) =>
    SosAlert(
      id: 'sos-1',
      childId: 'user-1',
      status: status,
      location: location,
      createdAt: DateTime.utc(2026, 8, 2, 8),
      acknowledgedBy: acknowledgedBy,
      acknowledgedAt: acknowledgedAt,
    );

FamilyLink _activeLink({required FamilyRole role}) => FamilyLink.fromMap({
      'id': 'active-link',
      'parent_id': role == FamilyRole.parent ? 'user-1' : 'other-user',
      'child_id': role == FamilyRole.child ? 'user-1' : 'other-user',
      'requested_by': 'user-1',
      'status': 'active',
      'created_at': '2026-08-01T08:00:00Z',
      'linked_at': '2026-08-01T09:00:00Z',
    });
