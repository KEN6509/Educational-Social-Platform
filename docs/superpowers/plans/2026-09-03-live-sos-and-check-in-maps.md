# Live SOS and Check-In Maps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add foreground-only 10-second SOS location tracking, multiple-parent acknowledgement and event timelines, an OpenStreetMap moving pin for SOS, and a fixed OpenStreetMap pin for Check-In details.

**Architecture:** Keep the existing Parent Supervision repository boundary, add server-authoritative latest-location and timeline storage, and introduce an app-scoped `SosTrackingCoordinator` as a Facade. Flutter lifecycle, coordinator notifications, and Supabase Realtime implement Observer behaviour; SOS lifecycle classes implement State behaviour; plugin coordinates are adapted into CyanZone-owned models.

**Tech Stack:** Flutter/Dart, `geolocator`, `flutter_map`, `latlong2`, Supabase PostgreSQL/RPC/RLS/Realtime, Flutter widget and unit tests.

---

## File Structure

**Create**

- `apps/mobile/lib/src/core/widgets/app_location_map.dart` — reusable OpenStreetMap with fixed/live marker modes and attribution.
- `apps/mobile/lib/src/features/parent_child/domain/sos_lifecycle_state.dart` — GoF State objects for action and tracking rules.
- `apps/mobile/lib/src/features/parent_child/services/sos_tracking_coordinator.dart` — app-scoped foreground tracking Facade.
- `apps/mobile/lib/src/features/parent_child/presentation/sos_tracking_scope.dart` — owns the coordinator above `MainShell` and forwards lifecycle changes.
- `apps/mobile/test/app_location_map_test.dart` — reusable map behaviour.
- `apps/mobile/test/sos_lifecycle_state_test.dart` — lifecycle and per-parent action rules.
- `apps/mobile/test/sos_tracking_coordinator_test.dart` — timing, retry, recovery, lifecycle, and resolution.

**Modify**

- `apps/mobile/pubspec.yaml` — add `flutter_map` and `latlong2`.
- `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart` — wrap authenticated UI in `SosTrackingHost`.
- `apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart` — add live-location, timeline-event, and aggregate detail models.
- `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart` — add active SOS, detail, location update, and focused realtime operations.
- `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart` — give new SOS sessions to the app-scoped coordinator.
- `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart` — render realtime map/timeline and state-dependent bottom action.
- `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart` — add the fixed Check-In map below coordinates.
- `apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart` — open hydrated realtime SOS detail.
- `apps/mobile/test/location_service_test.dart` — preserve one-time capture behaviour used by scheduled tracking.
- `apps/mobile/test/parent_supervision_flows_test.dart` — cover SOS and Check-In UI flows.
- `apps/mobile/test/parent_supervision_sql_test.dart` — cover new database objects and security rules.
- `supabase/parent_supervision.sql` — idempotent existing-project upgrade.
- `supabase/schema.sql` — canonical fresh-project schema.
- `supabase/README.md` — deployment and verification queries.
- `Project_Overview.md` — implemented behaviour, dependencies, pattern use, and remaining device evidence.

## Task 1: Add OpenStreetMap dependency and reusable map

**Files:**

- Modify: `apps/mobile/pubspec.yaml`
- Create: `apps/mobile/lib/src/core/widgets/app_location_map.dart`
- Create: `apps/mobile/test/app_location_map_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Add tests that construct an available `LocationCapture`, render
`AppLocationMap(location: location, mode: AppLocationMapMode.fixed)`, and
assert keys `app-location-map`, `app-location-marker`, and
`app-location-attribution` exist. Add a live-mode test that rebuilds with new
coordinates and verifies the keyed marker receives the new `LatLng`.

```dart
testWidgets('renders fixed marker and OpenStreetMap attribution', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: AppLocationMap(
      location: LocationCapture.available(
        latitude: 2.03454,
        longitude: 103.29548,
        accuracyMeters: 12,
        capturedAt: DateTime.utc(2026, 9, 3, 7),
      ),
      mode: AppLocationMapMode.fixed,
    ),
  ));
  expect(find.byKey(const Key('app-location-map')), findsOneWidget);
  expect(find.byKey(const Key('app-location-marker')), findsOneWidget);
  expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test and verify the expected failure**

Run:

```powershell
flutter test test/app_location_map_test.dart
```

Expected: compilation fails because `AppLocationMap` does not exist.

- [ ] **Step 3: Add dependencies and implement the component**

Run in `apps/mobile`:

```powershell
flutter pub add flutter_map latlong2
```

Implement a constrained map using `FlutterMap`, `TileLayer`, `MarkerLayer`, and
`RichAttributionWidget`. Keep the tile URL configurable and do not expose
plugin `LatLng` outside this widget.

