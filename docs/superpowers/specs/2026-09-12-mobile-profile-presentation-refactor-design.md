# Mobile Profile Presentation Refactor Design

Date: 2026-09-12
Status: Approved for implementation planning

## Context

Phase 5B continues CyanZone's incremental mobile refactor in the profile
feature. Current profile behaviour works, but presentation responsibilities
are concentrated in several large files and temporary feedback is constructed
in multiple different ways.

The main presentation files currently include:

- `profile_page.dart`, at about 1,080 lines;
- `verified_badge_page.dart`, at about 600 lines;
- `follow_list_page.dart`, at about 440 lines;
- `notification_settings_page.dart`, at about 420 lines;
- `edit_profile_page.dart`, at about 420 lines; and
- `settings_page.dart`, at about 260 lines.

The feature already contains useful boundaries that must be preserved:

- `ProfileRepository` owns profile and follow data operations;
- `PostsRepository` owns profile-grid post retrieval and interaction data;
- `ProfileAvatarCache` owns profile and posted-grid cache storage;
- injectable notification preference loaders and savers support tests;
- injectable creator verification loaders and submitters support tests; and
- shared CyanZone feedback, confirmation-dialog, and design-token components
  already exist.

## Goal

Make the profile-area presentation code easier to understand, reuse, and test
while preserving all current profile, edit, follow, settings, notification,
creator verification, caching, post ordering, and navigation behaviour.

## Scope

Phase 5B is divided into two implementation checkpoints.

### Phase 5B.1: Core Profile

- `profile_page.dart`;
- `edit_profile_page.dart`;
- `follow_list_page.dart`;
- their feature-local extracted presentation files; and
- related profile, post-grid, follow, cache, and interaction tests.

### Phase 5B.2: Supporting Profile Pages

- `settings_page.dart`;
- `notification_settings_page.dart`;
- `verified_badge_page.dart`;
- their feature-local extracted presentation files; and
- related settings, notification-preference, and creator-verification tests.

Small visual differences are permitted only when an existing raw value exactly
matches an approved CyanZone design token or when an existing feedback surface
is replaced by the already approved shared component. Layouts and wording stay
recognizable and unchanged.

## Non-Goals

Phase 5B does not:

- add or redesign product features;
- change Supabase SQL, policies, RPCs, storage rules, or API contracts;
- change the Administration Portal or deployed API;
- introduce Riverpod or another state-management dependency;
- rewrite `ProfileRepository`, `PostsRepository`, or cache storage;
- move existing Supabase operations between architectural layers;
- change profile navigation routes or public page constructors;
- change follow or message eligibility rules;
- change post moderation, deletion, like, save, or comment behaviour;
- change user-visible wording;
- refactor `set_password_page.dart`, which belongs to Phase 5C; or
- perform the final Android manual test, which the project owner will run after
  all Phase 5 work is complete.

## Selected Approach

Use a balanced incremental refactor. Stateful pages keep workflow and data
coordination, while cohesive private presentation widgets move into
feature-local Dart part files. Shared core abstractions are used only when they
already exist or have at least two genuine consumers.

This approach was selected over:

1. extracting only `profile_page.dart`, which would leave the surrounding
   profile experience inconsistent; and
2. a strict layered rewrite with new controllers and repositories, which would
   add unnecessary MVP schedule and regression risk.

## Phase 5B.1 Component Boundaries

### Profile Page

`profile_page.dart` retains:

- page lifecycle and current-user resolution;
- repository and cache ownership;
- profile loading, cached restoration, and refresh coordination;
- selected profile-tab state;
- navigation to edit, settings, follow lists, messaging, and post details;
- optimistic follow coordination and rollback; and
- post deletion and interaction refresh signals.

Feature-local presentation files receive:

- profile header and avatar presentation;
- statistics and action buttons;
- profile loading and persistent error states;
- the posted, saved, and liked tab strip;
- profile post-grid cards, skeletons, and persistent errors; and
- the sliver header delegate when it remains private to the profile library.

The current post-grid order remains authoritative:

- Posted posts place moderation states such as Pending and Rejected first,
  with newest posts first inside the applicable groups.
- Saved posts remain newest first.
- Liked posts remain newest first.
- Refreshing, deleting, liking, saving, or returning from a post detail keeps
  the same immediate update behaviour.

### Edit Profile

`edit_profile_page.dart` retains:

- text controllers and disposal;
- validation;
- image picking and crop-page navigation;
- connection checks;
- storage upload and profile-save coordination; and
- navigation result handling.

Inputs, avatar preview, action controls, loading state, and persistent load
errors move to a feature-local presentation part without changing their
current layout or labels.

### Follow Lists

`follow_list_page.dart` retains:

- tab and search state;
- repository ownership;
- current-user context;
- optimistic follow requests and rollback; and
- profile navigation.

List rows, follow buttons, skeletons, empty states, and persistent errors move
to a feature-local presentation part. Initial descending order and the current
search behaviour remain unchanged.

## Phase 5B.2 Component Boundaries

