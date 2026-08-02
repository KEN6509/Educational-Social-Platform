# Parent Supervision Linking, Safety, and Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved Parent Supervision module with secure parent-child linking, role dashboards, own-app screen-time monitoring, optional-location Check-Ins, mandatory-attempt-location SOS, and a separate ten-item realtime supervision feed.

**Architecture:** Supabase remains authoritative for roles, relationship transitions, safety records, notification fan-out, and screen-time threshold deduplication through security-definer RPCs protected by RLS. Flutter uses typed models and an injectable repository, a geolocator-backed location service, and a shell-owned persisted foreground tracker; the Parent Supervision page composes explicit unlinked, child, and parent dashboards and refreshes after realtime or lifecycle events.

**Tech Stack:** PostgreSQL/Supabase SQL, Supabase Realtime, Flutter/Dart, `supabase_flutter`, `shared_preferences`, `geolocator: ^14.0.3`, Flutter widget/unit tests.

---

## File Structure

### Database

- Create `supabase/parent_supervision.sql`: idempotent migration, RLS, RPCs, indexes, realtime publication, and grants for the complete module.
- Modify `supabase/schema.sql`: canonical clean-install equivalent of the migration.
- Modify `supabase/README.md`: application order and live verification queries.
- Create `apps/mobile/test/parent_supervision_sql_test.dart`: executable source-contract tests for the migration and canonical schema.

### Mobile data and services

- Create `apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart`: enums and immutable typed records for dashboards, links, candidates, screen time, Check-Ins, SOS, and supervision events.
- Replace `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart`: repository interface plus Supabase implementation; all sensitive changes call RPCs.
- Create `apps/mobile/lib/src/features/parent_child/services/location_service.dart`: injectable location capture contract and geolocator implementation.
- Create `apps/mobile/lib/src/features/parent_child/services/screen_time_tracker.dart`: persisted foreground session queue and synchronization.
- Modify `apps/mobile/pubspec.yaml`: add `geolocator: ^14.0.3`.
- Modify `apps/mobile/android/app/src/main/AndroidManifest.xml`: add coarse/fine foreground location permissions.
- Modify `apps/mobile/ios/Runner/Info.plist`: add the when-in-use location explanation.
- Modify `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`: own the screen-time tracker lifecycle.

### Mobile presentation

- Replace `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`: coordinator, refresh, realtime ownership, and dependency injection.
- Create `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart`: shared screen-time, family summary, safety action, record summary, and event widgets.
- Create `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart`: explicit unlinked, child, and parent page compositions.
- Create `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`: Followers/Following search, role confirmation, and request action.
- Create `apps/mobile/lib/src/features/parent_child/presentation/link_request_page.dart`: pending request detail with accept/reject/cancel.
- Create `apps/mobile/lib/src/features/parent_child/presentation/family_links_page.dart`: active/pending family list and child screen-time detail.
- Create `apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart`: required-message form and optional location flow.
- Create `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`: confirmation, mandatory location attempt, SOS detail, acknowledgement, and resolution.
- Create `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart`: parent Check-In/SOS record list and detail routing.
- Create `apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart`: typed event destinations and read marking.

### Mobile tests

- Create `apps/mobile/test/parent_supervision_models_test.dart`.
- Create `apps/mobile/test/parent_child_repository_test.dart`.
- Create `apps/mobile/test/location_service_test.dart`.
- Create `apps/mobile/test/screen_time_tracker_test.dart`.
- Create `apps/mobile/test/parent_supervision_page_test.dart`.
- Create `apps/mobile/test/parent_supervision_flows_test.dart`.

## Implementation Rules

- Run every command directly in the user's PowerShell terminal, never in a sandbox.
- Preserve all unrelated uncommitted files; stage only paths listed by the current task.
- Follow TDD: add a focused failing test, run it and observe the expected failure, add the minimum implementation, rerun, then commit.
- Never make link, Check-In, SOS, acknowledgement, resolution, or threshold state authoritative in Flutter. Refresh the server-confirmed state after each mutation.
- Do not add FCM, background location, active-link unlinking, geofencing, or continuous location tracking.

### Task 1: Add the Parent Supervision database foundation

**Files:**
- Create: `apps/mobile/test/parent_supervision_sql_test.dart`
- Create: `supabase/parent_supervision.sql`

- [ ] **Step 1: Write the failing migration contract tests**

Create tests that read the SQL as text and require the exact durable objects:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File('../../supabase/parent_supervision.sql').readAsStringSync();
  });

  test('creates dedicated supervision storage and cancellation state', () {
    expect(migration, contains("alter type public.link_status add value 'cancelled'"));
    expect(migration, contains('create table if not exists public.supervision_notifications'));
    expect(migration, contains('create table if not exists public.screen_time_sync_events'));
    expect(migration, contains('create table if not exists public.screen_time_threshold_events'));
    expect(migration, contains('parent_child_links_one_live_pair_idx'));
    expect(migration, contains('supervision_notifications_user_created_idx'));
  });

  test('removes direct sensitive writes and enables owner-scoped reads', () {
    expect(migration, contains('revoke insert, update, delete on public.parent_child_links from authenticated'));
    expect(migration, contains('revoke insert, update, delete on public.check_ins from authenticated'));
    expect(migration, contains('revoke insert, update, delete on public.sos_alerts from authenticated'));
    expect(migration, contains('Users view own supervision notifications'));
    expect(migration, contains('Active family views child safety records'));
  });

  test('publishes live supervision tables', () {
    expect(migration, contains('alter publication supabase_realtime add table public.parent_child_links'));
    expect(migration, contains('alter publication supabase_realtime add table public.sos_alerts'));
    expect(migration, contains('alter publication supabase_realtime add table public.supervision_notifications'));
  });
}
```

- [ ] **Step 2: Run the contract test and verify it fails**

Run from `apps/mobile`:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: FAIL because `../../supabase/parent_supervision.sql` does not exist.

- [ ] **Step 3: Create the idempotent table migration**

Create `supabase/parent_supervision.sql` with these concrete changes:

```sql
do $$
begin
  alter type public.link_status add value 'cancelled';
exception
  when duplicate_object then null;
end $$;

alter table public.parent_child_links
  add column if not exists responded_at timestamptz,
  add column if not exists cancelled_at timestamptz;

alter table public.parent_child_links
  drop constraint if exists parent_child_links_parent_id_child_id_key;

create unique index if not exists parent_child_links_one_live_pair_idx
on public.parent_child_links (
  least(parent_id, child_id),
  greatest(parent_id, child_id)
)
where status in ('pending', 'active');

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'screen_time_logs'
      and column_name = 'child_id'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'screen_time_logs'
      and column_name = 'user_id'
  ) then
    alter table public.screen_time_logs rename column child_id to user_id;
  end if;