```dart
enum AppLocationMapMode { fixed, live }

class AppLocationMap extends StatelessWidget {
  const AppLocationMap({
    required this.location,
    required this.mode,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    super.key,
  });

  final LocationCapture location;
  final AppLocationMapMode mode;
  final String tileUrl;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(location.latitude!, location.longitude!);
    return SizedBox(
      key: const Key('app-location-map'),
      height: 220,
      child: FlutterMap(
        options: MapOptions(initialCenter: point, initialZoom: 16),
        children: [
          TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.cyanzone.mobile'),
          MarkerLayer(markers: [
            Marker(
              key: const Key('app-location-marker'),
              point: point,
              width: 48,
              height: 48,
              child: Icon(
                mode == AppLocationMapMode.live
                    ? Icons.my_location_rounded
                    : Icons.location_on_rounded,
              ),
            ),
          ]),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Format and verify**

Run:

```powershell
dart format lib/src/core/widgets/app_location_map.dart test/app_location_map_test.dart
flutter test test/app_location_map_test.dart
```

Expected: map tests pass without requiring a successful network tile response.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/lib/src/core/widgets/app_location_map.dart apps/mobile/test/app_location_map_test.dart
git commit -m "feat: add reusable OpenStreetMap location view"
```

## Task 2: Add SOS domain models and State pattern

**Files:**

- Modify: `apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart`
- Create: `apps/mobile/lib/src/features/parent_child/domain/sos_lifecycle_state.dart`
- Create: `apps/mobile/test/sos_lifecycle_state_test.dart`

- [ ] **Step 1: Write failing model and state tests**

Cover JSON parsing for `SosLiveLocation` and `SosEvent`, chronological event
sorting in `SosDetail`, and these action rules:

```dart
expect(OpenSosState().actionFor(hasCurrentParentAcknowledged: false),
    SosParentAction.acknowledge);
expect(AcknowledgedSosState().actionFor(
    hasCurrentParentAcknowledged: false), SosParentAction.acknowledge);
expect(AcknowledgedSosState().actionFor(
    hasCurrentParentAcknowledged: true), SosParentAction.resolve);
expect(ResolvedSosState().actionFor(
    hasCurrentParentAcknowledged: true), SosParentAction.none);
expect(ResolvedSosState().trackingAllowed, isFalse);
```

- [ ] **Step 2: Run tests to verify failure**

```powershell
flutter test test/sos_lifecycle_state_test.dart
```

Expected: missing model/state types.

- [ ] **Step 3: Implement immutable models and lifecycle states**

Add `SosEventType`, `SosEvent`, `SosLiveLocation`, and `SosDetail` with typed
`fromMap` constructors. Implement:

```dart
enum SosParentAction { acknowledge, resolve, none }

sealed class SosLifecycleState {
  const SosLifecycleState();
  bool get trackingAllowed;
  SosParentAction actionFor({required bool hasCurrentParentAcknowledged});
}

base class OpenSosState extends SosLifecycleState {
  const OpenSosState();
  @override
  bool get trackingAllowed => true;
  @override
  SosParentAction actionFor({required bool hasCurrentParentAcknowledged}) =>
      hasCurrentParentAcknowledged
          ? SosParentAction.resolve
          : SosParentAction.acknowledge;
}

final class AcknowledgedSosState extends OpenSosState {
  const AcknowledgedSosState();
}

final class ResolvedSosState extends SosLifecycleState {
  const ResolvedSosState();
  @override
  bool get trackingAllowed => false;
  @override
  SosParentAction actionFor({required bool hasCurrentParentAcknowledged}) =>
      SosParentAction.none;
}
```

Add a factory that maps `SosStatus` to the matching state. Give
`SosLiveLocation` a `toLocationCapture()` adapter so both live SOS and fixed
Check-In maps consume the same CyanZone-owned `LocationCapture` input.

- [ ] **Step 4: Format and verify**

```powershell
dart format lib/src/features/parent_child/data/parent_supervision_models.dart lib/src/features/parent_child/domain/sos_lifecycle_state.dart test/sos_lifecycle_state_test.dart
flutter test test/sos_lifecycle_state_test.dart
```

