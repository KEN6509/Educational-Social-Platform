# Mobile Parent-Child Presentation Refactor Design

Date: 2026-09-12
Status: Approved for implementation planning

## Context

Phase 5A continues CyanZone's incremental mobile refactor in the parent-child
feature. The feature works, but several presentation files remain large and
mix page coordination with detailed widgets. The root Parent Supervision page
also manages initial loading, realtime debounce, app-resume refreshes, and
navigation-return refreshes directly. These requests can overlap and complete
out of order.

The main Phase 5A presentation files currently include:

- `family_links_page.dart`, at about 857 lines;
- `safety_records_page.dart`, at about 660 lines;
- `sos_page.dart`, at about 561 lines; and
- `supervision_dashboard_cards.dart`, at about 531 lines.

The feature already has strong boundaries worth preserving:

- `ParentChildRepositoryContract` isolates most database operations;
- `SosTrackingCoordinator` owns the foreground-only ten-second GPS cycle;
- `SosLifecycleState` owns valid SOS action transitions;
- `SupervisionNotificationRouter` owns notification navigation; and
- shared CyanZone design tokens, confirmation dialogs, and feedback surfaces
  already exist.

## Goal

Make the parent-child mobile presentation code easier to understand and reuse,
while preventing overlapping dashboard refreshes and preserving every current
Parent Supervision, family-link, Check-In, SOS, map, record, and notification
behaviour.

## Scope

Phase 5A is limited to:

- `apps/mobile/lib/src/features/parent_child` presentation and application
  code;
- promotion of the proven chat refresh coordinator into a shared mobile core
  utility;
- mechanical chat import and type-name updates required by that promotion;
- related Flutter tests; and
- mobile refactor documentation.

Small visual differences are allowed only when a touched raw value is replaced
by an existing CyanZone token or shared component. The approved layouts remain
recognizable and unchanged.

## Non-Goals

This phase does not:

- add or redesign product features;
- change Supabase SQL, policies, RPCs, or API contracts;
- change the Administration Portal or deployed API;
- change SOS tracking from foreground-only operation;
- change the ten-second SOS location interval;
- add Riverpod or another dependency;
- rewrite the repository layer;
- change navigation routes, user-visible wording, or role rules; or
- refactor profile and authentication presentation code, which remain Phase
  5B and Phase 5C.

## Selected Approach

Use a balanced incremental refactor. Extract cohesive feature-local widgets,
share only the refresh utility that now has two real consumers, and preserve
the existing repository and page boundaries.

This approach was selected over:

1. widget extraction only, which would leave overlapping dashboard refreshes
   and duplicated feedback construction; and
2. a strict layered rewrite, which would create unnecessary MVP schedule and
   regression risk.

## Shared Refresh Coordination

The current `ChatRefreshCoordinator` becomes the shared
`AsyncRefreshCoordinator` in:

`apps/mobile/lib/src/core/application/async_refresh_coordinator.dart`

Promotion is appropriate because both chat and Parent Supervision need the
same behaviour:

- debounce burst events;
- serialize asynchronous refreshes;
- retain at most one trailing refresh while work is active;
- include the initial page load in the same serialization cycle;
- contain refresh errors so later work remains possible; and
- cancel delayed work on disposal.

The three existing chat consumers receive only mechanical import and type-name
updates. Their subscription scope, cache behaviour, badge ownership, and UI do
not change.

`ParentChildPage` continues to own its repository, realtime channel, app
lifecycle observer, navigation, and `FutureBuilder`. The shared coordinator
owns only refresh timing and serialization. It does not import Supabase,
understand dashboard models, or become a state-management framework.

## Parent Supervision Data Flow

The page initializes one coordinator before starting its dashboard request.
The initial request is registered with the coordinator before realtime
subscription begins.

Refresh sources use one path:

- realtime database events call the debounced scheduling method;
- app resume requests an immediate refresh;
- pull-to-refresh requests an immediate refresh and awaits completion;
- returning from Family Links or Safety Records requests an immediate refresh;
- a successfully sent Check-In or SOS requests an immediate refresh; and
- completing a supervision-notification route requests an immediate refresh.

If a refresh is active, later requests do not start another database request
in parallel. They request one trailing refresh. This prevents an older request
from completing last and replacing newer dashboard data.

The page remains the single owner of its realtime channel. Disposal removes
the lifecycle observer, disposes the coordinator, cancels its timer, and
unsubscribes from the channel once.

## Presentation Decomposition

Files are split by cohesive responsibility rather than an arbitrary line
target.

### Family Links

`family_links_page.dart` retains:

- page state;
- repository actions;
- confirmations;
- navigation; and
- refresh coordination after an action.

