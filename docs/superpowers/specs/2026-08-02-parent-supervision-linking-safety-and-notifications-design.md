# Parent Supervision: Linking, Safety, and Notifications Design

**Status:** Approved design, awaiting written-spec review

**Date:** 2026-08-02

## 1. Goal

Complete the Parent Supervision module so that users can establish a parent-child relationship, see the dashboard appropriate to their role, record their own CyanZone screen time, and use in-app safety Check-In and SOS flows.

Firebase Cloud Messaging (FCM) delivery is intentionally deferred. While CyanZone is open, Supabase Realtime provides live updates. The data model and notification records must be suitable for adding push delivery later without redesigning the module.

## 2. Scope

### Included

- Parent-child link request, acceptance, rejection, and pending-request cancellation.
- Role-aware dashboards for an unlinked user, linked child, and linked parent.
- The signed-in user's own CyanZone screen-time total on every dashboard.
- Parent access to a linked child's screen-time detail.
- Screen-time threshold events at three hours and every additional completed hour.
- Child Safety Check-In with optional location sharing.
- Child SOS with a mandatory location attempt and a safe fallback when location cannot be obtained.
- SOS acknowledgement and resolution by linked parents.
- A dedicated Supervision Notifications feed, separate from Messages notifications.
- The ten latest supervision events, live status updates, and navigation to related module pages.
- Supabase schema changes, server-authoritative RPCs, RLS policies, Flutter services and screens, automated tests, and multi-account manual verification.

### Deferred

- FCM and other closed-app/background notification delivery.
- Ending an already active family link. The data model may retain the existing `revoked` state for a later unlink flow, but this slice exposes only cancellation of a pending request.
- Continuous location tracking, location history, geofencing, or a live map.
- Parent controls outside the approved linking, screen-time visibility, Check-In, SOS, records, and supervision-notification flows.

## 3. Product Language

- Module title: **Parent Supervision**.
- Notification section: **Supervision notifications**.
- Empty family state: **No active family links yet.**
- Linked child summary: **Child role · N linked parents**.
- Linked parent summary: **Parent role · N linked children**.
- Parent record card: **Check-In & SOS records**.

Supervision notifications are not the Notification feature inside the Messages page. They have their own records, unread state, realtime subscription, and navigation behavior within Parent Supervision.

## 4. Approved Role Dashboards

All three dashboard variants have an icon-only Add action in the top-right corner and display the signed-in user's own CyanZone screen time.

### 4.1 Unlinked user

The page contains:

1. Own screen-time card.
2. Family links card with **No active family links yet.**
3. Supervision notifications showing up to the latest ten events.

Tapping Add opens a candidate picker built from the union of the user's Followers and Following lists. The picker includes:

- Followers and Following groupings or filters.
- Search.
- A Link Request action for an eligible account.

Before sending the first request, a confirmation asks the requester to choose one role:

- **I am the parent**
- **I am the child**

The selected role applies to the requester; the recipient is assigned the complementary role if the request is accepted.

### 4.2 Linked child

The page contains:

1. Own screen-time card.
2. Family links card showing **Child role · N linked parents**.
3. Safety Check-In card and action.
4. SOS card and action.
5. Supervision notifications with live status updates.

The Add action uses the same Followers/Following picker. It does not ask for a role because the child's established role is reused.

### 4.3 Linked parent

The page contains:

1. Own screen-time card.
2. One horizontal row containing two equal-width cards:
   - Family links, showing **Parent role · N linked children**.
   - **Check-In & SOS records**.
3. Supervision notifications with live status updates.

The Add action uses the same Followers/Following picker and automatically reuses the parent role.

On narrow supported phone layouts, the two summary cards remain a single row. Their content must use compact, responsive text and avoid overflow rather than stacking the cards.

## 5. Parent-Child Linking

### 5.1 Role rules

- A user may have multiple active links in one role.
- A parent may link to multiple children.
- A child may link to multiple parents.
- A user may not be a parent in one pending or active relationship and a child in another pending or active relationship.
- The first pending or active relationship establishes the user's current role.
- Rejected and cancelled requests do not continue to reserve a role.
- Role compatibility and link eligibility are checked by the server, not inferred only by the client.

### 5.2 Request lifecycle

The lifecycle for this slice is:

```text
pending -> active
pending -> rejected
pending -> cancelled
```

