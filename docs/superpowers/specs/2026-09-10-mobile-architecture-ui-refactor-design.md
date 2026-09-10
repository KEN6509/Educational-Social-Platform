# Mobile Architecture and UI Consistency Refactor Design

Date: 2026-09-10
Status: Approved for implementation planning

## Context

CyanZone's mobile features are working, but the Flutter code has grown through
many feature iterations. The application already uses a feature-first folder
structure and contains useful abstractions for authentication, moderation,
push notifications, posts, chat, and parent supervision. The remaining issue
is consistency: several pages contain duplicated presentation code, hard-coded
colours and spacing, direct snackbar construction, and large widgets that mix
screen coordination with detailed UI.

The largest current Dart files include:

- `post_detail_page.dart`, at more than 3,400 lines;
- `chat_widgets.dart`, at more than 1,800 lines;
- `main_shell.dart`, at more than 1,700 lines;
- `chat_room_page.dart`, at more than 1,600 lines;
- `device_photo_picker_page.dart` and `chat_repository.dart`, at more than
  1,000 lines each; and
- `profile_page.dart`, `feed_card.dart`, and notification pages, each close to
  or above 1,000 lines.

The existing `AppTheme` defines part of the visual system, but many feature
files still repeat raw colours, padding, radii, button styles, and feedback
components. An application-wide confirmation dialog exists, but the push
permission prompt bypasses it with a separate `AlertDialog`. A feature-specific
white snackbar exists for post feedback, while many other screens construct
default dark snackbars directly.

The refactor must improve maintainability, consistency, and safe runtime
performance without redesigning the application or changing completed feature
behaviour. The developer has about three months remaining and wants to finish
development during the semester break, so a full architecture rewrite is not
appropriate.

## Goals

- Keep all existing mobile features and user flows working.
- Make feature boundaries and file responsibilities easier to understand.
- Extract reusable code only when it has a real shared purpose.
- Centralize theme colours, spacing, page padding, typography, radii, shadows,
  and common component styles.
- Provide consistent reusable dialogs and snackbars for current and future
  features.
- Make the bottom navigation pill float above page content consistently across
  all main tabs.
- Split oversized presentation files incrementally.
- Formalize six suitable GoF patterns already present or directly useful in
  the codebase.
- Improve user experience through safe, evidence-based performance changes.
- Keep each stage small enough to test, review, and revert independently.

## Non-goals

- Redesigning CyanZone's visual identity or rebuilding every screen.
- Migrating the application to Riverpod or another state-management package.
- Rewriting the Flutter application with strict Clean Architecture.
- Changing Supabase schemas, deployed API contracts, or Administration Portal
  behaviour as part of this phase.
- Adding new product features.
- Forcing all GoF patterns into the project.
- Introducing microservices, separate read/write databases, isolates, or other
  infrastructure without measured need.
- Completing the deferred physical-device FCM acceptance test. That test
  remains a separate manual verification activity when suitable devices are
  available.

## Selected Approach

Use an incremental architecture and UI-system refactor. Preserve the existing
feature-first organization and improve it feature by feature. Add shared
foundations first, migrate call sites gradually, and split large files only
after behaviour is protected by relevant tests.

This approach was selected over:

1. a UI-only cleanup, which would leave oversized files and mixed
   responsibilities unchanged; and
2. a full state-management and architecture rewrite, which would create too
   much schedule and regression risk for the MVP timeline.

## Scope and Boundaries

Implementation is limited to `apps/mobile`, plus mobile architecture
documentation and tests. Existing API, Administration Portal, and Supabase
code remain unchanged unless a mobile test exposes a genuine compatibility
defect that cannot be resolved inside the mobile boundary.

The refactor may make small visual adjustments when inconsistent values are
replaced by shared tokens. The overall CyanZone appearance, page content,
navigation, and interaction behaviour must remain recognizable and unchanged.

## Target Folder Responsibilities

The project keeps its feature-first layout:

```text
lib/src/
|-- core/
|   |-- config/
|   |-- errors/
|   |-- services/
|   |-- theme/
|   `-- widgets/
`-- features/
    `-- feature_name/
        |-- domain/
        |-- application/
        |-- data/
        `-- presentation/
```

Responsibilities are:

- `domain`: business models, state rules, and dependency contracts that do
  not depend on Flutter UI or vendor SDKs;
- `application`: controllers, coordinators, and multi-step feature workflows;
- `data`: Supabase, HTTP, Firebase, device, cache, and local-storage
  implementations;
