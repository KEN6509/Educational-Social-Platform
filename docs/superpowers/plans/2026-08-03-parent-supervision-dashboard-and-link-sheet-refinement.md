# Parent Supervision Dashboard and Link Sheet Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Match the Parent Supervision dashboard to the app's compact Chat styling, enforce the approved responsive card grid, and rebuild account-link requests with New Followers visuals and a shared Child/Parent confirmation.

**Architecture:** Keep all existing navigation and safety services intact. Extend the shared confirmation dialog with a customizable secondary label, give link candidates a typed request state derived from existing family links, and render both the dashboard and linking sheet from responsive constraints rather than hard-coded internal gaps.

**Tech Stack:** Flutter, Dart, Material 3, Supabase Flutter, flutter_test

---

## File structure

- Modify `apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart`: allow shared confirmation surfaces to customize the secondary action text.
- Modify `apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart`: add typed requestable/pending/linked candidate state.
- Modify `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart`: merge current family-link state into follower/following candidates.
- Modify `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`: New Followers-style rows, Request/Pending actions, shared role dialog, and in-place pending updates.
- Modify `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`: Chat-style app bar, theme background, and refresh callback from the linking sheet.
- Modify `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart`: shared-height screen-time, summary, and square safety cards.
- Modify `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart`: calculate the responsive tile extent and place parent/child action pairs in two-column rows.
- Modify `apps/mobile/test/app_confirmation_dialog_test.dart`: shared-dialog secondary label and Parent Supervision source-contract coverage.
- Modify `apps/mobile/test/parent_child_repository_test.dart`: candidate-state source contract.
- Modify `apps/mobile/test/parent_supervision_flows_test.dart`: linking-sheet states, role choice, pending behavior, and large-text regression.
- Modify `apps/mobile/test/parent_supervision_page_test.dart`: app bar, colors, shared heights, and square-grid geometry.
- Modify `design-qa.md`: append the final visual comparison evidence without removing existing module QA records.

### Task 1: Extend the shared confirmation dialog for role choices

**Files:**
- Modify: `apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart`
- Modify: `apps/mobile/test/app_confirmation_dialog_test.dart`

- [ ] **Step 1: Write a failing test for a custom secondary label**

Add a widget test that opens the shared dialog with `secondaryLabel: 'Parent'`:

```dart
testWidgets('supports a custom secondary confirmation action',
    (tester) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showAppConfirmationDialog(
            context: context,
            icon: Icons.family_restroom_rounded,
            iconColor: const Color(0xFF4490AD),
            iconBackgroundColor: const Color(0xFFE7F4F8),
            title: 'Choose your role',
            message: 'Select your role for family linking.',
            primaryLabel: 'Child',
            secondaryLabel: 'Parent',
            primaryColor: const Color(0xFF4490AD),
          );
        },
        child: const Text('Open'),
      ),
    ),
  ));

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.text('Child'), findsOneWidget);
  expect(find.text('Parent'), findsOneWidget);
  await tester.tap(find.text('Parent'));
  await tester.pumpAndSettle();
  expect(result, isFalse);
});
```

- [ ] **Step 2: Run the shared-dialog tests and verify RED**

Run:

```powershell
cd apps/mobile
flutter test test/app_confirmation_dialog_test.dart
```

Expected: compilation fails because `secondaryLabel` is not defined.

- [ ] **Step 3: Add an optional secondary label to the shared dialog**

Update both the function and widget constructors while preserving `Cancel` for every existing caller:

```dart
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required Color iconBackgroundColor,
  required String title,
  required String message,
  required String primaryLabel,
  required Color primaryColor,
  String secondaryLabel = 'Cancel',
  Key? primaryKey,
  Key? cancelKey,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => AppConfirmationDialog(
      icon: icon,
      iconColor: iconColor,
      iconBackgroundColor: iconBackgroundColor,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      primaryColor: primaryColor,
      secondaryLabel: secondaryLabel,
      primaryKey: primaryKey,
      cancelKey: cancelKey,
    ),
  );
}
```

Add `final String secondaryLabel;` to `AppConfirmationDialog`, default it to `Cancel`, and replace the hard-coded secondary `Text('Cancel')` with `Text(secondaryLabel, ...)`. Do not add icons inside either action.

- [ ] **Step 4: Run the shared-dialog tests and verify GREEN**

Run:

```powershell
flutter test test/app_confirmation_dialog_test.dart
```

Expected: all shared-dialog tests pass.

- [ ] **Step 5: Commit the shared dialog extension**