- The requester may cancel only while the request is pending.
- The recipient may accept or reject only while the request is pending.
- Accepted, rejected, and cancelled records are preserved for auditing and related notification navigation.
- Duplicate pending or active links between the same two users are prohibited regardless of which user initiated them.
- The server rechecks both users' roles at the moment of acceptance to prevent stale or conflicting requests from becoming active.

### 5.3 Candidate eligibility

The candidate list is the deduplicated union of Followers and Following. The UI may pre-disable or hide known ineligible candidates, but the RPC remains authoritative. A candidate is ineligible when:

- The candidate is the signed-in user.
- A pending or active link already exists between the two accounts.
- The candidate has an incompatible established role.
- Accepting the relationship would otherwise violate the role rules.

### 5.4 Events and navigation

- A submitted request creates a **Link request** event for the recipient.
- A requester cancellation creates a **Request cancelled** event for the recipient.
- Acceptance or rejection creates the corresponding event for the requester.
- A link-request event opens its request detail or acceptance page.
- A cancelled, rejected, or accepted event opens a read-only relationship/request detail appropriate to its final state.

## 6. Screen-Time Monitoring

Screen time means foreground usage of the CyanZone mobile application, not the device's total usage across other apps.

### 6.1 Tracking

- Tracking applies to every signed-in account, including unlinked users and parents.
- A shell-owned tracker observes app foreground/resume and pause/inactive/exit lifecycle transitions.
- Time is accumulated locally in small sessions, persisted across process restarts, and periodically synchronized.
- Pending local time is flushed on suitable lifecycle transitions and retried after network recovery.
- Server writes are idempotent so reconnects or retries do not double-count a session.
- Daily totals use the user's local calendar day for display; stored timestamps remain UTC.

### 6.2 Display and access

- Every Parent Supervision dashboard shows the signed-in user's daily total and next threshold.
- A linked parent may open a child's family/detail page to see that child's daily CyanZone usage.
- A child does not receive access to a parent's private screen-time detail merely because of the relationship.

### 6.3 Thresholds

- The first threshold occurs when the daily total reaches three completed hours.
- Further thresholds occur at each additional completed hour: four, five, six, and so on.
- Each threshold is emitted at most once per user, local day, and threshold hour.
- The monitored user and all currently linked parents receive a Supervision Notification event.
- Threshold processing must tolerate delayed synchronization. If a sync crosses more than one unreported threshold, each newly crossed threshold is recorded exactly once.

## 7. Safety Check-In

Safety Check-In is available only to a user whose established role is child and who has at least one active parent link.

### 7.1 Form

- A short message is required.
- **Share my location** is optional and off unless the child selects it.
- If location sharing is not selected, no location permission is requested.
- If selected, the app requests/uses location permission and attempts to capture the current coordinates.

### 7.2 Submission

- The submission RPC verifies that the sender is an actively linked child.
- The Check-In record and all recipient Supervision Notifications are created atomically.
- Every active linked parent receives the event.
- The child receives a sent-status event/confirmation in the module.
- The UI reports success only after the server transaction succeeds.

If optional location capture fails, the form explains the issue and allows the child to retry location or continue without sharing it. The typed message is preserved during recoverable failures.

## 8. SOS

SOS is available only to a user whose established role is child and who has at least one active parent link.

### 8.1 Send flow

1. The child taps SOS.
2. A clear confirmation explains that CyanZone will try to share the child's current location with all linked parents.
3. On confirmation, the app attempts to acquire location.
4. The server atomically creates the SOS and its recipient notifications.
5. The app shows **Sent** only after that transaction succeeds.

Location sharing is mandatory as an SOS intent: the app always attempts it. However, lack of permission, unavailable services, timeout, or acquisition failure must never prevent an SOS from being sent. In those cases, the event is stored and displayed with **Location unavailable** plus the failure status available to the UI.

### 8.2 Status lifecycle

```text
Open -> Acknowledged -> Resolved
```

- Every new SOS begins as Open.
- Any active linked parent may acknowledge an Open SOS.
- The first valid acknowledgement wins and records the acknowledging parent and timestamp.
- Later acknowledgement attempts return the already-confirmed state without overwriting the first parent.
- Any active linked parent may resolve an Acknowledged SOS.
- The server rejects invalid transitions and actions from unlinked or wrongly assigned users.
- The child and all active linked parents receive realtime status events for acknowledgement and resolution.