- `presentation`: pages, presentation controllers, and feature-specific
  widgets;
- `core/theme`: shared visual tokens and application-wide component themes;
- `core/widgets`: UI components genuinely used by multiple features; and
- `core/services`: application-wide external service contracts or adapters
  only when they are not owned by a single feature.

A widget used by one feature remains inside that feature. A page coordinates
its screen state and composition; it should not also contain every dialog,
card, sheet, formatter, and business workflow used by the feature.

## Design Token System

The mobile design system uses three conceptual layers while remaining small
and idiomatic for Flutter.

### Primitive tokens

Primitive values define the approved CyanZone palette, spacing scale, radii,
and shadows. The spacing scale is based on `4, 8, 12, 16, 20, 24, 32`.

### Semantic tokens

Semantic tokens describe purpose rather than raw values, including:

- background, surface, primary, text primary, and text secondary;
- success, warning, error, disabled, divider, and card border;
- normal page padding, compact content padding, section spacing, and floating
  navigation clearance.

Flutter's `ColorScheme`, `TextTheme`, and focused theme extensions should be
used instead of creating a second unrelated theme system.

### Component styling

`ThemeData` and focused reusable components provide consistent styling for:

- primary, secondary, text, and destructive buttons;
- text inputs and search inputs;
- cards and status surfaces;
- dialogs;
- snackbars; and
- the floating navigation pill.

Normal forms and content pages use 20 pixels of horizontal page padding.
Intentional exceptions remain for edge-to-edge feeds, media, compact internal
elements, chat bubbles, and overlays. Migration must be semantic rather than a
mechanical replacement of every `EdgeInsets` or colour literal.

## Shared Dialog Design

The existing application confirmation dialog becomes the basis of one shared
dialog system. It supports:

- information;
- confirmation;
- destructive confirmation; and
- permission request variants.

All variants use consistent title and description typography, surface colour,
radius, padding, action spacing, loading state, and dismissal behaviour.
Button order and emphasis remain appropriate to the action. Destructive
actions must be visually distinct and require explicit confirmation.

The push permission prompt is migrated to the shared dialog design. Existing
feature dialogs are migrated gradually rather than replaced in one large
change.

## Shared Snackbar Design

Create an application-wide feedback facade with neutral, success, warning, and
error variants. It supports:

- a short message;
- an optional status icon;
- an optional action such as Retry or Undo;
- consistent display duration and replacement behaviour; and
- safe positioning above the floating navigation pill and system inset.

The established white floating post/share feedback surface is the visual
baseline: white background, readable dark text, subtle border or shadow, and a
CyanZone-coloured optional action. Status must not depend on colour alone.

Pages call a small API such as `showSuccess`, `showError`, or a typed general
method instead of constructing `SnackBar` objects directly. Long explanations
remain in page content or dialogs; snackbars stay concise.

## Floating Bottom Navigation

The white rounded navigation pill remains visually recognizable, but it floats
above page content across every main tab.

Implementation must:

- let the `Scaffold` body extend behind the bottom navigation area;
- remove the full-width reserved background appearance;
- keep the pill's readable surface, border, and shadow;
- respect Android system navigation and gesture insets;
- provide one shared navigation-height/clearance value; and
- ensure the final list item, form action, or chat content is not hidden behind
  the overlay.

Each tab owns only its content padding needs; it must not duplicate the visual
construction of the navigation bar.

## GoF Pattern Mapping

Six GoF patterns are in scope. They are applied only where they reduce existing
coupling or duplication.

### Factory Method

A focused dependency factory or composition entry point creates the correct
production, fallback, or test implementation for services such as push
notifications. Construction decisions stay out of pages.

### Adapter

CyanZone-owned interfaces isolate Firebase, Supabase, HTTP, local storage, and
device SDK details. Existing adapters and gateways are retained and made
consistent where needed.

### Facade

The shared dialog and snackbar APIs act as presentation facades, hiding
Flutter dialog and `ScaffoldMessenger` configuration from feature pages.
Focused application coordinators may also provide one operation for workflows
that otherwise require several lower-level service calls.

### Strategy

Interchangeable implementations that share a contract, such as real and no-op
push delivery or HTTP-based moderation, remain replaceable without changing
the calling workflow.

### Observer

Realtime chat, notifications, moderation state, and SOS updates use streams and
listeners. The refactor makes subscription ownership explicit, prevents
duplicate subscriptions, and guarantees cleanup.

