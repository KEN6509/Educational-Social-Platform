# Live SOS Tracking and Check-In Maps Design

Date: 3 September 2026

## Objective

Extend Parent Supervision so an active SOS publishes the child's latest GPS
location approximately every 10 seconds while CyanZone is visible in the
foreground. Linked parents see a moving OpenStreetMap pin, live SOS status,
multiple-parent acknowledgements, and an authoritative event timeline. Safety
Check-In details retain their existing rows and add a fixed OpenStreetMap pin
below the latitude and longitude.

This change preserves the current visual direction and existing Parent
Supervision components. It is not a page redesign or a full mobile refactor.

## Confirmed Product Rules

- SOS location updates target one capture and upload every 10 seconds.
- Tracking runs only while CyanZone is visible in the foreground, regardless of
  which CyanZone page the child is viewing.
- Tracking pauses while the app is minimized, the screen is locked, or the app
  is terminated.
- When CyanZone returns to the foreground or is relaunched, it checks for the
  child's unresolved SOS and resumes foreground tracking.
- Mobile operating systems, GPS availability, and network availability can
  delay individual updates; the UI must not promise an exact interval.
- The system stores only the latest SOS location, not a route or location
  history.
- Every actively linked parent may acknowledge the same SOS once.
- The first acknowledgement changes the overall alert status from `open` to
  `acknowledged`.
- A parent must personally acknowledge the SOS before that parent may resolve
  it.
- Before personal acknowledgement, the parent sees only `Acknowledge SOS`.
- After personal acknowledgement, that action is replaced by `Resolve SOS`.
- Resolve requires a confirmation dialog explaining that live location updates
  will stop.
- Any parent who has acknowledged may resolve. The first successful resolution
  resolves the alert for everyone and stops further tracking.
- Only a linked parent can stop an SOS. The child cannot cancel or resolve it.
- Resolved alerts show neither acknowledgement nor resolution actions.
- Safety Check-In captures one optional location as it does currently. Its
  detail page displays a fixed map only when a location is available.

## Data Architecture

### `sos_alerts`

The existing table remains the stable SOS record and owns the overall lifecycle
status. Its valid transition is:

```text
open -> acknowledged -> resolved
```

It retains the child, creation time, resolution information, and the final
location fields needed by historical records. Frequent live-location writes do
not update acknowledgement or resolution columns directly.

### `sos_live_locations`

Add a table with one row per SOS:

- `sos_id` as the primary key and foreign key to `sos_alerts`
- `child_id`
- `latitude`
- `longitude`
- `accuracy_meters`
- `captured_at`, supplied from the device
- `received_at`, assigned by the database

Each valid foreground update overwrites the same row. The final row remains
available after resolution for the historical map, but the database rejects
all later updates.

### `sos_events`

Add an append-only timeline table:

- event ID
- SOS ID
- event type: `triggered`, `acknowledged`, or `resolved`
- actor user ID
- actor name snapshot
- server-created timestamp

The actor name is stored at event time so an old timeline does not change when
a profile is renamed. The triggered event identifies the child. Each parent
may have at most one acknowledgement event per SOS, and an SOS may have at most
one resolved event. Constraints and RPC logic make retries and double taps
idempotent.

## Database Operations and Security

All writes use security-definer RPCs. Direct authenticated insert, update, and
delete privileges remain revoked.

- `submit_sos_alert` creates the alert, initial latest-location row when
  available, and triggered timeline event atomically.
- A new location-update RPC accepts a location only when the caller owns the
  SOS and the alert is not resolved.
- `acknowledge_sos_alert` accepts `open` or `acknowledged` alerts, verifies an
  active parent-child link, inserts one acknowledgement for the current parent,
  and changes `open` to `acknowledged` on the first acknowledgement.
- `resolve_sos_alert` verifies an active parent-child link, verifies that the
  current parent has an acknowledgement event, accepts only an acknowledged
  alert, and records the single resolution event atomically.

Row-level security permits the child and actively linked parents to read the
alert, current location, and timeline. Only the child can submit its live
location. The database is the final authority even when a client has stale UI
state.

`sos_live_locations` and `sos_events` are added to Supabase Realtime using
idempotent publication checks. The complete `parent_supervision.sql` remains the
canonical existing-project upgrade script and is updated together with
`schema.sql` for fresh projects.

## Mobile Components

### `SosTrackingCoordinator`

An app-scoped coordinator acts as a Facade over location permission, periodic
GPS capture, uploading, app lifecycle, active-SOS recovery, and remote
resolution. It remains alive when the child navigates away from the SOS page.

Its public operations are intentionally small:

- start tracking an active SOS
- pause when the app leaves the foreground
- resume after checking the server's active SOS
- stop after resolution or sign-out

No Riverpod dependency is required. A small app-level Flutter scope owns and
exposes the coordinator.

### Location service

