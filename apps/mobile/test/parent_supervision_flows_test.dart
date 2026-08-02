import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/data/parent_supervision_models.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/link_candidates_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/link_request_page.dart';
import 'package:cyanzone_mobile/src/features/parent_child/presentation/parent_child_page.dart';
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
  FlowFakeRepository({this.dashboardRole});

  final FamilyRole? dashboardRole;
  FamilyRole? createdRole;
  String? createdCandidateId;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FamilyLink _activeLink({required FamilyRole role}) => FamilyLink.fromMap({
      'id': 'active-link',
      'parent_id': role == FamilyRole.parent ? 'user-1' : 'other-user',
      'child_id': role == FamilyRole.child ? 'user-1' : 'other-user',
      'requested_by': 'user-1',
      'status': 'active',
      'created_at': '2026-08-01T08:00:00Z',
      'linked_at': '2026-08-01T09:00:00Z',
    });