end $$;

alter table public.screen_time_logs
  add column if not exists seconds_used integer not null default 0
    check (seconds_used between 0 and 86400);

update public.screen_time_logs
set seconds_used = minutes_used * 60
where seconds_used = 0 and minutes_used > 0;

create table if not exists public.screen_time_sync_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_session_id text not null,
  local_day date not null,
  seconds_used integer not null check (seconds_used > 0 and seconds_used <= 86400),
  timezone_offset_minutes integer not null check (timezone_offset_minutes between -840 and 840),
  created_at timestamptz not null default now(),
  unique (user_id, client_session_id)
);

create table if not exists public.screen_time_threshold_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_day date not null,
  threshold_hours integer not null check (threshold_hours >= 3),
  created_at timestamptz not null default now(),
  unique (user_id, local_day, threshold_hours)
);

alter table public.check_ins
  add column if not exists message text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists accuracy_meters double precision,
  add column if not exists location_captured_at timestamptz,
  add column if not exists location_status text not null default 'not_requested'
    check (location_status in ('not_requested', 'available', 'unavailable'));

update public.check_ins
set message = coalesce(nullif(btrim(note), ''), 'Safety Check-In')
where message is null;

alter table public.check_ins
  alter column message set not null,
  alter column mood drop not null;

alter table public.check_ins
  drop constraint if exists check_ins_message_length_check;
alter table public.check_ins
  add constraint check_ins_message_length_check
  check (char_length(btrim(message)) between 1 and 280);

alter table public.sos_alerts
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists accuracy_meters double precision,
  add column if not exists location_captured_at timestamptz,
  add column if not exists location_status text not null default 'unavailable'
    check (location_status in ('available', 'unavailable')),
  add column if not exists location_failure text,
  add column if not exists resolved_by uuid references public.profiles(id) on delete set null;

create table if not exists public.supervision_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in (
    'link_request', 'link_accepted', 'link_rejected', 'link_cancelled',
    'check_in_sent', 'check_in_received', 'sos_opened',
    'sos_acknowledged', 'sos_resolved', 'screen_time_threshold'
  )),
  title text not null,
  body text not null,
  event_key text not null,
  link_id uuid references public.parent_child_links(id) on delete set null,
  check_in_id uuid references public.check_ins(id) on delete set null,
  sos_id uuid references public.sos_alerts(id) on delete set null,
  child_id uuid references public.profiles(id) on delete set null,
  threshold_hours integer,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, event_key)
);

create index if not exists supervision_notifications_user_created_idx
on public.supervision_notifications(user_id, created_at desc);
```

Enable RLS, remove direct mutations, and add these access rules:

```sql
alter table public.screen_time_sync_events enable row level security;
alter table public.screen_time_threshold_events enable row level security;
alter table public.supervision_notifications enable row level security;

drop policy if exists "Users can request family links" on public.parent_child_links;
drop policy if exists "Linked family can update links" on public.parent_child_links;
drop policy if exists "Family can add screen time" on public.screen_time_logs;
drop policy if exists "Users can create own check-ins" on public.check_ins;
drop policy if exists "Children can create sos alerts" on public.sos_alerts;
drop policy if exists "Linked parents can update sos alerts" on public.sos_alerts;

drop policy if exists "Users view own supervision notifications"
on public.supervision_notifications;
create policy "Users view own supervision notifications"
on public.supervision_notifications for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Users view own screen time sync events"
on public.screen_time_sync_events;
create policy "Users view own screen time sync events"
on public.screen_time_sync_events for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Users view own threshold events"
on public.screen_time_threshold_events;
create policy "Users view own threshold events"
on public.screen_time_threshold_events for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Active family views child safety records" on public.check_ins;
create policy "Active family views child safety records"
on public.check_ins for select to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = check_ins.user_id
      and link.status = 'active'
  )
);

drop policy if exists "Active family views child SOS records" on public.sos_alerts;
create policy "Active family views child SOS records"
on public.sos_alerts for select to authenticated
using (
  child_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = sos_alerts.child_id
      and link.status = 'active'
  )
);