### Settings

`settings_page.dart` retains navigation and logout coordination. Section
headers, section containers, and setting tiles move to a feature-local part.
Logout continues to use the shared confirmation dialog and injected sign-out
action used by tests.

### Notification Settings

`notification_settings_page.dart` retains preference loading, optimistic
updates, persistence, rollback, and its injectable loader/saver seams. State
models and switch/group presentation move to focused feature-local files when
doing so does not expose private types unnecessarily.

### Creator Verification

`verified_badge_page.dart` retains eligibility loading, statement input,
submission coordination, retry, and its injectable loader/submitter seams.
Requirements, status notices, body sections, submission surface, and persistent
load errors move to a feature-local part.

## Data Flow and State Ownership

The page state remains the single workflow coordinator:

```text
User action -> page state -> existing repository or service -> state update
            -> extracted presentation widgets rebuild
```

Extraction does not create a second source of truth. Private widgets receive
immutable values and callbacks. They do not construct repositories, access
Supabase, own caches, or independently refresh page data.

Existing optimistic operations retain their rollback path. Existing injected
loaders, savers, submitters, and page builders remain available and keep their
current defaults.

## Shared Feedback and Design Tokens

Profile-area direct `ScaffoldMessenger` and default `SnackBar` construction
moves behind the existing `AppFeedback` facade. Existing message strings and
action behaviour remain unchanged.

Confirmation decisions continue using `showAppConfirmationDialog`. Persistent
loading failures remain inline error states with their current Retry actions.

Raw colours, spacing, insets, and radii are replaced only when an existing
CyanZone token has exactly the same approved value. Non-matching values remain
local constants so this refactor does not silently restyle the UI.

## Error Handling

- Initial load failures remain persistent inline states.
- Retry actions continue their current safe request path.
- Temporary action failures use short shared error feedback.
- Success and informational messages use the corresponding shared feedback
  kind.
- Optimistic follow and notification-preference failures restore the previous
  state before showing feedback.
- Raw Supabase, storage, authentication, or platform exceptions are not newly
  exposed to users.
- The refactor does not introduce automatic retries for actions that might
  create duplicate writes.

## Design Pattern Use

Phase 5B uses patterns only where they match existing behaviour:

- **Facade:** `AppFeedback` and `AppConfirmationDialog` hide common Flutter UI
  construction from profile workflows.
- **Strategy:** injected loaders, savers, submitters, sign-out actions, page
  builders, and callbacks preserve replaceable behaviour and test seams.
- **Observer:** Flutter state, builders, and existing post-interaction signals
  rebuild presentation after data changes.
- **Composite:** focused Flutter widgets compose each profile-area page from
  smaller presentation units.
- **Repository:** existing profile and post repositories remain data-access
  boundaries, but this non-GoF pattern does not need to count toward the report
  target.

No additional pattern is introduced only to increase the pattern count.

## Testing Strategy

Production changes begin with a failing structural or behavioural regression
test. Verification is proportional to the touched checkpoint.

Phase 5B coverage includes:

- presentation decomposition contracts for every extracted file;
- focused profile-page regressions for loading, cached restoration, refresh,
  and persistent error behaviour, using compatible test seams where required;
- posted, saved, and liked order and refresh regressions;
- follow-list search, optimistic follow, rollback, and navigation regressions;
- edit-profile validation, image flow, save failure, and successful result
  regressions where existing test seams permit them;
- settings logout confirmation and failure regressions;
- notification preference load, optimistic update, persistence, and rollback
  regressions;
- creator eligibility, statement validation, submission, status, and retry
  regressions;
- a source audit preventing direct snackbar construction in the profile
  presentation directory, excluding `set_password_page.dart` until Phase 5C;
- strict Dart formatting;
- Flutter static analysis; and
- `git diff --check`.

Each checkpoint runs its focused tests before the complete related profile,
posts, settings, and shared-component suite. The entire mobile suite remains
part of the final mobile verification phase.

## Deferred Manual Android Check

After all Phase 5 work is complete, the project owner will check:

1. own and other-user profile loading;
2. posted, saved, and liked ordering;
3. follow, unfollow, and message eligibility;
4. edit profile, avatar crop, and return refresh;
5. follower and following lists, search, and follow actions;
6. settings navigation and logout confirmation;
7. notification preference updates; and
8. creator verification eligibility and submission states.

No Phase 5B completion claim will rely on unavailable physical-device evidence.

## Exit Criteria

Phase 5B is complete when:

- both implementation checkpoints pass their related automated tests;
- Flutter analysis reports no issues;
- formatting and `git diff --check` are clean;
- every extracted widget has one clear presentation responsibility;
- page state remains the only workflow and data-coordination owner;
- direct profile feedback is routed through the approved shared facade, except
  the explicitly deferred password page;
- current navigation, ordering, caching, optimistic updates, error recovery,
  wording, and visual layout remain unchanged; and
- manual Android checks remain clearly recorded as deferred until the full
  Phase 5 gate.