Expected: all state/model tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart apps/mobile/lib/src/features/parent_child/domain/sos_lifecycle_state.dart apps/mobile/test/sos_lifecycle_state_test.dart
git commit -m "feat: model live SOS lifecycle and timeline"
```

## Task 3: Extend the server-authoritative SOS contract

**Files:**

- Modify: `supabase/parent_supervision.sql`
- Modify: `supabase/schema.sql`
- Modify: `apps/mobile/test/parent_supervision_sql_test.dart`

- [ ] **Step 1: Write failing SQL contract tests**

Assert both SQL files contain:

```dart
for (final token in [
  'create table if not exists public.sos_live_locations',
  'create table if not exists public.sos_events',
  'update_sos_live_location',
  'fetch_active_sos_alert',
  "'triggered'",
  "'acknowledged'",
  "'resolved'",
  'sos_events_one_parent_ack_idx',
  'Current parent must acknowledge before resolving',
  'alter publication supabase_realtime add table public.sos_live_locations',
  'alter publication supabase_realtime add table public.sos_events',
]) {
  expect(migration, contains(token));
  expect(schema, contains(token));
}
```

- [ ] **Step 2: Run the SQL tests to verify failure**

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: missing live-location/event objects.

- [ ] **Step 3: Implement tables, indexes, RLS, grants, and Realtime**

Create one-row latest-location storage and append-only events. Add unique
partial indexes equivalent to:

```sql
create unique index if not exists sos_events_one_parent_ack_idx
on public.sos_events (sos_id, actor_user_id)
where event_type = 'acknowledged';

create unique index if not exists sos_events_one_resolution_idx
on public.sos_events (sos_id)
where event_type = 'resolved';
```

Use owner/active-family select policies and revoke direct writes from
`authenticated`.

- [ ] **Step 4: Replace RPCs atomically**

Update `submit_sos_alert` to insert the triggered event and initial live row.
Allow acknowledgements when status is `open` or `acknowledged`, insert one event
per parent with `on conflict do nothing`, and change status on the first
acknowledgement. Resolve only when an acknowledgement event exists for
`auth.uid()`. Add `update_sos_live_location` that updates only the caller's
unresolved SOS and `fetch_active_sos_alert` that returns the caller's newest
unresolved alert.

- [ ] **Step 5: Verify and commit**

```powershell
flutter test test/parent_supervision_sql_test.dart
git diff --check -- supabase/parent_supervision.sql supabase/schema.sql apps/mobile/test/parent_supervision_sql_test.dart
git add supabase/parent_supervision.sql supabase/schema.sql apps/mobile/test/parent_supervision_sql_test.dart
git commit -m "feat: add live SOS location and event storage"
```

Expected: SQL contract tests pass and Git reports no whitespace errors.

## Task 4: Extend the Parent Supervision repository

**Files:**

- Modify: `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart`
- Modify: `apps/mobile/test/parent_child_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Use the existing fake Supabase style to verify these contract methods and RPC
parameters:

```dart
Future<SosAlert?> fetchActiveSos();
Future<SosDetail> fetchSosDetail(String sosId);
Future<SosLiveLocation> updateSosLocation(
  String sosId,
  LocationCapture location,
);
RealtimeChannel subscribeToSosDetailChanges({
  required String sosId,
  required void Function() onChange,
});
```

Assert `update_sos_live_location` receives latitude, longitude, accuracy, and
captured timestamp, and that the focused realtime channel observes
`sos_alerts`, `sos_live_locations`, and `sos_events` for the requested SOS.

- [ ] **Step 2: Run the repository tests to verify failure**

```powershell
flutter test test/parent_child_repository_test.dart
```

Expected: repository contract methods are missing.

- [ ] **Step 3: Implement hydration and subscriptions**

Fetch the base alert, latest-location row, ordered events, and the current
user's acknowledgement flag. Parse all rows through the new model adapters.
Keep Supabase maps inside the data layer.

- [ ] **Step 4: Format and verify**

```powershell
dart format lib/src/features/parent_child/data/parent_child_repository.dart test/parent_child_repository_test.dart
flutter test test/parent_child_repository_test.dart test/parent_supervision_sql_test.dart
```

