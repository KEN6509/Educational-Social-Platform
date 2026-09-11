# Mobile Parent-Child Presentation Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose CyanZone's parent-child presentation code and coordinate Parent Supervision refreshes without changing existing linking, Check-In, SOS, map, record, notification, navigation, or visual behaviour.

**Architecture:** Promote the proven chat-only refresh coordinator into a vendor-neutral core utility, then use it for the Parent Supervision dashboard while each page remains the owner of its repository, channel, lifecycle observer, and visible state. Split large parent-child files through Dart library parts or focused public pages so workflows stay in page State classes and presentation-only widgets stay feature-local.

**Tech Stack:** Flutter, Dart, Material 3, Supabase Flutter realtime, `flutter_test`, existing CyanZone design tokens and shared feedback components

---

## Scope and working rules

- Work in the original `C:\Chan Ming Jiang\Degree\Sem 5\CyanZone` folder on
  `refactor/mobile-architecture-optimization`; do not create a worktree.
- Follow the approved design in
  `docs/superpowers/specs/2026-09-12-mobile-parent-child-presentation-refactor-design.md`.
- Do not change SQL, Supabase policies or RPCs, API contracts, Firebase,
  dependencies, routes, role rules, wording, or SOS tracking behaviour.
- Preserve the ten-second foreground-only SOS tracking interval.
- Use tests before behaviour-changing implementation.
- Keep mechanical file extraction separate from behaviour changes.
- Run terminal commands directly in the user's terminal and use `apply_patch`
  for file contents.
- Commit every passing checkpoint separately.

## File structure

### Create

- `apps/mobile/lib/src/core/application/async_refresh_coordinator.dart`
  - shared debounce, serialization, initial-load tracking, trailing refresh,
    error containment, and disposal.
- `apps/mobile/lib/src/features/parent_child/presentation/family_links_widgets.dart`
  - private Family Links cards, rows, indicators, and controls as a Dart part.
- `apps/mobile/lib/src/features/parent_child/presentation/safety_record_widgets.dart`
  - private Safety Records filters, list rows, avatars, chips, and page messages
    as a Dart part.
- `apps/mobile/lib/src/features/parent_child/presentation/check_in_detail_page.dart`
  - public Check-In record detail page and its private detail row.
- `apps/mobile/lib/src/features/parent_child/presentation/sos_widgets.dart`
  - private SOS bottom action, timeline, and detail cards as a Dart part.
- `apps/mobile/test/parent_child_presentation_decomposition_test.dart`
  - file-responsibility and direct-feedback construction contracts.

### Move or delete

- Delete
  `apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart`
  after all imports and tests use the shared coordinator.

### Modify

- `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- `apps/mobile/test/chat_refresh_coordinator_test.dart`
- `apps/mobile/test/chat_realtime_lifecycle_test.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/family_links_page.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`
- `apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart`
- `apps/mobile/test/parent_supervision_page_test.dart`
- `apps/mobile/test/parent_supervision_flows_test.dart`

---

### Task 1: Promote the refresh coordinator into shared core

**Files:**

- Create: `apps/mobile/lib/src/core/application/async_refresh_coordinator.dart`
- Delete: `apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/test/chat_refresh_coordinator_test.dart`
- Modify: `apps/mobile/test/chat_realtime_lifecycle_test.dart`

- [ ] **Step 1: Point the coordinator test at the future core contract**

In `chat_refresh_coordinator_test.dart`, replace the import and constructor
name:

```dart
import 'package:cyanzone_mobile/src/core/application/async_refresh_coordinator.dart';