### 8.3 Related pages

An SOS notification opens SOS detail, which includes:

- Child identity.
- Creation time.
- Open, Acknowledged, or Resolved status.
- Coordinates and an external-map action when available, otherwise **Location unavailable**.
- Acknowledging parent and timestamp when present.
- Parent actions permitted by the current server-confirmed state.

## 9. Supervision Notifications

### 9.1 Feed behavior

- The dashboard fetches only the ten latest events for the signed-in user, newest first.
- The feed has its own unread/read state and is not merged into Messages notifications.
- The dashboard subscription listens for inserts and relevant updates for the signed-in user.
- Returning from background triggers a refresh so missed realtime events are recovered.
- The UI keeps the last server-confirmed state during temporary reconnects and indicates when an action is retrying.
- Selecting an event marks it read and routes to the related link, Check-In, SOS, family, or screen-time detail page.

### 9.2 Event types

The initial event set includes:

- Link request.
- Link request accepted.
- Link request rejected.
- Link request cancelled.
- Safety Check-In received/sent.
- SOS opened.
- SOS acknowledged.
- SOS resolved.
- Screen-time threshold reached.

Each record stores a typed event plus structured related identifiers. Navigation is derived from the type and identifiers rather than a raw arbitrary client route.

## 10. Data and Server Design

Implementation uses a dedicated Parent Supervision migration and keeps `supabase/schema.sql` aligned for clean environment setup.

### 10.1 Tables

#### `parent_child_links`

Extend the current relationship model to support the approved lifecycle and audit data:

- Requester and recipient identifiers.
- Explicit parent and child identifiers once roles are chosen.
- Status including `pending`, `active`, `rejected`, `cancelled`, and the reserved/deferred `revoked` state if retained by the existing schema.
- Created, responded, cancelled, and updated timestamps as appropriate.
- Constraints/indexes preventing duplicate pending or active relationships for an unordered pair.

#### `screen_time_logs`

Generalize the existing child-only ownership concept to a signed-in `user_id` while preserving existing data. Store idempotent foreground session/log data from which daily totals can be calculated reliably.

Threshold deduplication must have a durable server-side key equivalent to `(user_id, local_day, threshold_hour)`.

#### `check_ins`

Store:

- Child/user identifier.
- Required message.
- Optional latitude, longitude, accuracy, and captured-at time.
- Location state such as not requested, available, or unavailable.
- Creation time.

#### `sos_alerts`

Store:

- Child identifier.
- Latitude, longitude, accuracy, and captured-at time when available.
- Location state and safe failure classification when unavailable.
- Status.
- Acknowledging parent and acknowledgement time.
- Resolver and resolution time.
- Creation and update times.

#### `supervision_notifications`

Create a separate table containing:

- Recipient `user_id`.
- Typed supervision event.
- Title and concise display body or server-generated display fields.
- Structured related link, Check-In, SOS, child, and threshold identifiers where applicable.
- Read time.
- Creation time.
- An optional durable event/deduplication key for idempotent fan-out.

The notification table does not reuse or write into the Messages notification table.

### 10.2 Server-authoritative operations

Security-sensitive mutations are exposed through RPCs/functions rather than direct client table updates. The operation set covers:

- Create link request.
- Accept link request.
- Reject link request.
- Cancel pending request.
- Submit Check-In.
- Submit SOS.
- Acknowledge SOS.
- Resolve SOS.
- Synchronize an idempotent screen-time session/batch and create newly crossed threshold events.
- Mark a Supervision Notification read.

Each RPC validates authentication, current relationship state, established roles, authorization, legal transition, and expected affected-row count. Record creation and notification fan-out occur in the same transaction where an event must never exist without its recipient records.

### 10.3 Read access and RLS

- Users may read links in which they participate.
- Users may read only their own Supervision Notifications.
- A child may read their own Check-Ins and SOS records.
- An active linked parent may read a linked child's Check-Ins, SOS records, and permitted screen-time summaries.
- Users may read their own screen-time records/summaries.
- Direct client writes to protected status, role, acknowledgement, resolution, or recipient fields are denied.
- RPCs use explicit authenticated identity checks and the minimum privileges required.
- Historical notification access does not grant access to current private relationship data after authorization no longer applies.

## 11. Flutter Architecture

The existing Parent Supervision feature should be split into focused components rather than growing one page and repository indefinitely.

