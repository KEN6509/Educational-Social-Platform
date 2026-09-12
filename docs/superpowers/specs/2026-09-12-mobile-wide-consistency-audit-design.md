# Mobile-Wide Consistency Audit Design

Date: 2026-09-12
Status: Approved for implementation planning

## Context

Phase 6 is the final mobile implementation stage of CyanZone's incremental
architecture and UI-consistency refactor. The shared design tokens,
application theme, confirmation dialog, feedback surface, floating navigation,
and major post, chat, parent-child, profile, and authentication presentation
boundaries are already implemented.

A mobile-wide source audit still finds direct `SnackBar` and
`ScaffoldMessenger` usage in several presentation files. One shell path exposes
`Error: ${e.toString()}`, which can reveal raw Supabase, PostgreSQL, or other
internal exception details to users. The audit also finds many raw colours and
spacing values, but those values include intentional media overlays, status
colours, opacity variants, and component-specific geometry. A mechanical
replacement would therefore create unnecessary visual and regression risk.

Phase 6 uses a conservative completion approach. It fixes verified shared-
style violations and genuine duplication without redesigning screens or
forcing every local value into the design-token system.

## Goals

- Make `AppFeedback` the only temporary user-message entry point in mobile
  presentation code.
- Prevent raw database, service, stack-trace, and exception details from being
  displayed to users.
- Preserve existing safe, concise user-facing messages and retry behaviour.
- Replace raw visual values only when an existing token is an exact semantic
  match.
- Consolidate only presentation components that are demonstrably duplicated.
- Add automated contracts that prevent direct snackbars and raw exception text
  from returning.
- Complete the final mobile implementation phase with a clean automated gate.

## Non-Goals

- No visual redesign or application-wide restyling.
- No mechanical replacement of every raw colour, padding, radius, or opacity.
- No change to mobile business rules, navigation, SQL, Supabase policies, API
  contracts, Gemini moderation, Firebase delivery, or Administration Portal
  behaviour.
- No Riverpod, new state-management package, or new dependency.
- No speculative shared widget that has only one current consumer.
- No new retry action unless the existing operation is confirmed idempotent.
- No physical-device acceptance, formal report writing, or final project
  documentation update in this implementation phase.
- No Administration Portal performance work; that remains a separate follow-up
  audit after the mobile application is stable.

## Selected Approach

Use conservative mobile-wide consistency completion.

This approach was selected over:

1. a broad visual sweep, which would touch hundreds of intentional local
   values and create disproportionate regression risk; and
2. a safety-only patch, which would hide raw exceptions but leave the remaining
   temporary-message inconsistency unresolved.

The selected approach migrates every verified direct temporary-message path,
protects user-safe error boundaries, applies only exact token matches in files
already touched by the migration, and extracts a reusable component only when
the current code proves that two or more consumers share the same structure
and behaviour.

## Scope and Boundaries

Implementation is limited to `apps/mobile/lib/src`, related Flutter tests, and
the Phase 6 specification and plan. The existing branch and original CyanZone
working directory remain in use; no Git worktree is created.

The initial feedback migration includes the remaining direct snackbar paths in:

- shell presentation;
- push-destination navigation;
- chat group and chat detail pages;
- chat room feedback;
- chat media feedback; and
- any other mobile presentation file found by the final structural audit.

`core/widgets/app_feedback.dart` is the only allowed location for direct
`ScaffoldMessenger` and `SnackBar` construction. A test-only usage is allowed
when it inspects the rendered shared feedback widget rather than providing an
alternative production path.

## Feedback Facade

Presentation code uses the shared semantic entry points:

- `AppFeedback.showSuccess` for completed operations;
- `AppFeedback.showError` for recoverable failures;
- `AppFeedback.showWarning` for cautionary state (added as the smallest
  convenience wrapper during this phase); and
- `AppFeedback.show` when an existing safe action such as Retry must be
  retained.

The migration preserves each message's meaning. Short messages that are already
safe, such as `No internet connection`, `Copied`, `Photo downloaded`, and
`Photo could not load`, remain concise. The refactor does not replace useful
specific messages with a single vague message.

Existing snackbar duration, action, dismissal, and callback behaviour must be
preserved when moving a path to `AppFeedback`. If the shared facade cannot
represent an existing safe behaviour, the facade may receive the smallest
general-purpose extension required by at least one real caller and covered by
tests.

## User-Safe Error Boundary

Raw PostgreSQL, Supabase, Firebase, HTTP, storage, stack-trace, or Dart
exception details must never appear in user-facing text.

The error flow is:

1. A page or controller catches the internal failure.
2. It maps the failure through the existing friendly-error utility when that
   utility has an appropriate mapping.