### State

Lifecycle-dependent behaviour such as open, acknowledged, and resolved SOS
actions remains centralized so invalid transitions are rejected consistently.
The refactor does not distribute lifecycle checks across widgets.

The Repository pattern may be documented separately as an optional application
architecture pattern. It is not counted among the six GoF patterns required by
this design.

## Large File Decomposition

Large files are split by cohesive responsibility, not by arbitrary line count.
Expected extraction candidates include:

- post detail sections, interaction actions, comments, media viewer, share
  sheet, and post decision UI;
- chat room message list, composer, attachment actions, realtime lifecycle,
  and message operations;
- reusable chat list and notification widgets;
- main shell app bars, tag controls, tab content, and bottom navigation; and
- profile grids, headers, actions, and status presentation.

Private widgets should move into feature-local files first. They move to
`core/widgets` only after at least two feature areas share the same semantic
component.

## Safe Mobile Performance Optimization

Performance work is included when it addresses an observed code path. The
refactor will check for:

- independent requests that can run concurrently;
- duplicate requests during rebuilds or tab changes;
- unnecessary rebuilding of complete pages or lists;
- missing pagination or incremental loading for growing lists;
- repeated image downloads or cache bypasses;
- search requests that need debouncing;
- duplicated realtime listeners;
- controllers, timers, and subscriptions that are not disposed;
- entire-list refreshes where an item-level state update is sufficient; and
- widgets that can safely be constant.

File movement and smaller widgets are not reported as performance improvements
unless they change runtime work. Complex techniques such as isolates are added
only if profiling identifies expensive CPU work that requires them.

## Error Handling

Existing friendly-error mapping remains the source for user-safe messages.
Pages should not expose raw exception strings. Shared snackbars display short
recoverable feedback, dialogs request decisions, and persistent page states
handle errors that prevent the screen from functioning.

Retry actions must call the existing idempotent workflow where available and
must not duplicate posts, messages, moderation requests, or supervision
actions.

## Migration Order

1. Add and test shared theme, spacing, page-inset, dialog, and snackbar
   foundations.
2. Migrate the shell to floating bottom navigation and verify every main tab's
   bottom clearance.
3. Refactor posts, starting with shared feedback and the largest post detail
   responsibilities.
4. Refactor chat, including widget extraction and realtime subscription
   ownership.
5. Refactor parent-child, profile, and authentication presentation code.
6. Complete a mobile-wide hard-coded style and duplicate-component audit.
7. Run final mobile verification and update architecture documentation.
8. Perform a separate Administration Portal performance audit after the mobile
   application is stable.

The admin audit will first measure request waterfalls, duplicate fetching,
pagination, selected columns, database indexes, React rerenders, and Vercel
cold starts. Lightweight command/query separation may be considered later, but
CQRS or separate read/write services are not part of this mobile refactor.

## Testing and Verification

Each stage begins by protecting affected behaviour with relevant tests where
coverage is missing. Verification includes:

- widget tests for theme tokens, shared dialogs, snackbar variants, action
  callbacks, and accessibility semantics;
- shell tests for navigation, selected tab, badges, system insets, and body
  extension behind the floating bar;
- existing feature tests for posts, chat, parent supervision, profile,
  authentication, moderation, and push coordination;
- tests for listener initialization, duplicate prevention, and disposal where
  practical;
- `flutter analyze` after each stage;
- related Flutter tests after each focused change; and
- the complete mobile test suite at major checkpoints and at the end.

Manual checks cover representative small and large Android screens, every main
tab, long scrolling pages, forms, the chat composer, dialogs, snackbars with
and without actions, keyboard visibility, and system navigation insets.

## Delivery and Risk Control

- Work stays in the original CyanZone folder and uses normal Git branches, not
  a separate worktree.
- Commits remain small and scoped by foundation or feature area.
- Behaviour changes discovered during refactoring are handled separately from
  structural changes whenever possible.
- No new dependency is added unless the existing Flutter SDK and current
  packages cannot solve the problem cleanly.
- User-visible changes are limited to approved consistency improvements.
- If a stage produces broad regressions, it is paused and corrected before the
  next feature area begins.

## Documentation Outcome

After implementation, update the project overview with:

- the final mobile folder responsibilities;
- the six implemented GoF patterns and concrete class examples;
- the shared design-token and feedback-component approach;
- the completed safe performance improvements; and
- remaining manual evidence or future improvements.

Formal final-report wording is intentionally deferred until development is
complete.