Expected: repository and SQL tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart apps/mobile/test/parent_child_repository_test.dart
git commit -m "feat: expose live SOS repository operations"
```

## Task 5: Implement the foreground tracking Facade

**Files:**

- Create: `apps/mobile/lib/src/features/parent_child/services/sos_tracking_coordinator.dart`
- Create: `apps/mobile/test/sos_tracking_coordinator_test.dart`
- Modify: `apps/mobile/test/location_service_test.dart`

- [ ] **Step 1: Write failing coordinator tests with fake time triggers**

Inject a scheduler callback instead of waiting ten real seconds. Cover:

- start immediately captures and uploads
- later ticks do not overlap an in-flight capture
- a failed upload retains the point and retries
- background cancels scheduled work
- foreground fetches the active alert and resumes
- resolved realtime refresh stops work
- dispose cancels timers and realtime channels

Define the scheduler seam used by tests:

```dart
abstract interface class SosTrackingSchedule {
  void start(Duration interval, void Function() onTick);
  void stop();
}
```

- [ ] **Step 2: Run tests to verify failure**

```powershell
flutter test test/sos_tracking_coordinator_test.dart test/location_service_test.dart
```

Expected: coordinator and schedule types are missing.

- [ ] **Step 3: Implement `SosTrackingCoordinator`**

Use a `ChangeNotifier` Facade with a production timer schedule. Its core API is:

```dart
final class SosTrackingCoordinator extends ChangeNotifier {
  Future<void> start(SosAlert alert);
  Future<void> onForeground();
  void onBackground();
  Future<void> stop();
  SosTrackingSnapshot get snapshot;
}
```

Set the production interval to `const Duration(seconds: 10)`. Keep at most one
capture/upload active. Before resuming, call `fetchActiveSos`; before uploading,
ensure the in-memory alert is unresolved. When the focused alert subscription
fires, refetch and stop on `resolved`.

- [ ] **Step 4: Format and verify**

```powershell
dart format lib/src/features/parent_child/services/sos_tracking_coordinator.dart test/sos_tracking_coordinator_test.dart test/location_service_test.dart
flutter test test/sos_tracking_coordinator_test.dart test/location_service_test.dart
```

Expected: coordinator tests pass without real timers, GPS, network, or Supabase.

- [ ] **Step 5: Commit**

```powershell
git add apps/mobile/lib/src/features/parent_child/services/sos_tracking_coordinator.dart apps/mobile/test/sos_tracking_coordinator_test.dart apps/mobile/test/location_service_test.dart
git commit -m "feat: coordinate foreground SOS tracking"
```

## Task 6: Host tracking across authenticated pages

**Files:**

- Create: `apps/mobile/lib/src/features/parent_child/presentation/sos_tracking_scope.dart`
- Modify: `apps/mobile/lib/src/features/auth/presentation/auth_gate.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Write failing host lifecycle tests**

Render the host with a fake coordinator and assert:

- authenticated host calls foreground recovery
- `AppLifecycleState.paused` calls `onBackground`
- `AppLifecycleState.resumed` calls `onForeground`
- disposing/signing out stops and disposes tracking
- starting an SOS through `ParentChildPage` passes the returned alert to the
  scoped coordinator

- [ ] **Step 2: Run the focused tests to verify failure**

```powershell
flutter test test/parent_supervision_flows_test.dart --plain-name "SOS tracking host"
```

Expected: `SosTrackingHost` is missing.

- [ ] **Step 3: Implement the host and scope**

Implement `SosTrackingHost` as a `StatefulWidget` with
`WidgetsBindingObserver`. Expose the coordinator through an
`InheritedNotifier<SosTrackingCoordinator>`. In `AuthGate`, wrap only the
authenticated `MainShell`; the unauthenticated `AuthPage` never owns tracking.

- [ ] **Step 4: Connect SOS creation**

After `submitSos` succeeds, call:

```dart
await SosTrackingScope.read(context).start(alert);
```

Keep constructor injection available so existing tests can provide fakes.

- [ ] **Step 5: Format, verify, and commit**

```powershell
dart format lib/src/features/parent_child/presentation/sos_tracking_scope.dart lib/src/features/auth/presentation/auth_gate.dart lib/src/features/parent_child/presentation/parent_child_page.dart test/parent_supervision_flows_test.dart
flutter test test/parent_supervision_flows_test.dart test/sos_tracking_coordinator_test.dart
git add apps/mobile/lib/src/features/parent_child/presentation/sos_tracking_scope.dart apps/mobile/lib/src/features/auth/presentation/auth_gate.dart apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "feat: host SOS tracking across foreground pages"
```

Expected: focused host and Parent Supervision flows pass.

## Task 7: Build the realtime SOS detail UI

**Files:**