// Every existing test constructs this type.
final coordinator = AsyncRefreshCoordinator(
  refresh: () async {},
);
```

Replace all six `ChatRefreshCoordinator(` occurrences with
`AsyncRefreshCoordinator(`. Keep all existing assertions unchanged.

- [ ] **Step 2: Run the coordinator test and verify the missing-core failure**

Run from `apps/mobile`:

```powershell
flutter test test/chat_refresh_coordinator_test.dart --no-pub --reporter expanded
```

Expected: FAIL because
`core/application/async_refresh_coordinator.dart` does not exist.

- [ ] **Step 3: Create the shared coordinator with the proven behaviour**

Create `async_refresh_coordinator.dart`:

```dart
import 'dart:async';

typedef AsyncRefreshTask = Future<void> Function();
typedef AsyncRefreshErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

final class AsyncRefreshCoordinator {
  AsyncRefreshCoordinator({
    required AsyncRefreshTask refresh,
    this.debounce = const Duration(milliseconds: 120),
    AsyncRefreshErrorHandler? onError,
  })  : _refresh = refresh,
        _onError = onError;

  final AsyncRefreshTask _refresh;
  final AsyncRefreshErrorHandler? _onError;
  final Duration debounce;

  Timer? _timer;
  Completer<void>? _cycleCompleter;
  bool _pending = false;
  bool _disposed = false;

  void schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(refreshNow());
    });
  }

  void trackInitialRefresh(Future<void> refresh) {
    if (_disposed) return;
    if (_cycleCompleter != null) {
      throw StateError('A refresh cycle is already active.');
    }

    final cycle = Completer<void>();
    _cycleCompleter = cycle;
    unawaited(_drain(cycle, initialRefresh: refresh));
  }

  Future<void> refreshNow() {
    if (_disposed) return Future<void>.value();
    _timer?.cancel();
    _timer = null;
    _pending = true;

    final activeCycle = _cycleCompleter;
    if (activeCycle != null) return activeCycle.future;

    final cycle = Completer<void>();
    _cycleCompleter = cycle;
    unawaited(_drain(cycle));
    return cycle.future;
  }

  Future<void> _drain(
    Completer<void> cycle, {
    Future<void>? initialRefresh,
  }) async {
    try {
      if (initialRefresh != null) {
        await _runRefresh(() => initialRefresh);
      }
      while (_pending && !_disposed) {
        _pending = false;
        await _runRefresh(_refresh);
      }
    } finally {
      if (identical(_cycleCompleter, cycle)) {
        _cycleCompleter = null;
      }
      if (!cycle.isCompleted) cycle.complete();
    }
  }

  Future<void> _runRefresh(AsyncRefreshTask refresh) async {
    try {
      await refresh();
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending = false;
    _timer?.cancel();
    _timer = null;
  }
}
```

- [ ] **Step 4: Verify the shared coordinator tests**

```powershell
dart format lib/src/core/application/async_refresh_coordinator.dart test/chat_refresh_coordinator_test.dart
flutter test test/chat_refresh_coordinator_test.dart --no-pub --reporter expanded
```

Expected: all six coordinator tests PASS.

- [ ] **Step 5: Migrate the three chat consumers mechanically**

In `chat_page.dart`, `chat_room_page.dart`, and
`notification_sections_page.dart`, replace the feature-local import with:

```dart
import '../../../core/application/async_refresh_coordinator.dart';
```

In each file, replace the field and construction type:

```dart
late final AsyncRefreshCoordinator _refreshCoordinator;