revoke insert, update, delete on public.parent_child_links from authenticated;
revoke insert, update, delete on public.screen_time_logs from authenticated;
revoke insert, update, delete on public.screen_time_sync_events from authenticated;
revoke insert, update, delete on public.screen_time_threshold_events from authenticated;
revoke insert, update, delete on public.check_ins from authenticated;
revoke insert, update, delete on public.sos_alerts from authenticated;
revoke insert, update, delete on public.supervision_notifications from authenticated;
```

Replace the existing screen-time Select policy with `user_id = auth.uid()` or an active link where the current user is the parent and `screen_time_logs.user_id` is the child. Retain the participant-only link Select policy.

For each of `parent_child_links`, `sos_alerts`, and `supervision_notifications`, add an idempotent `pg_publication_tables` guard followed by `alter publication supabase_realtime add table public.<table>`.

- [ ] **Step 4: Run the SQL contract test**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: PASS for the table, RLS/revoke, index, and publication contracts.

- [ ] **Step 5: Commit the foundation**

```powershell
git add -- ../../supabase/parent_supervision.sql test/parent_supervision_sql_test.dart
git commit -m "feat: add parent supervision database foundation"
```

### Task 2: Implement server-authoritative family-link transitions

**Files:**
- Modify: `apps/mobile/test/parent_supervision_sql_test.dart`
- Modify: `supabase/parent_supervision.sql`

- [ ] **Step 1: Add failing RPC contract tests**

Add assertions for the exact functions and authorization branches:

```dart
test('defines server-authoritative family link transitions', () {
  for (final name in [
    'create_parent_child_link',
    'accept_parent_child_link',
    'reject_parent_child_link',
    'cancel_parent_child_link',
  ]) {
    expect(migration, contains('function public.$name'));
  }
  expect(migration, contains("p_requester_role not in ('parent', 'child')"));
  expect(migration, contains('requested_by <> v_user_id'));
  expect(migration, contains('requested_by = v_user_id'));
  expect(migration, contains("status <> 'pending'"));
  expect(migration, contains('pg_advisory_xact_lock'));
  expect(migration, contains("'link_request'"));
  expect(migration, contains("'link_accepted'"));
  expect(migration, contains("'link_rejected'"));
  expect(migration, contains("'link_cancelled'"));
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: FAIL because the four RPCs are absent.

- [ ] **Step 3: Add the role guard and four transactional RPCs**

Add a private helper that checks whether a proposed `(user_id, role)` conflicts with any pending/active link. In each public RPC:

```sql
v_user_id uuid := auth.uid();
if v_user_id is null then
  raise exception 'Authentication required' using errcode = '42501';
end if;
perform pg_advisory_xact_lock(hashtextextended(least(v_user_id, p_candidate_id)::text, 0));
perform pg_advisory_xact_lock(hashtextextended(greatest(v_user_id, p_candidate_id)::text, 0));
```

`create_parent_child_link(p_candidate_id uuid, p_requester_role text)` must reject self-links, invalid roles, duplicate live pairs, and incompatible roles; assign `parent_id`/`child_id` from the requester's selected role; insert the pending row and one `link_request` notification for the recipient in the same transaction; and return the new row.

`accept_parent_child_link(p_link_id uuid)` must lock the pending row, require the current user to be the non-requesting participant, rerun both role checks, update `status = 'active'`, `linked_at = now()`, `responded_at = now()`, and notify the requester.

`reject_parent_child_link(p_link_id uuid)` must require the non-requesting participant, set `rejected/responded_at`, and notify the requester.

`cancel_parent_child_link(p_link_id uuid)` must require `requested_by = auth.uid()`, set `cancelled/cancelled_at`, and notify the recipient.

Use grants with exact signatures:

```sql
grant execute on function public.create_parent_child_link(uuid, text) to authenticated;
grant execute on function public.accept_parent_child_link(uuid) to authenticated;
grant execute on function public.reject_parent_child_link(uuid) to authenticated;
grant execute on function public.cancel_parent_child_link(uuid) to authenticated;
```

- [ ] **Step 4: Run the focused tests**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the link RPCs**

```powershell
git add -- ../../supabase/parent_supervision.sql test/parent_supervision_sql_test.dart
git commit -m "feat: secure parent child link transitions"
```

### Task 3: Implement atomic Check-In, SOS, and supervision notification RPCs

**Files:**
- Modify: `apps/mobile/test/parent_supervision_sql_test.dart`
- Modify: `supabase/parent_supervision.sql`

- [ ] **Step 1: Add failing safety RPC tests**

```dart
test('defines child-only safety and parent-only SOS transitions', () {
  for (final name in [
    'submit_safety_check_in',
    'submit_sos_alert',
    'acknowledge_sos_alert',
    'resolve_sos_alert',
    'mark_supervision_notification_read',
  ]) {
    expect(migration, contains('function public.$name'));
  }
  expect(migration, contains('No active parent link'));
  expect(migration, contains("status = 'open'"));
  expect(migration, contains("status = 'acknowledged'"));
  expect(migration, contains("status = 'resolved'"));
  expect(migration, contains('acknowledged_by is null'));
  expect(migration, contains("'Location unavailable'"));
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: FAIL because the safety RPCs are absent.

- [ ] **Step 3: Add child-only Check-In and SOS creation**

Implement `submit_safety_check_in(p_message text, p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_location_captured_at timestamptz)` so it:

- Requires `char_length(btrim(p_message)) between 1 and 280`.
- Requires the sender to be the child in at least one active link.
- Stores `available` only when both coordinates are present; otherwise stores `not_requested`.
- Inserts a `check_in_received` event for every active parent and `check_in_sent` for the child using keys `check-in:<id>:<recipient>`.
- Returns the inserted Check-In.

Implement `submit_sos_alert(p_latitude double precision, p_longitude double precision, p_accuracy_meters double precision, p_location_captured_at timestamptz, p_location_failure text)` so it:

- Requires an active parent link.
- Stores `location_status = 'available'` only with both coordinates; otherwise uses `unavailable` and a non-empty safe failure value.
- Always creates the SOS even when location is unavailable.
- Inserts `sos_opened` notifications for the child and all active parents in the same transaction.
- Returns the inserted SOS.

- [ ] **Step 4: Add concurrency-safe SOS transitions and read marking**

`acknowledge_sos_alert(p_sos_id uuid)` must use a single conditional update:

```sql
update public.sos_alerts
set status = 'acknowledged',
    acknowledged_by = v_user_id,
    acknowledged_at = now()
where id = p_sos_id
  and status = 'open'
  and acknowledged_by is null
returning * into v_sos;
```

If no row returns, fetch and return the already-confirmed SOS only when it is visible to that linked parent. On the first update, fan out `sos_acknowledged` to the child and all active parents.

`resolve_sos_alert(p_sos_id uuid)` must require an active linked parent and current status `acknowledged`, then set `resolved`, `resolved_by`, and `resolved_at` and fan out `sos_resolved`.

`mark_supervision_notification_read(p_notification_id uuid)` must update only `user_id = auth.uid()` and return the row.

- [ ] **Step 5: Run the SQL contract tests**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the safety RPCs**

```powershell
git add -- ../../supabase/parent_supervision.sql test/parent_supervision_sql_test.dart
git commit -m "feat: add atomic supervision safety events"
```

### Task 4: Implement idempotent screen-time synchronization and thresholds

**Files:**
- Modify: `apps/mobile/test/parent_supervision_sql_test.dart`
- Modify: `supabase/parent_supervision.sql`

- [ ] **Step 1: Add the failing synchronization contract test**

```dart
test('synchronizes screen time idempotently and emits every crossed threshold', () {
  expect(migration, contains('function public.sync_screen_time_session'));
  expect(migration, contains('on conflict (user_id, client_session_id) do nothing'));
  expect(migration, contains('generate_series(3, v_total_seconds / 3600)'));
  expect(migration, contains("'screen_time_threshold'"));
  expect(migration, contains('screen-time:'));
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: FAIL because `sync_screen_time_session` is absent.

- [ ] **Step 3: Implement `sync_screen_time_session`**

Use signature `(p_client_session_id text, p_local_day date, p_seconds_used integer, p_timezone_offset_minutes integer)`. Reject blank IDs, future dates, seconds outside `1..86400`, and offsets outside `-840..840`.

Insert `screen_time_sync_events` with `on conflict (user_id, client_session_id) do nothing`. Only when the insert succeeds, upsert the `screen_time_logs` row for `(user_id, local_day, source = 'device')`, increment `seconds_used` capped at 86400, and set `minutes_used = floor(seconds_used / 60)`.

For every newly completed hour from three through `floor(total_seconds / 3600)`, insert `screen_time_threshold_events on conflict do nothing`. For each newly inserted threshold, create notifications for the monitored user and all active linked parents using `screen-time:<user>:<day>:<hour>:<recipient>` event keys. Return daily seconds, next threshold hour, and whether the session was newly applied.

- [ ] **Step 4: Run the focused test**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit screen-time SQL**

```powershell
git add -- ../../supabase/parent_supervision.sql test/parent_supervision_sql_test.dart
git commit -m "feat: synchronize supervision screen time"
```

### Task 5: Add typed Parent Supervision models

**Files:**
- Create: `apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart`
- Create: `apps/mobile/test/parent_supervision_models_test.dart`

- [ ] **Step 1: Write failing parsing and role-state tests**

Test these behaviors with literal maps: cancelled status parses safely; a pending link establishes role; only active links contribute to `activeLinkCount`; notification maps preserve related IDs; SOS without coordinates reports `hasLocation == false`; and dashboard notifications are sorted newest-first and capped at ten.

```dart
test('pending link establishes child role without enabling safety', () {
  final state = SupervisionDashboardState.fromParts(
    currentUserId: 'child-1',
    links: [FamilyLink.fromMap({
      'id': 'link-1',
      'parent_id': 'parent-1',
      'child_id': 'child-1',
      'requested_by': 'parent-1',
      'status': 'pending',
      'created_at': '2026-08-02T08:00:00Z',
    })],
    ownScreenTime: const ScreenTimeSummary.zero(),
    notifications: const [],
  );

  expect(state.role, FamilyRole.child);
  expect(state.activeLinkCount, 0);
  expect(state.canUseSafetyActions, isFalse);
});
```

- [ ] **Step 2: Run the model tests and verify they fail**

Run:

```powershell
flutter test test/parent_supervision_models_test.dart
```

Expected: FAIL because the model file is absent.

- [ ] **Step 3: Implement immutable models and parsing**

Define these exact public types:

```dart
enum FamilyRole { parent, child }
enum FamilyLinkStatus { pending, active, rejected, cancelled, revoked }
enum SupervisionEventType {
  linkRequest,
  linkAccepted,
  linkRejected,
  linkCancelled,
  checkInSent,
  checkInReceived,
  sosOpened,
  sosAcknowledged,
  sosResolved,
  screenTimeThreshold,
}
enum SosStatus { open, acknowledged, resolved }
enum LocationStatus { notRequested, available, unavailable }

final class LocationCapture {
  const LocationCapture._({required this.status, this.latitude, this.longitude,
    this.accuracyMeters, this.capturedAt, this.failureCode});
  const LocationCapture.notRequested()
      : this._(status: LocationStatus.notRequested);
  const LocationCapture.unavailable(String failureCode)
      : this._(status: LocationStatus.unavailable, failureCode: failureCode);
  const LocationCapture.available({required double latitude,
    required double longitude, required double accuracyMeters,
    required DateTime capturedAt})
      : this._(status: LocationStatus.available, latitude: latitude,
          longitude: longitude, accuracyMeters: accuracyMeters,
          capturedAt: capturedAt);
  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final String? failureCode;
}

final class ProfileSummary {
  const ProfileSummary({required this.id, required this.name, this.email, this.avatarUrl});
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
}

final class FamilyLink {
  const FamilyLink({required this.id, required this.parentId, required this.childId,
    required this.requestedBy, required this.status, required this.createdAt,
    this.parent, this.child, this.linkedAt, this.respondedAt, this.cancelledAt});
  final String id;
  final String parentId;
  final String childId;
  final String requestedBy;
  final FamilyLinkStatus status;
  final DateTime createdAt;
  final DateTime? linkedAt;
  final DateTime? respondedAt;
  final DateTime? cancelledAt;
  final ProfileSummary? parent;
  final ProfileSummary? child;
}

final class LinkCandidate {
  const LinkCandidate({required this.profile, required this.isFollower,
    required this.isFollowing, this.ineligibleReason});
  final ProfileSummary profile;
  final bool isFollower;
  final bool isFollowing;
  final String? ineligibleReason;
  bool get isEligible => ineligibleReason == null;
}

final class ScreenTimeSummary {
  const ScreenTimeSummary({required this.userId, required this.localDay,
    required this.secondsUsed, required this.nextThresholdHours});
  const ScreenTimeSummary.zero()
      : userId = '', localDay = null, secondsUsed = 0, nextThresholdHours = 3;
  final String userId;
  final DateTime? localDay;
  final int secondsUsed;
  final int nextThresholdHours;
}

final class CheckInDraft {
  const CheckInDraft({required this.message, required this.location});
  final String message;
  final LocationCapture location;
}

final class SosDraft {
  const SosDraft({required this.location});
  final LocationCapture location;
}

final class SafetyCheckIn {
  const SafetyCheckIn({required this.id, required this.childId,
    required this.message, required this.location, required this.createdAt,
    this.child});
  final String id;
  final String childId;
  final String message;
  final LocationCapture location;
  final DateTime createdAt;
  final ProfileSummary? child;
}

final class SosAlert {
  const SosAlert({required this.id, required this.childId, required this.status,
    required this.location, required this.createdAt, this.acknowledgedBy,
    this.acknowledgedAt, this.resolvedBy, this.resolvedAt, this.child});
  final String id;
  final String childId;
  final SosStatus status;
  final LocationCapture location;
  final DateTime createdAt;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final ProfileSummary? child;
  bool get hasLocation => location.status == LocationStatus.available;
}

final class SupervisionNotification {
  const SupervisionNotification({required this.id, required this.eventType,
    required this.title, required this.body, required this.createdAt,
    this.linkId, this.checkInId, this.sosId, this.childId,
    this.thresholdHours, this.readAt});
  final String id;
  final SupervisionEventType eventType;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? linkId;
  final String? checkInId;
  final String? sosId;
  final String? childId;
  final int? thresholdHours;
  final DateTime? readAt;
}

final class ScreenTimeSession {
  const ScreenTimeSession({required this.clientSessionId, required this.localDay,
    required this.secondsUsed, required this.timezoneOffsetMinutes});
  final String clientSessionId;
  final DateTime localDay;
  final int secondsUsed;
  final int timezoneOffsetMinutes;
}

final class ScreenTimeSyncResult {
  const ScreenTimeSyncResult({required this.dailySeconds,
    required this.nextThresholdHours, required this.applied});
  final int dailySeconds;
  final int nextThresholdHours;
  final bool applied;
}

final class SupervisionDashboardState {
  const SupervisionDashboardState({required this.role, required this.links,
    required this.ownScreenTime, required this.notifications});
  final FamilyRole? role;
  final List<FamilyLink> links;
  final ScreenTimeSummary ownScreenTime;
  final List<SupervisionNotification> notifications;
  int get activeLinkCount =>
      links.where((link) => link.status == FamilyLinkStatus.active).length;
  bool get canUseSafetyActions =>
      role == FamilyRole.child && activeLinkCount > 0;

  factory SupervisionDashboardState.fromParts({
    required String currentUserId,
    required List<FamilyLink> links,
    required ScreenTimeSummary ownScreenTime,
    required List<SupervisionNotification> notifications,
  }) {
    FamilyRole? role;
    for (final link in links.where((link) =>
        link.status == FamilyLinkStatus.pending ||
        link.status == FamilyLinkStatus.active)) {
      final linkRole = link.parentId == currentUserId
          ? FamilyRole.parent
          : link.childId == currentUserId
              ? FamilyRole.child
              : throw StateError('Current user is not part of the link');
      if (role != null && role != linkRole) {
        throw StateError('Conflicting family roles returned by server');
      }
      role = linkRole;
    }
    final latest = [...notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return SupervisionDashboardState(
      role: role,
      links: List.unmodifiable(links),
      ownScreenTime: ownScreenTime,
      notifications: List.unmodifiable(latest.take(10)),
    );
  }
}
```

Use exhaustive private parsers that throw `FormatException` for unknown server enum values. `SupervisionDashboardState.fromParts` derives role from pending/active links, rejects mixed roles with `StateError`, counts only active links, and exposes `canUseSafetyActions => role == FamilyRole.child && activeLinkCount > 0`.

- [ ] **Step 4: Run the model tests**

Run:

```powershell
flutter test test/parent_supervision_models_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the models**

```powershell
git add -- lib/src/features/parent_child/data/parent_supervision_models.dart test/parent_supervision_models_test.dart
git commit -m "feat: model parent supervision state"
```

### Task 6: Replace direct table mutations with an injectable Supabase repository

**Files:**
- Replace: `apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart`
- Create: `apps/mobile/test/parent_child_repository_test.dart`

- [ ] **Step 1: Write failing repository contract tests**

Use source-contract assertions for RPC names and pure helper tests for candidate deduplication and local-day formatting. Require `.limit(10)` for supervision events and verify the old direct `.insert`/`.update` methods are gone.

```dart
test('sensitive mutations use only approved RPCs', () {
  final source = File('lib/src/features/parent_child/data/parent_child_repository.dart')
      .readAsStringSync();
  for (final rpc in [
    'create_parent_child_link',
    'accept_parent_child_link',
    'reject_parent_child_link',
    'cancel_parent_child_link',
    'submit_safety_check_in',
    'submit_sos_alert',
    'acknowledge_sos_alert',
    'resolve_sos_alert',
    'sync_screen_time_session',
    'mark_supervision_notification_read',
  ]) {
    expect(source, contains("'$rpc'"));
  }
  expect(source, isNot(contains('createInvite(')));
  expect(source, isNot(contains('updateLinkStatus(')));
  expect(source, contains('.limit(10)'));
});
```

- [ ] **Step 2: Run the repository test and verify it fails**

Run:

```powershell
flutter test test/parent_child_repository_test.dart
```

Expected: FAIL against the current direct-write repository.

- [ ] **Step 3: Define the injectable repository contract**

```dart
abstract interface class ParentChildRepository {
  Future<SupervisionDashboardState> fetchDashboard({required DateTime localDay});
  Future<List<LinkCandidate>> fetchLinkCandidates();
  Future<FamilyLink> createLinkRequest(String candidateId, FamilyRole requesterRole);
  Future<FamilyLink> acceptLinkRequest(String linkId);
  Future<FamilyLink> rejectLinkRequest(String linkId);
  Future<FamilyLink> cancelLinkRequest(String linkId);
  Future<List<FamilyLink>> fetchLinks();
  Future<ScreenTimeSummary> fetchScreenTime(String userId, DateTime localDay);
  Future<List<SafetyCheckIn>> fetchCheckIns();
  Future<List<SosAlert>> fetchSosAlerts();
  Future<SafetyCheckIn> submitCheckIn(CheckInDraft draft);
  Future<SosAlert> submitSos(SosDraft draft);
  Future<SosAlert> acknowledgeSos(String sosId);
  Future<SosAlert> resolveSos(String sosId);
  Future<ScreenTimeSyncResult> syncScreenTime(ScreenTimeSession session);
  Future<void> markNotificationRead(String notificationId);
  RealtimeChannel subscribeToSupervisionChanges({required VoidCallback onChange});
  Future<void> unsubscribe(RealtimeChannel channel);
}
```

Implement `SupabaseParentChildRepository(SupabaseClient client)`. Fetch dashboard pieces concurrently; query only the signed-in user's ten newest `supervision_notifications`; query candidate profiles through the deduplicated union of follower and following rows; and invoke only the approved RPCs for mutations. Convert Postgrest errors through the existing friendly-error convention at the presentation boundary, not into fabricated states.

- [ ] **Step 4: Run repository and model tests**

Run:

```powershell
flutter test test/parent_child_repository_test.dart test/parent_supervision_models_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the repository**

```powershell
git add -- lib/src/features/parent_child/data/parent_child_repository.dart test/parent_child_repository_test.dart
git commit -m "refactor: secure parent supervision data access"
```

### Task 7: Add testable location capture and platform permissions

**Files:**
- Modify: `apps/mobile/pubspec.yaml`
- Modify: `apps/mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/mobile/ios/Runner/Info.plist`
- Create: `apps/mobile/lib/src/features/parent_child/services/location_service.dart`
- Create: `apps/mobile/test/location_service_test.dart`

- [ ] **Step 1: Write failing location outcome tests**

Cover services disabled, denied, denied forever, timeout, platform failure, and available coordinates. Assert that failures return typed values such as `LocationCapture.unavailable('permission_denied')` instead of throwing to the SOS caller.

```dart
test('permission denial becomes an unavailable capture', () async {
  final platform = FakeLocationPlatform(permission: LocationPermission.denied);
  final result = await GeolocatorLocationService(platform: platform).capture();
  expect(result.status, LocationStatus.unavailable);
  expect(result.failureCode, 'permission_denied');
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/location_service_test.dart
```

Expected: FAIL because the location service does not exist.

- [ ] **Step 3: Add dependency, permissions, and service**

Add `geolocator: ^14.0.3`. Add Android `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`. Add iOS key `NSLocationWhenInUseUsageDescription` with value `CyanZone uses your location only when you choose to share a Safety Check-In or send an SOS.`

Define an injectable adapter and service:

```dart
abstract interface class LocationPlatform {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
}

abstract interface class LocationService {
  Future<LocationCapture> capture();
}
```

`GeolocatorLocationService.capture()` checks services, requests only when needed, and wraps `getCurrentPosition()` in a ten-second timeout. Map outcomes to `services_disabled`, `permission_denied`, `permission_denied_forever`, `timeout`, or `capture_failed`; preserve coordinates, accuracy, and UTC capture time on success.

- [ ] **Step 4: Resolve packages and run tests**

Run:

```powershell
flutter pub get
flutter test test/location_service_test.dart
```

Expected: dependency resolution succeeds and tests PASS.

- [ ] **Step 5: Commit location support**

```powershell
git add -- pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/src/features/parent_child/services/location_service.dart test/location_service_test.dart
git commit -m "feat: capture supervision safety location"
```

### Task 8: Add the persisted foreground screen-time tracker

**Files:**
- Create: `apps/mobile/lib/src/features/parent_child/services/screen_time_tracker.dart`
- Create: `apps/mobile/test/screen_time_tracker_test.dart`
- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`

- [ ] **Step 1: Write failing tracker tests**

Use `SharedPreferences.setMockInitialValues({})`, a fake clock, and a fake repository. Verify: resume starts a session; pause closes, persists, and syncs it; a 60-second periodic checkpoint produces non-overlapping sessions; sync failure leaves the session queued; restart reloads it; successful retry removes it; and duplicate lifecycle calls do not double count.

```dart
test('failed sync survives restart and retries once', () async {
  SharedPreferences.setMockInitialValues({});
  final repository = FakeParentChildRepository()..failScreenTimeSync = true;
  final tracker = await ForegroundScreenTimeTracker.create(
    userId: 'user-1', repository: repository, now: fakeClock.call,
  );
  tracker.onResumed();
  fakeClock.advance(const Duration(minutes: 5));
  await tracker.onPaused();
  expect(tracker.pendingSessionCount, 1);

  repository.failScreenTimeSync = false;
  final restarted = await ForegroundScreenTimeTracker.create(
    userId: 'user-1', repository: repository, now: fakeClock.call,
  );
  await restarted.flush();
  expect(restarted.pendingSessionCount, 0);
});
```

- [ ] **Step 2: Run the tracker test and verify it fails**

Run:

```powershell
flutter test test/screen_time_tracker_test.dart
```

Expected: FAIL because the tracker does not exist.

- [ ] **Step 3: Implement the tracker**

Persist a JSON list under `parent_supervision_screen_time_queue_<userId>`. Each `ScreenTimeSession` stores `clientSessionId`, local day, whole positive seconds, and timezone offset. Build the client ID from user ID plus UTC start/end microseconds so retries are stable. Ignore intervals shorter than one second. On resume start a stopwatch interval; every 60 seconds checkpoint the elapsed interval into the queue and start a new one; on pause/inactive/detached close it; `flush()` processes oldest-first and removes only confirmed sessions.

- [ ] **Step 4: Integrate tracker ownership into `MainShell`**

Initialize it after SharedPreferences and the current authenticated user are available. Forward all lifecycle states, flush on resume, pause/inactive/detached, cancel its timer in `dispose`, and keep the existing chat badge refresh behavior:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _screenTimeTracker?.onResumed();
    unawaited(_screenTimeTracker?.flush());
    _refreshChatBadge();
  } else if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached) {
    unawaited(_screenTimeTracker?.onPaused());
  }
}
```

- [ ] **Step 5: Run tracker tests and shell regression test**

Run:

```powershell
flutter test test/screen_time_tracker_test.dart test/chat_repository_test.dart
```

Expected: PASS, including the existing shell-owned chat badge lifecycle assertions.

- [ ] **Step 6: Commit the tracker**

```powershell
git add -- lib/src/features/parent_child/services/screen_time_tracker.dart lib/src/features/shell/presentation/main_shell.dart test/screen_time_tracker_test.dart
git commit -m "feat: track CyanZone foreground screen time"
```

### Task 9: Build the three approved dashboards and responsive parent summary row

**Files:**
- Replace: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart`
- Create: `apps/mobile/test/parent_supervision_page_test.dart`

- [ ] **Step 1: Write failing dashboard widget tests**

Pump `ParentChildPage(repository: fakeRepository)` for unlinked, child, and parent fixtures. Assert:

- App bar title is `Parent Supervision` and has one icon-only Add action.
- All variants show `My screen time`.
- Unlinked shows `No active family links yet.` and no safety cards.
- Child shows `Child role · 2 linked parents`, Safety Check-In, and SOS.
- Parent shows `Parent role · 2 linked children` and `Check-In & SOS records`.
- At 360 logical pixels, the two parent cards have equal width and the same vertical position with no overflow exception.
- Only ten notification tiles render.

- [ ] **Step 2: Run the dashboard tests and verify they fail**

Run:

```powershell
flutter test test/parent_supervision_page_test.dart
```

Expected: FAIL against the current Family Connection implementation.

- [ ] **Step 3: Implement shared cards and explicit dashboard compositions**

Use a `SupervisionDashboardCallbacks` value containing Add, family, records, Check-In, SOS, and event callbacks. Keep layout selection exhaustive:

```dart
Widget buildDashboard(SupervisionDashboardState state) {
  return switch (state.role) {
    null => UnlinkedSupervisionDashboard(state: state, callbacks: callbacks),
    FamilyRole.child => ChildSupervisionDashboard(state: state, callbacks: callbacks),
    FamilyRole.parent => ParentSupervisionDashboard(state: state, callbacks: callbacks),
  };
}
```

For pending-only child/parent states, use the established role dashboard but disable safety/record actions requiring active links and show `Available after the link is accepted.`

Build the parent summary with `Row`, two `Expanded` children, an eight-pixel gap, compact titles, and `FittedBox` only around the numeric summary. Do not stack at supported phone widths.

- [ ] **Step 4: Implement coordinator loading, retry, refresh, and realtime**

`ParentChildPage` accepts optional repository and location service dependencies, creates production defaults from Supabase, fetches one dashboard future, subscribes to both `supervision_notifications` and relevant `parent_child_links`/`sos_alerts` changes through the repository, debounces bursts into one refresh, refreshes on app resume, keeps the last confirmed state while refreshing, and removes the channel in `dispose`.

- [ ] **Step 5: Run dashboard tests**

Run:

```powershell
flutter test test/parent_supervision_page_test.dart
```

Expected: PASS with no overflow logs.

- [ ] **Step 6: Commit the dashboards**

```powershell
git add -- lib/src/features/parent_child/presentation/parent_child_page.dart lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart lib/src/features/parent_child/presentation/supervision_dashboards.dart test/parent_supervision_page_test.dart
git commit -m "feat: build parent supervision dashboards"
```

### Task 10: Complete link candidate, request, acceptance, rejection, and cancellation UI

**Files:**
- Create: `apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/link_request_page.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/family_links_page.dart`
- Create: `apps/mobile/test/parent_supervision_flows_test.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`

- [ ] **Step 1: Write failing link-flow widget tests**

Test the candidate union/search labels, deduplication, and disabled eligibility explanation. Verify an unlinked request shows the `I am the parent` / `I am the child` confirmation, while an established role sends without another role question. Verify incoming pending detail has Accept/Reject, outgoing pending detail has Cancel request, terminal requests are read-only, successful actions pop and refresh, and failed actions keep the page open with a friendly error.

- [ ] **Step 2: Run the flow test and verify it fails**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart
```

Expected: FAIL because the link pages are absent.

- [ ] **Step 3: Build the candidate picker**

Render a search field plus Followers and Following sections from the deduplicated candidates. Each eligible row has `Link Request`; ineligible rows show the server-compatible reason. On request:

```dart
final role = establishedRole ?? await showRoleConfirmation(context);
if (role == null || !context.mounted) return;
await repository.createLinkRequest(candidate.id, role);
if (context.mounted) Navigator.of(context).pop(true);
```

The role confirmation must use the existing `showAppConfirmationDialog` visual language through a custom two-choice dialog; it must clearly state that the role remains fixed while pending or active family links exist.

- [ ] **Step 4: Build request and family detail pages**

Use server-derived ownership and status to expose exactly one action set: incoming pending Accept/Reject, outgoing pending Cancel request, or read-only final/active state. Confirm destructive rejection/cancellation, disable buttons while awaiting, preserve the page on error, and return `true` only after server success. Family detail lets parents open a child's daily screen-time summary; it does not expose parent screen time to children and does not add active unlink.

- [ ] **Step 5: Wire Add, family cards, and link notifications**

Open candidate picker from the icon-only Add button. Open family detail from the Family links card. Route link notifications to `LinkRequestPage` with terminal records in read-only mode. Refresh after a returned `true` result.

- [ ] **Step 6: Run flow and dashboard tests**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart test/parent_supervision_page_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit the linking UI**

```powershell
git add -- lib/src/features/parent_child/presentation/link_candidates_page.dart lib/src/features/parent_child/presentation/link_request_page.dart lib/src/features/parent_child/presentation/family_links_page.dart lib/src/features/parent_child/presentation/parent_child_page.dart test/parent_supervision_flows_test.dart
git commit -m "feat: complete family linking flow"
```

### Task 11: Implement Check-In and SOS interaction flows

**Files:**
- Create: `apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`

- [ ] **Step 1: Add failing Check-In and SOS widget tests**

Verify Check-In rejects blank/over-280 messages, does not call location when Share my location is off, calls it once when on, allows retry/continue-without-location after capture failure, preserves the message after errors, and reports sent only after repository success.

Verify SOS requires confirmation, always calls location once, submits with coordinates on success, submits `Location unavailable` after denied/disabled/timeout/failure, remains open and retryable after repository failure, and never renders Sent before the repository future completes.

- [ ] **Step 2: Run the safety-flow tests and verify they fail**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart
```

Expected: FAIL because the safety pages are absent.

- [ ] **Step 3: Implement Safety Check-In**

Use a form with a 280-character counter, required validation, optional `Share my location` switch, and one submit button. Capture location only when selected. On capture failure show Retry and Continue without location; continuing creates a draft with `LocationStatus.notRequested`. Keep the controller alive until the server confirms submission, then pop `true`.

- [ ] **Step 4: Implement SOS send and detail**

Use `showAppConfirmationDialog` with the approved explanation. After confirmation, immediately enter a progress state, call location capture exactly once, convert every unavailable result into a `SosDraft` with `locationFailure`, then call `submitSos`. Only a returned `SosAlert` can produce the Sent state.

The detail page renders location or `Location unavailable`, current status, acknowledging parent/time, and valid parent actions. Acknowledge and Resolve call the corresponding RPC, disable while pending, replace local data only with the returned server row, and tolerate the first-acknowledger race by displaying the returned winner.

- [ ] **Step 5: Wire child dashboard actions**

Only enable Check-In and SOS when `state.canUseSafetyActions`; refresh when either page returns success.

- [ ] **Step 6: Run safety, location, and dashboard tests**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart test/location_service_test.dart test/parent_supervision_page_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit the safety flows**

```powershell
git add -- lib/src/features/parent_child/presentation/check_in_page.dart lib/src/features/parent_child/presentation/sos_page.dart lib/src/features/parent_child/presentation/parent_child_page.dart test/parent_supervision_flows_test.dart
git commit -m "feat: add check in and SOS flows"
```

### Task 12: Add parent records and typed Supervision Notification navigation

**Files:**
- Create: `apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart`
- Create: `apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart`
- Modify: `apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart`
- Modify: `apps/mobile/test/parent_supervision_flows_test.dart`

- [ ] **Step 1: Add failing records and routing tests**

Test newest-first merged Check-In/SOS records, status labels, empty/error/loading states, and detail navigation. For every `SupervisionEventType`, assert the exact destination: link request/detail, Check-In detail, SOS detail, or family screen-time detail. Assert selecting an event calls `markNotificationRead` before/while opening and a failure to mark read does not block safety detail access.

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```powershell
flutter test test/parent_supervision_flows_test.dart
```

Expected: FAIL because records and router files are absent.

- [ ] **Step 3: Build parent safety records**

Fetch RLS-filtered Check-Ins and SOS alerts, merge into a sealed/typed record item, sort descending by creation time, and render the approved `Check-In & SOS records` page. Check-In detail shows message, child, time, and optional coordinates. SOS detail reuses `SosPage.detail` so acknowledgement/resolution logic has one implementation.

- [ ] **Step 4: Implement exhaustive event routing**

Use an exhaustive switch with no raw route strings:

```dart
return switch (notification.eventType) {
  SupervisionEventType.linkRequest ||
  SupervisionEventType.linkAccepted ||
  SupervisionEventType.linkRejected ||
  SupervisionEventType.linkCancelled => openLink(notification.linkId!),
  SupervisionEventType.checkInSent ||
  SupervisionEventType.checkInReceived => openCheckIn(notification.checkInId!),
  SupervisionEventType.sosOpened ||
  SupervisionEventType.sosAcknowledged ||
  SupervisionEventType.sosResolved => openSos(notification.sosId!),
  SupervisionEventType.screenTimeThreshold => openScreenTime(notification.childId!),
};
```

Validate required related IDs before navigation and show `This supervision record is no longer available.` if a historical event no longer grants access.

- [ ] **Step 5: Wire records card and event tiles**

The parent summary card opens records. Each notification tile calls the router, refreshes read state afterward, and preserves the ten-item cap. Realtime changes trigger the page-level debounced refresh implemented in Task 9.

- [ ] **Step 6: Run all Parent Supervision tests**

Run:

```powershell
flutter test test/parent_supervision_models_test.dart test/parent_child_repository_test.dart test/location_service_test.dart test/screen_time_tracker_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit records and navigation**

```powershell
git add -- lib/src/features/parent_child/presentation/safety_records_page.dart lib/src/features/parent_child/presentation/supervision_notification_router.dart lib/src/features/parent_child/presentation/parent_child_page.dart test/parent_supervision_flows_test.dart
git commit -m "feat: add supervision records and navigation"
```

### Task 13: Synchronize the canonical schema and deployment documentation

**Files:**
- Modify: `supabase/schema.sql`
- Modify: `supabase/README.md`
- Modify: `apps/mobile/test/parent_supervision_sql_test.dart`

- [ ] **Step 1: Add failing canonical-schema and documentation tests**

```dart
test('canonical schema matches parent supervision migration contracts', () {
  final schema = File('../../supabase/schema.sql').readAsStringSync();
  for (final token in [
    'supervision_notifications',
    'screen_time_sync_events',
    'screen_time_threshold_events',
    'create_parent_child_link',
    'submit_safety_check_in',
    'submit_sos_alert',
    'sync_screen_time_session',
  ]) {
    expect(schema, contains(token));
  }
});

test('Supabase README documents parent supervision application and verification', () {
  final readme = File('../../supabase/README.md').readAsStringSync();
  expect(readme, contains('parent_supervision.sql'));
  expect(readme, contains('supervision_notifications'));
  expect(readme, contains('FCM remains deferred'));
});
```

- [ ] **Step 2: Run the SQL test and verify it fails**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: FAIL because the base schema and README do not yet contain the new module contract.

- [ ] **Step 3: Port the migration into `schema.sql`**

Update the clean-install enum/table definitions directly, replace the old permissive family policies, add all helper/RPC definitions and grants, and publish `supervision_notifications`. Ensure a clean schema uses `screen_time_logs.user_id` directly while the migration retains the conditional rename needed by existing databases.

- [ ] **Step 4: Document application and verification**

Add a Parent Supervision section after base schema setup instructing existing projects to run `parent_supervision.sql` after `schema.sql` and before mobile verification. Include SQL Editor checks for the four core tables, all ten public RPCs, RLS policies, and realtime publication. State that FCM remains deferred and current delivery is in-app Realtime only.

- [ ] **Step 5: Run the SQL contract tests**

Run:

```powershell
flutter test test/parent_supervision_sql_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit schema and docs**

```powershell
git add -- ../../supabase/schema.sql ../../supabase/README.md test/parent_supervision_sql_test.dart
git commit -m "docs: finalize parent supervision rollout"
```

### Task 14: Apply, verify, and regression-test the complete module

**Files:**
- Verify only; modify a listed module file only if a failing test exposes a defect.

- [ ] **Step 1: Format all changed Dart files**

Run from `apps/mobile`:

```powershell
dart format lib/src/features/parent_child lib/src/features/shell/presentation/main_shell.dart test/parent_supervision_models_test.dart test/parent_child_repository_test.dart test/location_service_test.dart test/screen_time_tracker_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
```

Expected: formatter completes without errors.

- [ ] **Step 2: Run focused Parent Supervision tests**

```powershell
flutter test test/parent_supervision_models_test.dart test/parent_child_repository_test.dart test/location_service_test.dart test/screen_time_tracker_test.dart test/parent_supervision_page_test.dart test/parent_supervision_flows_test.dart test/parent_supervision_sql_test.dart
```

Expected: all focused tests PASS.

- [ ] **Step 3: Run the complete mobile test suite**

```powershell
flutter test
```

Expected: all tests PASS.

- [ ] **Step 4: Run static analysis**

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Inspect the final scoped diff**

Run from the repository root:

```powershell
git status --short
git diff --check -- apps/mobile/lib/src/features/parent_child apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/android/app/src/main/AndroidManifest.xml apps/mobile/ios/Runner/Info.plist apps/mobile/test/parent_supervision_models_test.dart apps/mobile/test/parent_child_repository_test.dart apps/mobile/test/location_service_test.dart apps/mobile/test/screen_time_tracker_test.dart apps/mobile/test/parent_supervision_page_test.dart apps/mobile/test/parent_supervision_flows_test.dart apps/mobile/test/parent_supervision_sql_test.dart supabase/parent_supervision.sql supabase/schema.sql supabase/README.md
```

Expected: no whitespace errors; unrelated pre-existing changes remain untouched.

- [ ] **Step 6: Apply SQL in the live Supabase SQL Editor**

Run the complete `supabase/parent_supervision.sql`, then execute the README verification queries. Expected: all tables/functions/policies exist and the three realtime tables are published. Do not run copied fragments.

- [ ] **Step 7: Perform multi-account acceptance testing**

Use three authenticated sessions to verify:

1. Unlinked user chooses a role and sends a request.
2. Recipient accepts; both dashboards update live.
3. A second same-role link succeeds and a conflicting-role request fails clearly.
4. Pending requester cancellation and recipient rejection navigate correctly.
5. Check-In works without location and with location.
6. SOS sends with location and also sends with `Location unavailable` after permission denial.
7. Two parents acknowledge concurrently; exactly one first acknowledger remains.
8. A linked parent resolves and every open client receives the status update.
9. Own screen time appears for unlinked/child/parent accounts; child detail is visible to parent only.
10. Three-hour and subsequent hourly events appear once, the feed shows only the latest ten, and Messages notifications remain unchanged.

- [ ] **Step 8: Commit only verification-driven fixes, if any**

If verification required code changes, rerun the failing focused test plus the full suite and analyzer, then stage only those scoped files:

```powershell
git add -- apps/mobile/lib/src/features/parent_child/data/parent_supervision_models.dart apps/mobile/lib/src/features/parent_child/data/parent_child_repository.dart apps/mobile/lib/src/features/parent_child/services/location_service.dart apps/mobile/lib/src/features/parent_child/services/screen_time_tracker.dart apps/mobile/lib/src/features/parent_child/presentation/parent_child_page.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboard_cards.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_dashboards.dart apps/mobile/lib/src/features/parent_child/presentation/link_candidates_page.dart apps/mobile/lib/src/features/parent_child/presentation/link_request_page.dart apps/mobile/lib/src/features/parent_child/presentation/family_links_page.dart apps/mobile/lib/src/features/parent_child/presentation/check_in_page.dart apps/mobile/lib/src/features/parent_child/presentation/sos_page.dart apps/mobile/lib/src/features/parent_child/presentation/safety_records_page.dart apps/mobile/lib/src/features/parent_child/presentation/supervision_notification_router.dart apps/mobile/lib/src/features/shell/presentation/main_shell.dart apps/mobile/test/parent_supervision_models_test.dart apps/mobile/test/parent_child_repository_test.dart apps/mobile/test/location_service_test.dart apps/mobile/test/screen_time_tracker_test.dart apps/mobile/test/parent_supervision_page_test.dart apps/mobile/test/parent_supervision_flows_test.dart apps/mobile/test/parent_supervision_sql_test.dart supabase/parent_supervision.sql supabase/schema.sql supabase/README.md
git commit -m "fix: stabilize parent supervision acceptance flow"
```

If no files changed, do not create an empty commit.