- Modify: `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Write failing SOS detail widget tests**

Cover:

- coordinates remain visible and `AppLocationMap` appears directly below
- timeline entries render in chronological order and refresh after callback
- another parent's acknowledgement does not unlock Resolve for current parent
- current parent's Acknowledge button is replaced by Resolve after success
- Resolve opens the shared confirmation dialog
- confirmed Resolve removes the action and stops the scoped tracker
- stale location uses `Last updated ...`, not `Live`
- missing/unavailable location does not render an empty map

- [ ] **Step 2: Run targeted tests to verify failure**

```powershell
flutter test test/parent_supervision_flows_test.dart --plain-name "SOS detail"
```

Expected: aggregate detail, timeline, map, or state-dependent assertions fail.

- [ ] **Step 3: Split and implement focused UI components**

Keep `SosPage` as coordinator and extract within the feature:

```text
SosLocationSection  - existing coordinate row + map + freshness
SosTimeline         - ordered event rows
SosBottomAction     - one state-dependent action
```

Subscribe with `subscribeToSosDetailChanges`, debounce bursts, and call
`fetchSosDetail`. Use `SosLifecycleState.actionFor` for the bottom action. Use
`showAppConfirmationDialog` before `resolveSos` with copy explaining that live
tracking will stop.

- [ ] **Step 4: Update notification and record entry points**

Ensure records and supervision notifications open `SosPage` with the same
repository and alert ID, allowing the page to hydrate `SosDetail` and subscribe
instead of displaying a permanently stale `initialAlert`.

- [ ] **Step 5: Format, verify, and commit**

```powershell
dart format lib/src/features/parent_child/presentation/sos_page.dart lib/src/features/parent_child/presentation/safety_records_page.dart lib/src/features/parent_child/presentation/supervision_notification_router.dart test/parent_supervision_flows_test.dart
flutter test test/parent_supervision_flows_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart
git add apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "feat: show live SOS map actions and timeline"
```

Expected: all focused SOS flows pass.

## Task 8: Add the fixed Check-In detail map

**Files:**

- Modify: `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Write failing Check-In map tests**

Assert an available location retains the coordinate `_DetailRow` and renders
`AppLocationMap` immediately after it in fixed mode. Assert `notRequested` and
`unavailable` states retain their current text and render no map.

- [ ] **Step 2: Run targeted tests to verify failure**

```powershell
flutter test test/parent_supervision_flows_test.dart --plain-name "check in detail"
```

Expected: fixed map assertion fails.

- [ ] **Step 3: Implement the minimal layout addition**

After the existing location row, conditionally add spacing and:

```dart
if (checkIn.location.status == LocationStatus.available) ...[
  const SizedBox(height: 12),
  AppLocationMap(
    location: checkIn.location,
    mode: AppLocationMapMode.fixed,
  ),
]
```

- [ ] **Step 4: Format, verify, and commit**

```powershell
dart format lib/src/features/parent_child/presentation/safety_records_page.dart test/parent_supervision_flows_test.dart
flutter test test/parent_supervision_flows_test.dart test/app_location_map_test.dart
git add apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart apps/mobile/test/parent_supervision_flows_test.dart
git commit -m "feat: map safety check-in locations"
```

Expected: available and unavailable Check-In map tests pass.

## Task 9: Document deployment and verify the feature

**Files:**

- Modify: `supabase/README.md`
- Modify: `Project_Overview.md`

- [ ] **Step 1: Update deployment documentation**

Add the two tables and new RPC to verification queries. State that the full
updated `parent_supervision.sql` must be rerun, existing records are preserved,
OpenStreetMap tiles are best-effort for MVP/UAT, tracking is foreground-only,
and real-device evidence remains manual.

- [ ] **Step 2: Run focused formatting, tests, and analysis**

```powershell
dart format lib/src/core/widgets/app_location_map.dart lib/src/features/parent_child test/app_location_map_test.dart test/location_service_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart test/parent_child_repository_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
flutter test test/app_location_map_test.dart test/location_service_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart test/parent_child_repository_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
flutter analyze lib/src/core/widgets/app_location_map.dart lib/src/features/parent_child test/app_location_map_test.dart test/location_service_test.dart test/sos_lifecycle_state_test.dart test/sos_tracking_coordinator_test.dart test/parent_child_repository_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
```

Expected: every focused test passes and analyzer prints `No issues found!`.

- [ ] **Step 3: Inspect the final diff and documentation**

```powershell
git diff --check
git status --short
git diff --stat
```

Confirm the five pre-existing deleted visual-QA PNGs remain unstaged and are
not included in feature commits.

- [ ] **Step 4: Commit documentation**

```powershell
git add supabase/README.md Project_Overview.md
git commit -m "docs: describe live SOS and map rollout"
```

- [ ] **Step 5: Report the manual acceptance steps**

Provide the user with:

1. Run the complete updated `supabase/parent_supervision.sql`.
2. Launch child and parent accounts on separate devices or sessions.
3. Verify foreground movement updates approximately every 10 seconds.
4. Verify minimizing the child app pauses freshness and returning resumes it.
5. Verify each parent must acknowledge before Resolve appears.
6. Verify Resolve confirmation stops all later location changes.
7. Verify a Check-In with location shows coordinates plus a fixed map.

Do not claim real GPS, OpenStreetMap networking, or deployed SQL is verified
until the user completes those external checks.