_refreshCoordinator = AsyncRefreshCoordinator(
  refresh: _performHomeRefresh, // Keep each file's current callback.
);
```

For `chat_room_page.dart`, retain its existing `onError` callback. For
`notification_sections_page.dart`, retain `_performRefresh`. Do not modify any
subscription, cache, loading, or UI code.

Update `chat_realtime_lifecycle_test.dart` so all source assertions expect:

```dart
late final AsyncRefreshCoordinator _refreshCoordinator;
_refreshCoordinator = AsyncRefreshCoordinator(
```

Delete `features/chat/application/chat_refresh_coordinator.dart` only after
`rg -n "ChatRefreshCoordinator|chat_refresh_coordinator" apps/mobile/lib apps/mobile/test`
returns no matches.

- [ ] **Step 6: Run the chat migration regression tests**

```powershell
dart format lib/src/features/chat/presentation/chat_page.dart lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/notification_sections_page.dart test/chat_realtime_lifecycle_test.dart
flutter test test/chat_refresh_coordinator_test.dart test/chat_realtime_lifecycle_test.dart test/chat_widgets_test.dart test/chat_repository_test.dart --no-pub --reporter expanded
```

Expected: all selected tests PASS with unchanged chat behaviour.

- [ ] **Step 7: Commit the shared coordinator checkpoint**

```powershell
git add apps/mobile/lib/src/core/application/async_refresh_coordinator.dart apps/mobile/lib/src/features/chat apps/mobile/test/chat_refresh_coordinator_test.dart apps/mobile/test/chat_realtime_lifecycle_test.dart
git commit -m "refactor(mobile): share async refresh coordination"
```

---

### Task 2: Coordinate Parent Supervision dashboard refreshes

**Files:**

- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`
- Create: `apps/mobile/test/parent_child_presentation_decomposition_test.dart`

- [ ] **Step 1: Add the failing early-resume serialization test**

Add this test to `parent_supervision_flows_test.dart`:

```dart
testWidgets('dashboard serializes resume refresh behind initial load',
    (tester) async {
  final initial = Completer<SupervisionDashboardState>();
  final repository = FlowFakeRepository(pendingDashboard: initial);

  await tester.pumpWidget(
    MaterialApp(
      home: ParentChildPage(
        repository: repository,
        subscribeToRealtime: false,
      ),
    ),
  );
  await tester.pump();

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  expect(repository.dashboardFetchCalls, 1);

  initial.complete(repository.dashboardState(DateTime(2026, 9, 12)));
  await tester.pumpAndSettle();
  expect(repository.dashboardFetchCalls, 2);
});
```

Extend `FlowFakeRepository` with:

```dart
final Completer<SupervisionDashboardState>? pendingDashboard;
bool _pendingDashboardReturned = false;

SupervisionDashboardState dashboardState(DateTime localDay) {
  return SupervisionDashboardState.fromParts(
    currentUserId: 'user-1',
    links: dashboardRole == null
        ? const []
        : [_activeLink(role: dashboardRole!)],
    ownScreenTime: ScreenTimeSummary.zero('user-1', localDay),
    notifications: dashboardNotifications,
  );
}
```

Add `this.pendingDashboard` to its constructor. At the start of
`fetchDashboard`, after incrementing `dashboardFetchCalls`, add:

```dart
if (pendingDashboard != null && !_pendingDashboardReturned) {
  _pendingDashboardReturned = true;
  return pendingDashboard!.future;
}
return dashboardState(localDay);
```

Replace the method's existing inline `SupervisionDashboardState.fromParts`
return with `dashboardState(localDay)` so the helper has one definition.

- [ ] **Step 2: Add failing source ownership assertions**

Create `parent_child_presentation_decomposition_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ParentChildPage owns one coordinated dashboard refresh path', () {
    final source = File(
      'lib/src/features/parent_child/presentation/parent_child_page.dart',
    ).readAsStringSync();

    expect(source, contains('late final AsyncRefreshCoordinator'));
    expect(source, contains('_refreshCoordinator.trackInitialRefresh('));
    expect(source, contains('onChange: _refreshCoordinator.schedule'));
    expect(source, contains('Future<void> _performRefresh()'));
    expect(source, contains('_refreshCoordinator.dispose();'));
    expect(source, isNot(contains('Timer? _refreshDebounce')));
    expect(
      source.indexOf('_refreshCoordinator = AsyncRefreshCoordinator('),
      lessThan(source.indexOf('_dashboardFuture =')),
    );
  });
}
```

- [ ] **Step 3: Run the new tests and verify both failures**

```powershell
flutter test test/parent_supervision_flows_test.dart test/parent_child_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL because resume starts a second dashboard fetch while the first
is pending and the page still owns a raw `Timer` debounce.

- [ ] **Step 4: Route every dashboard refresh through the shared coordinator**

In `parent_child_page.dart`, add:

```dart
import '../../../core/application/async_refresh_coordinator.dart';
```

Remove `_refreshDebounce` and add:

```dart
late final AsyncRefreshCoordinator _refreshCoordinator;
```

Replace the loading section of `initState` with:

```dart
_repository =
    widget.repository ?? ParentChildRepository(Supabase.instance.client);
_refreshCoordinator = AsyncRefreshCoordinator(
  debounce: const Duration(milliseconds: 180),
  refresh: _performRefresh,
  onError: (error, _) {
    assert(() {
      debugPrint('Parent Supervision refresh failed: $error');
      return true;
    }());
  },
);
_dashboardFuture = _repository.fetchDashboard(localDay: DateTime.now());
_refreshCoordinator.trackInitialRefresh(
  _dashboardFuture.then<void>((_) {}),
);
if (widget.subscribeToRealtime) {
  _channel = _repository.subscribeToSupervisionChanges(
    onChange: _refreshCoordinator.schedule,
  );
}
```

Replace `_scheduleRefresh` and `_refresh` with:

```dart
Future<void> _performRefresh() async {
  if (!mounted) return;
  final next = _repository.fetchDashboard(localDay: DateTime.now());
  setState(() => _dashboardFuture = next);
  await next;
}

Future<void> _refresh() => _refreshCoordinator.refreshNow();
```

Change resume to:

```dart
if (state == AppLifecycleState.resumed) {
  unawaited(_refresh());
}
```

Use `if (changed) await _refresh();` after the candidate sheet closes. Await
`_refresh()` after Family Links and Safety Records close. Keep Check-In and SOS
conditional on `sent == true`, but await their refresh. Keep notification
navigation using `.whenComplete(_refresh)`.

Use the direct callback for pull refresh:

```dart
RefreshIndicator(
  onRefresh: _refresh,
  child: SupervisionDashboard(...),
)
```

In `dispose`, replace `_refreshDebounce?.cancel()` with:

```dart
_refreshCoordinator.dispose();
```

Keep the existing one-channel unsubscribe code unchanged.

- [ ] **Step 5: Verify the dashboard coordination**

```powershell
dart format lib/src/features/parent_child/presentation/parent_child_page.dart test/parent_supervision_flows_test.dart test/parent_child_presentation_decomposition_test.dart
flutter test test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_child_presentation_decomposition_test.dart test/chat_refresh_coordinator_test.dart --no-pub --reporter expanded
```

Expected: all selected tests PASS. The early-resume test must observe one fetch
until the initial completer finishes, followed by exactly one trailing fetch.

- [ ] **Step 6: Commit the dashboard coordination checkpoint**

```powershell
git add apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart apps/mobile/test/parent_supervision_flows_test.dart apps/mobile/test/parent_child_presentation_decomposition_test.dart
git commit -m "refactor(mobile): coordinate supervision dashboard refreshes"
```

---

### Task 3: Extract Family Links presentation widgets

**Files:**

- Create: `apps/mobile/lib/src/features/parent_child/presentation/family_links_widgets.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/family_links_page.dart`
- Modify: `apps/mobile/test/parent_child_presentation_decomposition_test.dart`

- [ ] **Step 1: Add the failing Family Links decomposition contract**

Append inside `main()`:

```dart
test('Family Links page keeps coordination and delegates private widgets', () {
  final page = File(
    'lib/src/features/parent_child/presentation/family_links_page.dart',
  ).readAsStringSync();
  final widgets = File(
    'lib/src/features/parent_child/presentation/family_links_widgets.dart',
  );

  expect(page, contains("part 'family_links_widgets.dart';"));
  expect(widgets.existsSync(), isTrue);
  final widgetSource = widgets.readAsStringSync();
  expect(widgetSource, contains("part of 'family_links_page.dart';"));
  expect(page, contains('class _FamilyLinksPageState'));
  expect(page, isNot(contains('class _PendingLinkRow')));
  expect(widgetSource, contains('class _PendingLinkRow'));
  expect(widgetSource, contains('class _ActiveLinkRow'));
  expect(widgetSource, contains('class _ChildScreenTimeRow'));
});
```

- [ ] **Step 2: Run the decomposition contract and verify failure**

```powershell
flutter test test/parent_child_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL because `family_links_widgets.dart` does not exist.

- [ ] **Step 3: Create the Family Links Dart part**

Add this directive after all imports in `family_links_page.dart`:

```dart
part 'family_links_widgets.dart';
```

Keep lines containing `FamilyProfilePageBuilder`, `FamilyLinksPage`, and
`_FamilyLinksPageState` in the page file. Move the existing class block from
`_SectionHeader` through `_UnlinkPill` into the new file without changing
constructor signatures, keys, callback types, layout values, or text.

The new file starts with:

```dart
part of 'family_links_page.dart';

// Existing classes moved here unchanged, in their current order:
// _SectionHeader, _SectionCard, _PendingLinkRow, _PendingUnlinkRow,
// _ActiveLinkRow, _ChildScreenTimeRow, _LinkedNameRow,
// _LocalSupervisionNotice, _LocalNoticeRow, _EmptyLinkedCard,
// _Avatar, _RoleChip, _CircleAction, and _UnlinkPill.
```

Do not make the private classes public. Using a part preserves their library
privacy and avoids new cross-file APIs.

- [ ] **Step 4: Format and run Family Links behaviour tests**

```powershell
dart format lib/src/features/parent_child/presentation/family_links_page.dart lib/src/features/parent_child/presentation/family_links_widgets.dart test/parent_child_presentation_decomposition_test.dart
flutter test test/parent_child_presentation_decomposition_test.dart test/parent_supervision_flows_test.dart --no-pub --reporter expanded
```

Expected: PASS, including request, accept, reject, unlink, screen-time, profile
navigation, narrow-screen, and confirmation behaviour.

- [ ] **Step 5: Commit the Family Links extraction**

```powershell
git add apps/mobile/lib/src/features/parent_child/presentation/family_links_page.dart apps/mobile/lib/src/features/parent_child/presentation/family_links_widgets.dart apps/mobile/test/parent_child_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract family link widgets"
```

---

### Task 4: Separate Safety Records list and Check-In detail presentation

**Files:**

- Create: `apps/mobile/lib/src/features/parent_child/presentation/safety_record_widgets.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/check_in_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart`
- Modify: `apps/mobile/test/parent_child_presentation_decomposition_test.dart`
- Test: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Add the failing Safety Records decomposition contract**

Append:

```dart
test('Safety Records separates list widgets and Check-In detail route', () {
  final page = File(
    'lib/src/features/parent_child/presentation/safety_records_page.dart',
  ).readAsStringSync();
  final widgets = File(
    'lib/src/features/parent_child/presentation/safety_record_widgets.dart',
  );
  final detail = File(
    'lib/src/features/parent_child/presentation/check_in_detail_page.dart',
  );

  expect(page, contains("part 'safety_record_widgets.dart';"));
  expect(page, contains("import 'check_in_detail_page.dart';"));
  expect(widgets.existsSync(), isTrue);
  expect(detail.existsSync(), isTrue);
  expect(page, isNot(contains('class CheckInDetailPage')));
  expect(detail.readAsStringSync(), contains('class CheckInDetailPage'));
  expect(widgets.readAsStringSync(), contains('class _RecordTile'));
});
```

- [ ] **Step 2: Run the decomposition test and verify failure**

```powershell
flutter test test/parent_child_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL because the two extracted files do not exist.

- [ ] **Step 3: Extract Safety Records private widgets as a Dart part**

Add to `safety_records_page.dart`:

```dart
import 'check_in_detail_page.dart';

part 'safety_record_widgets.dart';
```

Move these existing classes unchanged into `safety_record_widgets.dart`:

```dart
part of 'safety_records_page.dart';

// Existing classes moved here unchanged:
// _FilterBar, _FilterPill, _DateHeader, _RecordTile, _RecordVisual,
// _TypeChip, _RecordAvatar, _LegacyRecordTile, and _RecordsMessage.
```

Keep `SafetyRecordItem`, `CheckInRecordItem`, `SosRecordItem`, `_RecordFilter`,
`SafetyRecordsPage`, and `_SafetyRecordsPageState` in
`safety_records_page.dart`.

- [ ] **Step 4: Move Check-In detail into its focused public file**

Move the existing `CheckInDetailPage` and `_DetailRow` implementations into
`check_in_detail_page.dart`. Preserve the public constructor:

```dart
class CheckInDetailPage extends StatelessWidget {
  const CheckInDetailPage({super.key, required this.checkIn});

  final SafetyCheckIn checkIn;
}
```

Move the existing `build` method below this declaration byte-for-byte before
formatting, including its Scaffold, map, rows, keys, and copy interaction.

The new file imports Flutter Material, Flutter services, the shared map, and
`parent_supervision_models.dart`. Define detail-only private colour constants
with the same current values required by the extracted build method; do not
change displayed colours during this mechanical step.

Remove the two classes from `safety_records_page.dart`. The page continues
opening `CheckInDetailPage(checkIn: checkIn)` through the same route.

- [ ] **Step 5: Format and run record/detail regressions**

```powershell
dart format lib/src/features/parent_child/presentation/safety_records_page.dart lib/src/features/parent_child/presentation/safety_record_widgets.dart lib/src/features/parent_child/presentation/check_in_detail_page.dart test/parent_child_presentation_decomposition_test.dart
flutter test test/parent_child_presentation_decomposition_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_models_test.dart --no-pub --reporter expanded
```

Expected: PASS with record ordering, filtering, missing SOS hydration, map,
coordinates, and detail navigation unchanged.

- [ ] **Step 6: Commit the Safety Records extraction**

```powershell
git add apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart apps/mobile/lib/src/features/parent_child/presentation/safety_record_widgets.dart apps/mobile/lib/src/features/parent_child/presentation/check_in_detail_page.dart apps/mobile/test/parent_child_presentation_decomposition_test.dart
git commit -m "refactor(mobile): separate safety record presentation"
```

---

### Task 5: Extract SOS presentation widgets

**Files:**

- Create: `apps/mobile/lib/src/features/parent_child/presentation/sos_widgets.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`
- Modify: `apps/mobile/test/parent_child_presentation_decomposition_test.dart`
- Test: `apps/mobile/test/parent_supervision_flows_test.dart`
- Test: `apps/mobile/test/sos_lifecycle_state_test.dart`
- Test: `apps/mobile/test/sos_tracking_coordinator_test.dart`

- [ ] **Step 1: Add the failing SOS decomposition contract**

Append:

```dart
test('SOS page keeps workflow state and delegates presentation widgets', () {
  final page = File(
    'lib/src/features/parent_child/presentation/sos_page.dart',
  ).readAsStringSync();
  final widgets = File(
    'lib/src/features/parent_child/presentation/sos_widgets.dart',
  );

  expect(page, contains("part 'sos_widgets.dart';"));
  expect(widgets.existsSync(), isTrue);
  final widgetSource = widgets.readAsStringSync();
  expect(page, contains('class _SosPageState'));
  expect(page, isNot(contains('class _BottomSosAction')));
  expect(widgetSource, contains('class _BottomSosAction'));
  expect(widgetSource, contains('class _TimelineCard'));
  expect(widgetSource, contains('class _TimelineEventRow'));
  expect(widgetSource, contains('class _DetailCard'));
});
```

- [ ] **Step 2: Run the test and verify the missing-part failure**

```powershell
flutter test test/parent_child_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL because `sos_widgets.dart` does not exist.

- [ ] **Step 3: Extract only the presentation-only SOS classes**

Add after the imports in `sos_page.dart`:

```dart
part 'sos_widgets.dart';
```

Keep `SosPage`, `_SosPageState`, fallback event construction, status labels,
location freshness calculation, realtime handling, and every action method in
`sos_page.dart`.

Move the existing final class block into the new part without changing keys,
text, sizes, colours, or callbacks:

```dart
part of 'sos_page.dart';

// Existing classes moved here unchanged:
// _BottomSosAction, _TimelineCard, _TimelineEventRow, and _DetailCard.
```

- [ ] **Step 4: Format and verify all SOS behaviour**

```powershell
dart format lib/src/features/parent_child/presentation/sos_page.dart lib/src/features/parent_child/presentation/sos_widgets.dart test/parent_child_presentation_decomposition_test.dart
flutter test test/parent_child_presentation_decomposition_test.dart test/parent_supervision_flows_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart --no-pub --reporter expanded
```

Expected: PASS, including trigger confirmation, submission retry,
acknowledge-before-resolve, parent-only resolution, confirmation, timeline,
realtime detail refresh, foreground tracking, and disposal behaviour.

- [ ] **Step 5: Commit the SOS extraction**

```powershell
git add apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart apps/mobile/lib/src/features/parent_child/presentation/sos_widgets.dart apps/mobile/test/parent_child_presentation_decomposition_test.dart
git commit -m "refactor(mobile): extract sos presentation widgets"
```

---

### Task 6: Standardize parent-child feedback and touched design values

**Files:**

- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/check_in_detail_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/sos_widgets.dart`
- Modify: `apps/mobile/test/parent_child_presentation_decomposition_test.dart`
- Test: `apps/mobile/test/app_feedback_test.dart`
- Test: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Add the failing direct-snackbar construction audit**

Append:

```dart
test('parent-child presentation uses the shared feedback facade', () {
  final directory = Directory(
    'lib/src/features/parent_child/presentation',
  );
  final offenders = <String>[];

  for (final entity in directory.listSync()) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    if (source.contains('ScaffoldMessenger.of(') ||
        source.contains('SnackBar(')) {
      offenders.add(entity.path);
    }
  }

  expect(offenders, isEmpty);
});
```

- [ ] **Step 2: Run the audit and verify it reports current offenders**

```powershell
flutter test test/parent_child_presentation_decomposition_test.dart --no-pub --reporter expanded
```

Expected: FAIL and list the existing parent-child files that construct direct
snackbars.

- [ ] **Step 3: Replace direct feedback with the existing facade**

Import where required:

```dart
import '../../../core/widgets/app_feedback.dart';
```

Replace success messages with:

```dart
AppFeedback.showSuccess(context, existingMessage);
```

Replace failure messages with:

```dart
AppFeedback.showError(context, existingMessage);
```

Use `AppFeedback.show` with `AppFeedbackKind.neutral` only for informational
messages such as copied coordinates. Preserve every current message string.

Apply this mapping:

- Parent Supervision candidate-sheet failure: error.
- Link request completed: success.
- Link request failure: error.
- Check-In submitted: success.
- Check-In submission failure: error.
- SOS action failure: error.
- Supervision notification route failure: error.
- Check-In detail coordinates copied: neutral.

Do not change inline form validation or persistent loading/error widgets into
snackbars.

- [ ] **Step 4: Replace only exact touched design-token matches**

In moved or feedback-touched code, replace values only where the shared token
has the same approved value:

```dart
const Color(0xFF0B1F3E) -> AppColors.navy
const Color(0xFF64748B) -> AppColors.textSecondary
const Color(0xFF94A3B8) -> AppColors.textMuted
const Color(0xFFE2E8F0) -> AppColors.border
const Color(0xFFF1F5F9) -> AppColors.surfaceMuted
const Color(0xFFE11D48) -> AppColors.error
EdgeInsets.all(16) -> EdgeInsets.all(AppSpacing.lg)
EdgeInsets.symmetric(horizontal: 20) -> AppInsets.page
BorderRadius.circular(14) -> BorderRadius.circular(AppRadii.compact)
```

Add `app_design_tokens.dart` imports to the owning library file for Dart parts.
Do not replace non-matching colours such as `0xFF087F8C`, and do not alter
layout-specific dimensions.

- [ ] **Step 5: Format and run feedback and parent-child regressions**

```powershell
dart format lib/src/features/parent_child/presentation test/parent_child_presentation_decomposition_test.dart
flutter test test/parent_child_presentation_decomposition_test.dart test/app_feedback_test.dart test/app_confirmation_dialog_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart --no-pub --reporter expanded
```

Expected: PASS. The audit reports no direct snackbar construction, and current
parent-child text and action behaviour remain unchanged.

- [ ] **Step 6: Commit the feedback and token checkpoint**

```powershell
git add apps/mobile/lib/src/features/parent_child/presentation apps/mobile/test/parent_child_presentation_decomposition_test.dart
git commit -m "refactor(mobile): standardize supervision feedback"
```

---

### Task 7: Complete the Phase 5A verification gate

**Files:**

- Verify: all Phase 5A production and test files
- Modify only if a verified Phase 5A regression is found

- [ ] **Step 1: Run shared refresh and chat lifecycle tests**

```powershell
flutter test test/chat_refresh_coordinator_test.dart test/chat_realtime_lifecycle_test.dart test/chat_repository_test.dart test/chat_widgets_test.dart --no-pub --reporter expanded
```

Expected: all selected tests PASS with no chat behaviour change after the core
coordinator move.

- [ ] **Step 2: Run the complete related parent-child suite**

```powershell
flutter test test/parent_child_presentation_decomposition_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_models_test.dart test/parent_child_repository_test.dart test/parent_supervision_sql_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart test/app_feedback_test.dart test/app_confirmation_dialog_test.dart --no-pub --reporter expanded
```

Expected: all selected tests PASS with zero failures.

- [ ] **Step 3: Run Flutter analysis**

```powershell
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4: Run strict formatting for every changed Dart file**