Extend the current location abstraction so one-time Check-In capture and
periodic SOS capture share permission and error mapping. Platform output is
adapted into the existing application location model. A timer schedules a
capture approximately every 10 seconds while the app is in the foreground.

Only a newly captured valid position is uploaded. A failed capture leaves the
SOS active and is retried on a later cycle.

### Realtime parent view

The SOS detail page subscribes to:

- the alert row for overall status and resolution
- the latest-location row for the moving pin and freshness
- the event rows for the live timeline

Child-side tracking also observes resolution so it can stop promptly. Database
rejection remains the backstop against an update racing with resolution.

### Reusable map component

Add one reusable `AppLocationMap` built with `flutter_map` and OpenStreetMap.
It accepts the application location model and supports:

- a live SOS marker that moves when the latest location changes
- a fixed Check-In marker
- configurable tile URL so the tile provider can be replaced later
- visible `© OpenStreetMap contributors` attribution
- a loading state and non-blocking tile-error fallback

The initial MVP/UAT may use the standard OpenStreetMap raster tile endpoint
with a distinct CyanZone application identifier and policy-compliant caching.
The tile provider remains configurable because the public service is
best-effort and is not a production SLA.

## UI Design

### SOS detail

Reuse the existing detail-page components and order them as follows:

1. Status row
2. Existing latitude/longitude location row
3. OpenStreetMap live map
4. Timeline row
5. A single state-dependent action at the bottom

The location area includes accuracy and freshness text. Recent updates may be
labelled live; after roughly 20 to 30 seconds without a received update, the UI
uses `Last updated ...` or `Location updates paused` instead of claiming the
pin is live.

The timeline is ordered by authoritative server timestamp and formats entries
such as:

```text
3:00 PM - SOS triggered by Child
3:02 PM - Parent A acknowledged alert
3:04 PM - Parent B acknowledged alert
4:00 PM - Parent B resolved alert
```

The action rules are:

```text
Active + current parent has not acknowledged -> Acknowledge SOS
Active + current parent has acknowledged     -> Resolve SOS
Resolved                                     -> no action
```

### Check-In detail

Reuse the current detail rows. Keep the latitude/longitude text and insert the
fixed OpenStreetMap immediately below it. When location was not shared or was
unavailable, retain the existing textual state and do not render an empty map.

## Failure and Recovery Behaviour

- SOS creation still succeeds when the initial location is unavailable.
- Permission denial, disabled location services, timeout, and capture failure
  use the existing typed location failure values.
- A failed upload keeps the most recent unsent valid point in memory and retries
  on a later foreground cycle.
- Parent views display the server-confirmed latest point and its freshness.
- OpenStreetMap tile failure does not hide coordinates, status, timeline, or
  emergency actions.
- Concurrent parent acknowledgements are both retained.
- Concurrent resolution attempts produce one resolution event; later calls
  return the already-resolved state without duplicating the timeline.
- Returning to the foreground or relaunching checks the server before resuming,
  preventing a resolved alert from restarting tracking.

## Design Patterns Applied

- **Facade:** `SosTrackingCoordinator` hides GPS, lifecycle, retry, recovery,
  realtime status, and repository interactions behind a small API.
- **Observer:** Geolocator updates, Flutter application lifecycle changes, and
  Supabase Realtime changes notify the coordinator and SOS views.
- **State:** open, acknowledged, and resolved lifecycle objects determine
  tracking and action availability; the database independently enforces the
  same transitions.
- **Adapter:** platform GPS positions and map coordinates are converted through
  CyanZone-owned location models, keeping pages independent of plugin types.

The patterns solve current variability and coordination problems. No unrelated
GoF patterns are introduced merely to increase a pattern count.

## Verification

Implementation uses focused Parent Supervision verification:

- unit tests for lifecycle state rules, per-parent actions, 10-second
  scheduling, pause/resume, recovery, retry, and stop behaviour
- repository tests for new RPC parameters and realtime subscriptions
- widget tests for button replacement, resolve confirmation, timeline updates,
  moving SOS marker, fixed Check-In marker, stale-location labels, and fallbacks
- SQL contract tests for tables, constraints, grants, RLS, RPCs, idempotency,
  and Realtime publication
- existing Parent Supervision regression suites
- targeted Flutter analysis for changed code and tests

Real-device acceptance remains necessary for GPS permission, foreground
lifecycle transitions, network interruption, and map-tile rendering.

## Deployment

After implementation, rerun the complete updated
`supabase/parent_supervision.sql` in the Supabase SQL Editor. The script remains
idempotent and preserves existing records. Inspect and resolve any SQL Editor
error before mobile acceptance testing. Verification queries in
`supabase/README.md` are updated for the new tables, RPC, policies, and Realtime
entries.

## Out of Scope

- background or locked-screen GPS tracking
- storing a route or historical 10-second location points
- child cancellation or child resolution
- reverse geocoding, Places search, directions, or route rendering
- offline map downloads
- replacing the current Parent Supervision visual design
- broad mobile architecture refactoring outside the code touched by this
  feature