```powershell
git add -- apps/mobile/lib/src/core/widgets/app_confirmation_dialog.dart apps/mobile/test/app_confirmation_dialog_test.dart
git commit -m "feat: support shared role confirmation actions"
```

### Task 2: Model and load candidate request state

**Files:**
- Modify: `apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart`
- Modify: `apps/mobile/test/parent_child_repository_test.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Write failing model and repository-contract tests**

Add this model test to `parent_supervision_flows_test.dart`, showing pending and linked candidates cannot be requested:

```dart
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
```

Extend `parent_child_repository_test.dart` to require the repository to merge `fetchLinks()` results and assign `LinkCandidateState.pending` and `LinkCandidateState.linked`.

- [ ] **Step 2: Run the candidate tests and verify RED**

Run:

```powershell
flutter test test/parent_child_repository_test.dart test/parent_supervision_flows_test.dart
```

Expected: compilation fails because `LinkCandidateState` and the `linkState` copy argument do not exist.

- [ ] **Step 3: Add the typed candidate state**

In `parent_supervision_models.dart`:

```dart
enum LinkCandidateState { requestable, pending, linked }

final class LinkCandidate {
  const LinkCandidate({
    required this.profile,
    required this.isFollower,
    required this.isFollowing,
    this.linkState = LinkCandidateState.requestable,
  });

  final ProfileSummary profile;
  final bool isFollower;
  final bool isFollowing;
  final LinkCandidateState linkState;
  bool get isEligible => linkState == LinkCandidateState.requestable;