```powershell
dart format --output=none --set-exit-if-changed lib/src/core/application/async_refresh_coordinator.dart lib/src/features/chat/presentation/chat_page.dart lib/src/features/chat/presentation/chat_room_page.dart lib/src/features/chat/presentation/notification_sections_page.dart lib/src/features/parent_child/presentation/parent_child_page.dart lib/src/features/parent_child/presentation/family_links_page.dart lib/src/features/parent_child/presentation/family_links_widgets.dart lib/src/features/parent_child/presentation/safety_records_page.dart lib/src/features/parent_child/presentation/safety_record_widgets.dart lib/src/features/parent_child/presentation/check_in_detail_page.dart lib/src/features/parent_child/presentation/sos_page.dart lib/src/features/parent_child/presentation/sos_widgets.dart lib/src/features/parent_child/presentation/check_in_page.dart lib/src/features/parent_child/presentation/link_candidates_page.dart lib/src/features/parent_child/presentation/supervision_notification_router.dart test/chat_refresh_coordinator_test.dart test/chat_realtime_lifecycle_test.dart test/parent_supervision_flows_test.dart test/parent_child_presentation_decomposition_test.dart
```

Expected: formatting reports zero changed files.

- [ ] **Step 5: Verify repository scope and stale coordinator references**

Run from the repository root:

```powershell
rg -n "ChatRefreshCoordinator|chat_refresh_coordinator" apps/mobile/lib apps/mobile/test
git diff --check
git status --short --branch
```

Expected: `rg` exits 1 with no stale references, `git diff --check` prints no
errors, and only intentional Phase 5A files are changed before the final
commit.

- [ ] **Step 6: Perform the short Android acceptance check**

On the available Android phone, verify:

1. Parent Supervision loads and pull-to-refresh works.
2. The family-link candidate sheet opens, searches, and closes normally.
3. Family Links actions and confirmation dialogs remain correct.
4. Check-In validation, optional location, and successful return remain
   correct.
5. SOS trigger, live map, timeline, Acknowledge, Resolve confirmation, and
   parent-only resolution remain correct.
6. Safety Records list and Check-In/SOS details open normally.
7. Background and resume CyanZone; the dashboard refreshes without duplicate
   rows or visible stale state.
8. The floating navigation does not cover dashboard actions or record content.

Expected: no visible redesign, no duplicate refresh symptoms, and no broken
navigation or interaction. Record unavailable physical-device evidence rather
than assuming it passed.

- [ ] **Step 7: Record a verification-only correction only when necessary**

If verification finds a Phase 5A defect, first add a failing assertion to the
nearest listed test, apply only that correction, and repeat Steps 1-5. Do not
create an empty commit. Commit a real correction as:

```powershell
git add apps/mobile
git commit -m "fix(mobile): close supervision refactor gaps"
```

## Completion gate

Phase 5A is complete only when both related test groups pass, Flutter analysis
is clean, formatting and `git diff --check` are clean, no stale chat-specific
coordinator reference remains, each lifecycle resource has one disposal owner,
and manual Android evidence is either completed or explicitly recorded as
pending.

After this gate, begin a separately designed Phase 5B for profile presentation.