### 11.1 Presentation

- Dashboard coordinator that resolves unlinked, child, or parent state.
- Unlinked dashboard.
- Child dashboard.
- Parent dashboard.
- Followers/Following candidate picker and search.
- Link request detail/acceptance page.
- Family link/detail page.
- Check-In form.
- SOS confirmation and detail page.
- Check-In & SOS record list/detail.
- Supervision Notification list items and destination routing.

Shared cards and states should remain reusable while the three dashboard compositions stay explicit, particularly the parent's two-card horizontal row.

### 11.2 Data and services

- Typed supervision models and enums.
- Parent Supervision repository for reads, RPCs, and realtime refresh.
- Location service that reports available/unavailable outcomes without owning business authorization.
- Shell-owned screen-time tracker with durable local buffering.
- Lifecycle/reconnect integration that refreshes server state after background gaps.

The UI may optimistically show progress, but it must not invent a final link, SOS, acknowledgement, or notification state before server confirmation.

## 12. Error and Concurrency Handling

- Duplicate, stale, or role-conflicting link actions return a specific explanation and refresh the current relationship state.
- Check-In and SOS forms preserve entered content after recoverable network or location failures.
- An SOS remains retryable until the database transaction confirms it; the UI must not label it sent earlier.
- Concurrent SOS acknowledgement is serialized by a conditional server update so only one parent becomes the first acknowledger.
- Realtime disconnects preserve the last confirmed state, and resume/reconnect performs a bounded refresh.
- Local screen-time data survives offline periods and application restarts.
- Retried RPCs use idempotency where duplicate creation would be harmful.
- Unauthorized or invalid role actions are rejected even if a modified client attempts them directly.

## 13. Verification and Acceptance Criteria

### 13.1 Database tests

- First-request role establishment for both requester choices.
- Multiple same-role links are allowed.
- Mixed-role pending/active combinations are rejected.
- Duplicate unordered-pair requests are rejected.
- Only the correct requester/recipient can cancel, accept, or reject.
- Accepting a stale request rechecks both parties atomically.
- Check-In and SOS are child-only and require an active parent link.
- Check-In/SOS records and all recipient notification rows are atomic.
- SOS without captured location is accepted and records Location unavailable.
- Concurrent acknowledgement records exactly one first parent.
- Only valid linked parents can resolve.
- Notification and family-record reads obey RLS.
- Latest-ten ordering and read-state behavior are correct.
- Screen-time retries do not double-count.
- Three-hour and subsequent hourly thresholds fire exactly once.

### 13.2 Flutter tests

- Dashboard selection for unlinked, child, and parent users.
- The parent's Family links and Check-In & SOS records cards remain side by side at supported phone widths without overflow.
- Add action role prompt appears only for an unlinked user.
- Candidate search, eligibility, request, acceptance, rejection, and cancellation states.
- Check-In requires a message and requests location only when selected.
- SOS always attempts location but can send after an unavailable result.
- SOS final state is not shown before server confirmation.
- Notification list is capped at ten and routes each event type correctly.
- Realtime insert/update and resume refresh reconcile the visible state.
- Screen-time lifecycle accumulation, local persistence, synchronization, and threshold display.

### 13.3 Manual verification

- Test with at least two authenticated accounts in separate sessions; use a third account for concurrent/multiple-parent cases.
- Verify full request/acceptance and request/cancellation flows.
- Verify Android location permission allowed, denied, disabled-service, and timeout/unavailable paths.
- Verify Check-In with and without location.
- Verify SOS open, first acknowledgement, competing acknowledgement, and resolution updates across accounts.
- Verify the ten-event limit and navigation destinations.
- Verify the Messages notification feature remains separate and unchanged.
- Run the complete Flutter test suite and analyzer in the user's PowerShell terminal.

## 14. Rollout Notes

- Apply the new Supabase migration before testing the updated client.
- Update the canonical base schema in the same implementation so fresh environments match migrated environments.
- Confirm Realtime publication/configuration for the dedicated notification and changing SOS/link tables.
- Existing data migrations must preserve current relationship and screen-time rows where possible.
- FCM can later consume the durable Supervision Notification records; it is not required for this implementation to be accepted.

## 15. Implementation Convention

All implementation, formatting, analysis, migration, and test commands are to be run directly in the user's PowerShell terminal, as requested. Existing unrelated working-tree changes must be preserved.