  LinkCandidate copyWith({
    bool? isFollower,
    bool? isFollowing,
    LinkCandidateState? linkState,
  }) =>
      LinkCandidate(
        profile: profile,
        isFollower: isFollower ?? this.isFollower,
        isFollowing: isFollowing ?? this.isFollowing,
        linkState: linkState ?? this.linkState,
      );
}
```

Remove `ineligibleReason`; replace its UI usage in Task 3.

- [ ] **Step 4: Merge pending and active family links into candidates**

After building the follower/following candidate map in `fetchLinkCandidates`, load existing links and assign state by the other account ID:

```dart
final links = await fetchLinks();
for (final link in links) {
  if (link.status != FamilyLinkStatus.pending &&
      link.status != FamilyLinkStatus.active) {
    continue;
  }
  final otherId = link.parentId == id ? link.childId : link.parentId;
  final candidate = candidates[otherId];
  if (candidate == null) continue;
  candidates[otherId] = candidate.copyWith(
    linkState: link.status == FamilyLinkStatus.pending
        ? LinkCandidateState.pending
        : LinkCandidateState.linked,
  );
}
```

Keep rejected, cancelled, and revoked links requestable because they no longer represent a current relationship.

- [ ] **Step 5: Run the candidate tests and verify GREEN**

Run:

```powershell
flutter test test/parent_child_repository_test.dart test/parent_supervision_flows_test.dart
```

Expected: the typed-state tests pass.

- [ ] **Step 6: Commit candidate state support**

```powershell
git add -- apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart apps/mobile/test/parent_child_repository_test.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "feat: expose family link candidate states"
```

### Task 3: Rebuild the request-account-linking sheet

**Files:**
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/test/app_confirmation_dialog_test.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Replace old sheet expectations with failing New Followers-style tests**

Add `lib/src/features/parent_child/presentation/link_candidates_page.dart` to the shared-dialog source contract in `app_confirmation_dialog_test.dart`. Update the flow tests to expect the new copy and states:

```dart
expect(find.text('Request Account Linking'), findsOneWidget);
expect(find.text('Followers & Following'), findsNothing);
expect(find.text('Request'), findsOneWidget);
expect(find.byKey(const Key('link-candidate-divider-0')), findsOneWidget);
```

Add a test for the shared role dialog and in-place pending state:

```dart
testWidgets('unlinked request uses shared Child and Parent role actions',
    (tester) async {
  final repository = FlowFakeRepository();
  await tester.pumpWidget(MaterialApp(
    home: LinkCandidatesPage(repository: repository),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Request'));
  await tester.pumpAndSettle();
  expect(find.byType(AppConfirmationDialog), findsOneWidget);
  expect(find.text('Child'), findsOneWidget);
  expect(find.text('Parent'), findsOneWidget);
  expect(find.text('I am the child'), findsNothing);
  expect(find.text('I am the parent'), findsNothing);

  await tester.tap(find.text('Child'));
  await tester.pumpAndSettle();
  expect(repository.createdRole, FamilyRole.child);
  expect(find.byType(LinkCandidatesPage), findsOneWidget);
  expect(find.text('Pending'), findsOneWidget);
});
```

Add a fake pending candidate and verify its action starts as `Pending`. Preserve the existing 360-pixel/2× text test but change its expected action from `Link Request` to `Request`.

- [ ] **Step 2: Run the linking-sheet tests and verify RED**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart test/app_confirmation_dialog_test.dart
```

Expected: failures reference the old title, old button label, `AlertDialog`, and route pop after request; the source-contract test also rejects the linking page's direct `AlertDialog`.

- [ ] **Step 3: Use the shared role confirmation**

Import the shared dialog and replace `_chooseRole`:

```dart
Future<FamilyRole?> _chooseRole() async {
  final childSelected = await showAppConfirmationDialog(
    context: context,
    icon: Icons.family_restroom_rounded,
    iconColor: const Color(0xFF4490AD),
    iconBackgroundColor: const Color(0xFFE7F4F8),
    title: 'Choose your role',
    message:
        'Your role stays the same while you have pending or active family links.',
    primaryLabel: 'Child',
    secondaryLabel: 'Parent',
    primaryColor: const Color(0xFF4490AD),
  );
  if (childSelected == null) return null;
  return childSelected ? FamilyRole.child : FamilyRole.parent;
}
```

The action widgets remain text-only because `AppConfirmationDialog` does not render button icons.

- [ ] **Step 4: Keep the sheet open and mark successful requests pending**

Add state and a callback:

```dart
final VoidCallback? onRequestCreated;
final Set<String> _locallyPendingCandidateIds = <String>{};

// after createLinkRequest succeeds
setState(() {
  _busyCandidateId = null;
  _locallyPendingCandidateIds.add(candidate.profile.id);
});
widget.onRequestCreated?.call();
```

Remove the success-path `Navigator.pop(true)`. In `ParentChildPage._openCandidates`, capture changes independently of how the sheet is dismissed:

```dart
var changed = false;
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => FractionallySizedBox(
    heightFactor: .86,
    child: LinkCandidatesPage(
      repository: _repository,
      establishedRole: state.role,
      embedded: true,
      onRequestCreated: () => changed = true,
    ),
  ),
);
if (changed) _refresh();
```

- [ ] **Step 5: Match the New Followers row design**

Use these sheet and row rules:

```dart
const _navy = Color(0xFF0B1F3E);
const _cyan = Color(0xFF4490AD);
const _softGrey = Color(0xFFF1F5F9);
const _divider = Color(0xFFE2E8F0);
```

- Left-align `Request Account Linking` at 18 pixels, weight 800.
- Keep the search field above the list.
- Use `ListView.separated` with horizontal padding 16.
- Build a 46-pixel `CircleAvatar` with cyan at 14% opacity and navy initial.
- Use 12 pixels between avatar and text.
- Render account name at weight 800 and relationship at 14 pixels in `0xFF475569`.
- Use an indented divider with `indent: 58`, `height: 1`, and key `link-candidate-divider-$index`.
- Use an `OutlinedButton` with 18-pixel radius, transparent border, minimum 78×36 size.

Resolve the action state before building the button:

```dart
final state = _locallyPendingCandidateIds.contains(profile.id)
    ? LinkCandidateState.pending
    : candidate.linkState;
final requestable = state == LinkCandidateState.requestable;
final label = switch (state) {
  LinkCandidateState.requestable => 'Request',
  LinkCandidateState.pending => 'Pending',
  LinkCandidateState.linked => 'Linked',
};
```

For `Request`, use cyan background and white text. For `Pending` and `Linked`, use `0xFFF1F5F9` background, cyan text, and a null `onPressed`. Retain the fixed-width/FittedBox protection that prevents large-text layout assertions.

- [ ] **Step 6: Run the linking-sheet tests and verify GREEN**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart test/app_confirmation_dialog_test.dart
```

Expected: all linking, role, pending, and large-text regressions pass.

- [ ] **Step 7: Commit the linking-sheet redesign**

```powershell
git add -- apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart apps/mobile/test/app_confirmation_dialog_test.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "feat: redesign account linking requests"
```

### Task 4: Implement the responsive square dashboard grid

**Files:**
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart`
- Modify: `apps/mobile/test/parent_supervision_page_test.dart`

- [ ] **Step 1: Write failing geometry, app-bar, and color tests**

At a 360×800 logical viewport, assert the compact app bar and scaffold background:

```dart
final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
final appBar = tester.widget<AppBar>(find.byType(AppBar));
expect(find.text('Parent Supervision'), findsOneWidget);
expect(find.text('Family Connection'), findsNothing);
expect(scaffold.backgroundColor, const Color(0xFFF1F5F9));
expect(appBar.titleSpacing, 16);
expect(appBar.elevation, 0);
expect(appBar.scrolledUnderElevation, 0);
expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
```

For the unlinked state:

```dart
final hero = tester.getRect(find.byKey(const Key('screen-time-hero')));
final family = tester.getRect(find.byKey(const Key('family-links-card')));
expect(hero.height, closeTo(family.height, .1));
```

For the parent state:

```dart
expect(family.top, records.top);
expect(family.width, closeTo(family.height, .1));
expect(records.width, closeTo(records.height, .1));
expect(hero.height, closeTo(family.height, .1));
```

For the child state, assign keys `safety-check-in-card` and `sos-card`, then assert they share a row, are square, and match the hero height.

- [ ] **Step 2: Run dashboard tests and verify RED**

Run:

```powershell
flutter test test/parent_supervision_page_test.dart
```

Expected: failures show the old title/app-bar, `0xFFF3F6F8`, 230-pixel summary card, stacked safety cards, and unequal hero/grid heights.

- [ ] **Step 3: Match the Chat page app bar and theme gray**

Replace the Parent Child app bar with:

```dart
Scaffold(
  backgroundColor: const Color(0xFFF1F5F9),
  appBar: AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleSpacing: 16,
    title: const Text(
      'Parent Supervision',
      style: TextStyle(
        color: Color(0xFF0B1F3E),
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
    ),
    actions: [
      IconButton(
        tooltip: 'Add family link',
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
          color: Color(0xFF0B1F3E),
          size: 28,
        ),
        onPressed: _openCandidates,
      ),
      const SizedBox(width: 8),
    ],
  ),
)
```

Change notification-row and empty-state fills from `0xFFF4F7F9` to `0xFFF1F5F9`.

- [ ] **Step 4: Calculate one responsive tile extent**

Change `_DashboardBase.list` to accept a tile-aware builder:

```dart
Widget list(List<Widget> Function(double tileExtent) childrenBuilder) =>
    LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 16.0;
        const columnGap = 12.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final tileExtent = (availableWidth - columnGap) / 2;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
          children: childrenBuilder(tileExtent),
        );
      },
    );
```

Pass `tileExtent` to every screen-time, full-width summary, and square action card.

- [ ] **Step 5: Make cards fit the shared extent without internal gaps**

Add a required `height` to `ScreenTimeCard`, `SummaryActionCard`, and `SafetyActionCard`, wrapping each root in `SizedBox(height: height)`. Remove `SummaryActionCard`'s fixed 190-pixel child and use this exact compact vertical structure, sized for a 158-pixel tile at a 360-pixel viewport:

```dart
padding: const EdgeInsets.all(14),
icon extent: 40,
icon/title gap: 8,
title font: 14, maxLines: 2,
title/subtitle gap: 4,
subtitle font: 10, maxLines: 2,
bottom action font: 11,
```

After the two-line subtitle, use `Expanded(child: Align(alignment: Alignment.bottomLeft, child: actionRow))`; do not place any `Spacer` between the title and subtitle. This keeps the bottom action aligned without recreating the previous oversized content gap. Reduce the screen-time card's padding to `EdgeInsets.all(16)`, use a 6-pixel label/value gap, a 10-pixel value/progress gap, and an 8-pixel progress/reminder gap so it fits the same extent without clipping.

Render `SafetyActionCard` vertically with the same square-card structure, semantic icon color, compact description, and bottom action/chevron. Use `Check in` and `Send SOS` as its bottom action labels.

- [ ] **Step 6: Place child safety actions in a square two-column row**

In `_Child`, replace the two stacked cards with:

```dart
Row(children: [
  Expanded(
    child: SafetyActionCard(
      key: const Key('safety-check-in-card'),
      height: tileExtent,
      title: 'Safety Check-In',
      actionLabel: 'Check in',
      description: 'Tell your linked parents that you are safe.',
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF16A34A),
      enabled: state.canUseSafetyActions,
      onTap: callbacks.onCheckIn,
    ),
  ),
  const SizedBox(width: 12),
  Expanded(
    child: SafetyActionCard(
      key: const Key('sos-card'),
      height: tileExtent,
      title: 'SOS',
      actionLabel: 'Send SOS',
      description: 'Send an urgent alert with a location attempt.',
      icon: Icons.sos_rounded,
      color: const Color(0xFFE11D48),
      enabled: state.canUseSafetyActions,
      onTap: callbacks.onSos,
    ),
  ),
])
```

Give the parent Family links and records cards `height: tileExtent`; their row widths then equal the same extent. Give full-width screen-time and Family links cards that same height.

- [ ] **Step 7: Run dashboard tests and verify GREEN**

Run:

```powershell
flutter test test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart
```

Expected: all dashboard geometry, app-bar, color, navigation, and safety-flow tests pass without overflow.

- [ ] **Step 8: Commit the dashboard refinement**

```powershell
git add -- apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart apps/mobile/test/parent_supervision_page_test.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "fix: refine parent supervision dashboard grid"
```

### Task 5: Full verification and visual QA

**Files:**
- Modify: `design-qa.md`
- Create or replace: `apps/mobile/parent-supervision-dashboard-grid-device.png`
- Create or replace: `apps/mobile/request-account-linking-sheet-device.png`
- Create or replace: `apps/mobile/parent-supervision-refinement-visual-qa.png`

- [ ] **Step 1: Format all changed Dart files**

Run:

```powershell
cd apps/mobile
dart format lib/src/core/widgets/app_confirmation_dialog.dart lib/src/features/parent_child/data/parent_supervision_models.dart lib/src/features/parent_child/data/parent_child_repository.dart lib/src/features/parent_child/presentation/link_candidates_page.dart lib/src/features/parent_child/presentation/parent_child_page.dart lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart lib/src/features/parent_child/presentation/supervision_dashboards.dart test/app_confirmation_dialog_test.dart test/parent_child_repository_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_page_test.dart
```

Expected: formatter exits successfully.

- [ ] **Step 2: Run focused and full verification**

Run:

```powershell
flutter test test/app_confirmation_dialog_test.dart test/parent_child_repository_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart
flutter analyze
flutter test
```

Expected: focused tests pass, analyzer reports `No issues found!`, and the full suite finishes with zero failures.

- [ ] **Step 3: Run the app on the connected Android device**

Run:

```powershell
flutter run -d 10AE6213P700176 --debug
```

Open Parent Supervision and verify the compact app bar, equal-height hero/full-width cards, square parent/child action rows, and `0xFFF1F5F9` canvas. Open Add and verify Request, Pending, search, the shared Child/Parent dialog, and sheet persistence after requesting.

- [ ] **Step 4: Capture and compare both approved visual targets**

Capture the dashboard and linking sheet from the device. Both dashboard reference and implementation captures must use the linked-parent state at the same logical viewport; both linking-list reference and implementation captures must show available accounts at the same logical viewport. If the signed-in device account cannot provide the linked-parent state, render that state through the existing widget-test fake repository at the device viewport instead of comparing different states. Compose comparison evidence that includes:

- parent dashboard reference `C:\Users\KEN\AppData\Local\Temp\codex-clipboard-fae40c15-5055-41dc-8b7a-15bd8cfcc899.png`;
- New Followers reference `C:\Users\KEN\AppData\Local\Temp\codex-clipboard-eed7b97c-bb83-4820-85fe-c651a74cb7db.jpg`;
- latest dashboard device capture;
- latest request-account-linking sheet device capture.

Inspect the combined comparison for app-bar size, title alignment, avatar size, list spacing, dividers, button states, card geometry, clipping, and theme colors. Fix every P0/P1/P2 mismatch and repeat capture until the comparison passes.

- [ ] **Step 5: Append the QA result without overwriting prior records**

Append a new `Parent Supervision Dashboard and Link Sheet Refinement` section to `design-qa.md` with source paths, implementation capture paths, interaction checks, verification counts, and exactly:

```markdown
## Result

final result: passed
```

- [ ] **Step 6: Commit verification evidence**

```powershell
git add -- design-qa.md apps/mobile/parent-supervision-dashboard-grid-device.png apps/mobile/request-account-linking-sheet-device.png apps/mobile/parent-supervision-refinement-visual-qa.png
git commit -m "test: verify parent supervision visual refinement"
```

- [ ] **Step 7: Confirm the worktree is clean**

Run:

```powershell
git status --short
git log -5 --oneline
```

Expected: `git status --short` prints nothing and the recent commits include the dialog, candidate state, linking sheet, dashboard grid, and visual verification changes.