3. A feature-specific safe message is used when it communicates the failed
   operation more clearly than a generic mapping.
4. The page calls the semantic `AppFeedback` method.
5. Optional technical logging may retain diagnostic details in development
   output, but those details are not interpolated into visible widgets.

Representative safe outcomes are:

- database or unexpected action failure: `Unable to complete this action.
  Please try again.`;
- network failure: `No internet connection.`; and
- media load failure: `Photo could not load.`

Existing domain-specific wording is retained where it is already safe and more
useful. Error conversion must happen before the value reaches a `Text`, dialog,
snackbar, banner, or persistent error-state widget.

## Design-Token Policy

Phase 6 applies `AppColors`, `AppSpacing`, `AppInsets`, and `AppRadii` only when
both conditions are true:

1. the raw value exactly equals an existing token; and
2. the token expresses the same semantic purpose.

Examples of valid replacements include the standard CyanZone navy action
colour used as a primary action, the shared surface colour used as a normal
page surface, and the established page inset used as page-level horizontal
padding.

The following remain local unless a separately approved design change is
required:

- black or translucent media overlays;
- selection and loading overlays;
- status-specific colours not represented by the current semantic palette;
- deliberately different media-preview backgrounds;
- one-off geometry required by a particular component; and
- values that are only numerically equal but have a different purpose.

No new token is introduced merely to eliminate a single literal.

## Reuse and Duplication Policy

Repeated calls to direct snackbar construction are confirmed duplication and
are consolidated through the existing `AppFeedback` Facade.

A new shared component is allowed only when the audit identifies at least two
current consumers with the same:

- visual structure;
- interaction behaviour;
- accessibility meaning; and
- lifecycle or callback requirements.

If two widgets only look similar but represent different workflows, they remain
feature-local. If duplication is limited to a few values, existing tokens or a
small local helper are preferred over a new global component. File extraction
alone is not treated as runtime optimization.

## Design Patterns

Phase 6 completes the existing **Facade** pattern: `AppFeedback` provides one
semantic interface for temporary mobile messages and hides Flutter snackbar
construction from feature pages.

The friendly-error utility remains ordinary error-mapping code and is not
presented as a new GoF Strategy implementation. The other five approved GoF
patterns remain unchanged by this phase. No pattern is added merely to satisfy
a pattern count.

## Data and Control Flow

No domain data flow changes. Repositories, controllers, and page coordinators
continue to report success or failure through their current return values and
exceptions. Only the final presentation step changes:

```text
operation -> existing result/error handling -> safe message mapping
          -> AppFeedback semantic method -> shared white floating surface
```

Actions and retries continue to invoke their existing callbacks. The refactor
does not move repository calls into shared widgets and does not create a new
global state owner.

## Testing Strategy

Phase 6 follows red-green-refactor for every behaviour or boundary correction.
The automated gate includes:

- a structural test rejecting production `SnackBar` construction outside
  `AppFeedback`;
- a structural test rejecting production `ScaffoldMessenger` usage outside
  `AppFeedback`;
- a structural test rejecting user-facing raw interpolation patterns such as
  `Error: ${...}`, `exception.toString()`, and `e.toString()`;
- focused widget tests for migrated feedback paths whose action, duration, or
  message behaviour could regress;
- existing shell, notification, chat, media, theme, feedback, and feature
  regression suites;
- the complete mobile Flutter test suite;
- `flutter analyze --no-pub`;
- strict Dart formatting for changed files; and
- `git diff --check` plus a clean intended-file review.

The raw-error structural contract is scoped carefully so that technical logging
and non-user-facing serialization are not rejected. It guards strings that can
reach presentation widgets rather than banning every internal `toString()`.

## Manual Verification

The user will perform the combined Android manual test after Phase 6 automated
completion. That later test will include representative success, warning,
network failure, and unexpected failure feedback; compact and common screen
sizes; the floating navigation; and the previously deferred feature flows.

Phase 6 completion will not claim physical-device evidence.

## Completion Criteria

Phase 6 implementation is complete when:

- all production temporary feedback uses `AppFeedback`;
- no verified user-facing path exposes raw exception or database text;
- exact semantic token replacements are applied without changing intentional
  local visuals;
- any new shared component has at least two proven consumers;
- related and full mobile tests pass;
- Flutter analysis and strict formatting pass;
- Git whitespace checks pass; and
- no known automated blocker remains before the user's combined manual test.

After this phase, the remaining mobile-refactor activities are the user's
manual Android verification, final automated evidence capture where needed,
and architecture/project documentation updates. The Administration Portal
performance audit remains a separate follow-up project.
