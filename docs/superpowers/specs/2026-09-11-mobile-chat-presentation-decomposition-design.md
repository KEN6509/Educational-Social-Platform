# Mobile Chat Presentation Decomposition Design

Date: 2026-09-11
Status: Approved approach; awaiting written-spec review

## Purpose

Phase 4A reduces the size and mixed responsibilities of CyanZone's mobile chat
presentation files without changing chat behaviour, data access, routes, or the
current user interface. It is the structural checkpoint before Phase 4B reviews
realtime subscription ownership and refresh performance.

The current largest chat presentation files are approximately:

- `chat_widgets.dart`: 1,990 lines;
- `chat_room_page.dart`: 1,746 lines;
- `notification_sections_page.dart`: 1,041 lines; and
- `chat_page.dart`: 914 lines.

## Scope

Phase 4A will:

- keep `chat_widgets.dart`, `chat_room_page.dart`, and
  `notification_sections_page.dart` as the owning Dart libraries;
- move cohesive existing widgets into feature-local `part` files;
- preserve current public class names and imports;
- keep page State classes as screen coordinators;
- preserve message loading, sending, selection, mentions, media display,
  navigation, notification actions, and realtime behaviour;
- add structural tests for the new boundaries; and
- run the existing chat-focused regression tests and Flutter analysis.

Phase 4A will not:

- redesign chat screens, bubbles, cards, colours, spacing, or navigation;
- change the rule that direct messaging requires a current follow
  relationship;
- change Supabase queries, SQL, API contracts, Firebase, moderation, or push
  delivery;
- move repository code or data models;
- introduce Riverpod or another dependency;
- change subscription timing, refresh frequency, or caching behaviour; or
- rewrite the complete chat architecture.

## Architecture

The decomposition follows the same private-library pattern already used by
Post Detail. Each owning file declares feature-local `part` files. Public chat
widgets remain available through the existing `chat_widgets.dart` import, and
private widgets remain private to their owning library.

This approach avoids making internal widgets public simply to move them and
avoids import churn across the application.

### Chat widget library

`chat_widgets.dart` remains the stable public entry point and owns shared chat
constants and formatting helpers. Its existing declarations are grouped into:

- `chat_message_bubbles.dart`: `ChatMessageBubble`, shared-post presentation,
  inline text and timestamp presentation;
- `chat_message_media.dart`: image-message layout, thumbnails, full-screen
  preview, zoom and image failure states; and
- `chat_list_widgets.dart`: avatars, search field, conversation rows,
  participant rows, empty states, and notification entry cards.

The exact existing widget bodies move without visual or callback changes.

### Chat room library

`chat_room_page.dart` keeps `ChatRoomPage` and `_ChatRoomPageState`, including
all controllers, timers, message loading, sending, permissions, selection,
mentions, scrolling coordination, image picking and realtime ownership.

Existing private visual declarations after the page State move into
`chat_room_widgets.dart`, including the message list, jump and mention
controls, mention suggestions, group-creation notice, date and unread
separators, and wallpaper painter.

Inline composer extraction is intentionally deferred. It has many callbacks
and State dependencies, so moving it in the same checkpoint would add risk
without being required to establish the first clean boundary.

### Notification section library

`notification_sections_page.dart` keeps its public page and State coordinator,
including loading, local read state, filtering, navigation, deletion and the
current realtime channel.

Existing private row, badge, filter, preview and follower-action widgets move
into `notification_section_widgets.dart` without changing their bodies.

### Files left unchanged

`chat_repository.dart`, `chat_models.dart`, `chat_mention.dart`,
`chat_mention_controller.dart`, group pages, details pages and system
notification pages remain unchanged unless compilation exposes a direct import
required by the file movement.

## Runtime and Data Flow

Runtime flow remains unchanged:

1. A page State loads data through its existing injected callback or
   `ChatRepository`.
2. The State owns futures, controllers, local selection and refresh state.
3. The State passes immutable values and callbacks to presentation widgets.
4. Presentation widgets render data and return user actions through those
   callbacks.
5. Existing realtime callbacks request the same page refreshes as before.
6. Existing page disposal continues to remove observers, cancel timers,
   unsubscribe channels and dispose controllers.

No additional fetch, subscription, cache write, or rebuild is introduced by
moving declarations.

## Error Handling

Existing error and fallback behaviour is preserved. Phase 4A does not replace
chat error messages, retry rules, cached fallbacks, image failure states or
friendly-error mapping.

If extraction reveals an existing behavioural defect, implementation stops at
the structural boundary. The defect is reported and fixed only with a separate
failing behavioural test and an explicit focused change.

## Testing

The implementation uses test-first structural contracts for each extraction:

- each owning library declares the expected `part` file;
- each `part` file exists and begins with the correct `part of` directive;
- named widget responsibilities are present only in the intended file; and
- current public imports continue to compile.

Existing behaviour coverage will then verify:

- text, shared-post and image message bubbles;
- sent and received message layout;
- conversation rows, search, filters and badges;
- direct-chat follow enforcement and failed-send draft preservation;
- message ordering, unread navigation and mentions;
- group creation and participant presentation;
- notification rows, read state, deletion and routing; and
- shared feedback and confirmation components used by chat.

Verification consists of Dart formatting, `git diff --check`, focused chat
tests and complete Flutter analysis. The complete mobile suite remains a major
checkpoint test rather than a requirement after every declaration move.

## Phase 4A Completion Gate

Phase 4A is complete when:

- the three owning libraries compile with their new private part files;
- existing public constructors and imports are unchanged;
- no chat behaviour or UI values were intentionally modified;
- all selected chat regression tests pass;
- Flutter analysis reports no issues; and
- the working tree contains only reviewed Phase 4A changes.

After this gate, Phase 4B may introduce a separately designed and tested
realtime coordinator, subscription lifecycle tests, and measured refresh
coalescing. Those runtime changes are not part of this structural checkpoint.