Feature-local presentation widgets move to
`family_links_widgets.dart`. These include
section cards and headers, pending-link rows, pending-unlink rows, active-link
rows, child screen-time rows, linked-name rows, empty states, avatars, role
chips, and compact action controls.

### Safety Records

`safety_records_page.dart` retains:

- record loading;
- filter state;
- retry and pull refresh; and
- navigation to the selected record.

Record filters, date headers, record tiles, avatars, type chips, and empty or
error states move to `safety_record_widgets.dart`. The Check-In detail page and
its reusable location rows move to `check_in_detail_page.dart` without changing
its public constructor or navigation behaviour.

### SOS

`sos_page.dart` retains:

- SOS draft and submission workflow;
- current alert state;
- realtime subscription ownership;
- acknowledge and resolve actions;
- parent-only resolution checks; and
- interaction with `SosTrackingCoordinator`.

The map/location presentation, event timeline, status content, unavailable
location state, and bottom action surface move to `sos_widgets.dart`.
The existing `SosLifecycleState` remains the single source for whether
Acknowledge or Resolve is available.

### Check-In and Dashboard Cards

`check_in_page.dart`, `supervision_dashboards.dart`, and
`supervision_dashboard_cards.dart` are already divided by recognizable
responsibility. They are not split merely to reduce line count. Only repeated
feedback construction and touched raw design values are migrated.

## Shared Feedback and Design Tokens

Remaining parent-child `ScaffoldMessenger` and default `SnackBar`
construction moves behind the existing `AppFeedback` facade. Existing message
text and action behaviour remain unchanged.

Confirmation decisions continue to use `AppConfirmationDialog`. Persistent
page failures remain inline page states rather than temporary snackbars.

When extracted widgets contain raw values already represented by the CyanZone
design system, they use `AppColors`, `AppSpacing`, and `AppRadii`. This phase
does not globally replace every raw number or restyle unaffected widgets.

## Error Handling

- Initial dashboard failure continues to display an inline error with Retry.
- A failed refresh does not permanently block future refreshes.
- Recoverable action failures use short, user-safe shared feedback.
- Raw Supabase or platform exceptions are not displayed.
- Check-In and SOS retry actions continue using their existing idempotent
  workflows.
- The refactor does not add a Retry action to any operation that could create a
  duplicate record.

## Design Pattern Use

Phase 5A uses approved patterns only where they match existing behaviour:

- **Observer:** one explicit realtime subscription owner forwards changes into
  the coordinated refresh path and disposes the subscription once.
- **Facade:** `AppFeedback` and `AppConfirmationDialog` hide Flutter feedback
  configuration from feature workflows.
- **State:** `SosLifecycleState` remains responsible for valid SOS actions and
  transitions.
- **Adapter:** `ParentChildRepositoryContract` and the location/tracking
  service contracts continue isolating Supabase and device implementations.

No additional pattern is introduced only to increase the pattern count.

## Testing Strategy

Every behaviour-changing task follows a red-green-refactor cycle.

Required automated coverage includes:

- shared coordinator debounce, serialization, trailing refresh, initial-load
  tracking, failure recovery, and disposal tests;
- a Parent Supervision regression proving an early realtime or resume request
  cannot overlap the initial dashboard request;
- source or widget contracts for one subscription and one disposal owner;
- existing family-link request, acceptance, rejection, unlink, and role tests;
- existing Check-In validation and location-choice tests;
- existing SOS lifecycle, foreground tracking, acknowledgement, resolution,
  timeline, and map tests;
- existing safety-record and supervision-notification routing tests;
- existing chat coordinator and lifecycle tests after the shared move;
- compact-screen and enlarged-text parent-child widget checks;
- Flutter static analysis;
- strict Dart formatting; and
- `git diff --check`.

Following the project's time-conscious testing preference, Phase 5A runs the
complete related parent-child, shared-component, and chat-coordinator suites.
The entire mobile test suite remains part of the final mobile verification
phase.

## Manual Android Check

The short Phase 5A device check covers:

1. Parent Supervision initial load and pull refresh.
2. The family-link candidate sheet and Family Links page.
3. Check-In validation, location choice, and successful return.
4. Active SOS display, timeline, acknowledge/resolve action sequence, and map.
5. Safety Records list and detail navigation.
6. App background/resume refresh and floating navigation clearance.

The deferred two-account FCM delivery test remains outside this phase.

## Exit Criteria

Phase 5A is complete when:

- related tests pass with zero failures;
- Flutter analysis reports no issues;
- formatting and `git diff --check` are clean;
- dashboard refreshes cannot overlap or complete out of order;
- each timer, lifecycle observer, coordinator, and realtime channel has one
  clear disposal owner;
- current parent-child behaviour and visual layout remain unchanged; and
- any unavailable physical-device evidence is reported rather than assumed.
