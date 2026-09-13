# Mobile Chat Realtime and Refresh Optimization Design

Date: 2026-09-12  
Status: Approved for implementation

## Purpose

Phase 4B improves CyanZone's mobile chat realtime lifecycle and refresh
performance after the Phase 4A presentation decomposition. It reduces
duplicate database work and makes subscription ownership more precise without
changing the chat user interface, messaging rules, navigation, or Supabase
schema.

## Context and Audit Findings

Phase 4A moved large visual declarations into feature-local files while
intentionally leaving controllers, timers, refreshes, and realtime channels in
their original page State classes. The resulting structure is stable and its
focused tests and Flutter analysis pass.

The Phase 4B audit found the following runtime concerns:

- `ChatRoomPage` uses the same broad listener as the chat home. It therefore
  reacts to changes in unrelated conversations, memberships, messages, and
  notifications by loading the open room again.
- `ChatPage`, `NotificationSectionsPage`, `ChatRoomPage`, and `MainShell`
  start refresh work directly from realtime callbacks. A rapid group of row
  changes can create overlapping fetches.
- every chat-home realtime refresh reloads suggested group members even though
  ordinary message and notification changes do not change follow eligibility;
- both the always-mounted `ChatPage` and `MainShell` subscribe for notification
  changes and independently recalculate badge data; and
- notification channels rely on row-level security but do not explicitly
  filter events to the signed-in user's `user_id`.

These are request-efficiency and lifecycle-ownership problems. They are not
evidence of incorrect chat history or a need to redesign realtime chat.

## Goals

Phase 4B will:

- coalesce rapid realtime events into bounded refresh work;
- prevent overlapping refresh operations for one screen;
- allow no more than one trailing refresh when new events arrive during a
  running refresh;
- cancel pending delayed work when its owner is disposed;
- give the chat home, an open chat room, and a notification section
  purpose-specific realtime subscriptions;
- filter room events to the open conversation where the Supabase realtime API
  supports a stable row filter;
- filter notification events to the current authenticated user;
- stop ordinary realtime events from reloading suggested group members;
- remove the duplicate continuous badge subscription from `MainShell` and use
  the always-mounted `ChatPage` as the continuous chat badge data owner;
- preserve cached fallback data and the last confirmed badge value when a
  network request fails; and
- demonstrate the change with focused lifecycle, coalescing, subscription, and
  chat regression tests.

## Non-goals

Phase 4B will not:

- redesign any chat, notification, or navigation screen;
- add Riverpod or another state-management dependency;
- create a global chat store or rewrite all chat state;
- change direct-message follow enforcement, group membership rules, message
  requests, mentions, unread calculations, or notification categories;
- change SQL, row-level security, API endpoints, Firebase, push delivery, or
  moderation;
- add message pagination or alter the current cache size;
- move repository queries into a new backend service; or
- claim a performance improvement from file movement alone.

## Considered Approaches

### Approach A: Page-local debounce timers

Each page would add its own timer and boolean flags around its current refresh
method.

This is the smallest edit, but it repeats concurrency logic, makes disposal
rules easy to implement differently, and leaves the broad room subscription
unchanged. It is not selected.

### Approach B: Feature-local refresh coordinator and purpose-specific subscriptions

A small pure-Dart coordinator will provide the shared burst-coalescing and
in-flight refresh behavior. The repository will expose subscription methods
named for the screen that consumes them, with stable server-side filters where
possible. Page State classes will continue to own their screen state and will
use the coordinator only for refresh scheduling.

This provides a reusable behavioral boundary without introducing a global
store or new package. It is the selected approach.

### Approach C: Global reactive chat store

One application-wide store would own conversations, messages, notification
counts, channels, caches, and navigation-facing state.

This could remove more duplicate reads eventually, but it would substantially
change state ownership across the shell and every chat page. The migration and
regression risk are not justified for the MVP timeline. It is not selected.

## Architecture

### Feature-local refresh coordinator

Add
`apps/mobile/lib/src/features/chat/application/chat_refresh_coordinator.dart`.
It remains inside the chat feature until another feature has the same proven
semantic requirement.

The coordinator accepts an asynchronous refresh callback and a short debounce
window. Its public operations support:

- scheduling a realtime refresh after the debounce window;
- requesting an immediate refresh for user and lifecycle actions; and
- disposing the coordinator.

Its behavior is deterministic:

1. Repeated scheduled requests inside the debounce window reset one timer.
2. When the timer completes, one refresh begins.
3. If any request arrives while the refresh is running, one pending flag is
   set instead of starting another operation.
4. After the running refresh finishes, exactly one trailing refresh runs when
   the pending flag is set.
5. Disposal cancels the debounce timer and rejects future scheduling. An
   already-running external Future is not forcibly cancelled, but it cannot
   start another refresh after disposal.
6. Scheduled refresh failures are contained so they do not become unhandled
   asynchronous errors. Existing page Futures and fallback data remain
   responsible for visible error state.

The default debounce window will be approximately 120 milliseconds. This is
short enough to remain perceptually realtime while combining the multiple row
events commonly produced by one chat action.

### Realtime repository boundaries

`ChatRepository` will replace the ambiguous screen use of
`subscribeToChatChanges` with purpose-specific methods:

- a chat-home subscription for conversation, membership, message, and the
  signed-in user's notification changes;
- a conversation subscription filtered by the open conversation ID for
  conversation, membership, and message rows; and
- a notification subscription explicitly filtered by the signed-in user's
  `user_id`.

The open-room subscription will not listen to the general `notifications`
table. Message, conversation, and membership changes for other conversations
must not reload the visible room.

The chat-home message listener may remain broad because PostgreSQL realtime
cannot express the current user's complete dynamic conversation membership as
one stable equality filter. Row-level security continues to prevent delivery
of unauthorized rows, while refresh coalescing limits repeated work.

Pages still own and close exactly one channel for their scope. The repository
continues to own the Supabase construction and removal details.

### Chat home refresh ownership

`ChatPage` remains mounted inside the shell's `IndexedStack`; therefore it will
be the continuous realtime owner for chat-home data and bottom-bar badge
updates.

The page will:

- observe application resume and request an immediate home refresh;
- schedule chat-home realtime refreshes through its coordinator;
- continue reporting the calculated total through
  `onBadgeCountChanged`;
- refresh conversations and notification counts without reloading suggested
  group members for ordinary realtime events; and
- reload suggested group members only during initial loading, explicit user
  refresh, or navigation outcomes that can affect the available people list.

The independent conversation and notification-count reads may start
concurrently, while each retains its own cached fallback and cache write. This
does not change the combined `_ChatHomeState` delivered to the UI.

`MainShell` will stop owning a continuous notification channel. It will keep
the last badge count received from `ChatPage`, so a temporary failure never
clears a confirmed badge. This removes two continuous listeners responding to
the same notification row.

### Chat room refresh ownership

`ChatRoomPage` will use the conversation-specific channel and one refresh
coordinator. Realtime events schedule a refresh; successful text and image
sends request the same refresh path immediately. A realtime echo arriving near
the send completion is therefore combined or reduced to one trailing refresh
instead of creating overlapping message loads.

The page retains ownership of:

- the message Future and cache;
- send permission and resume checks;
- read marking;
- mention state;
- selection state;
- input and scroll controllers; and
- layout/scroll timers.

The coordinator does not alter scroll positioning, composer behavior, or
message ordering.

### Notification section refresh ownership

`NotificationSectionsPage` will filter its realtime channel to the signed-in
user and schedule realtime updates through one coordinator. Navigation
returns, deletion, follow actions, read-state updates, and application resume
may request an immediate refresh through the same boundary.

`_refreshGeneration` continues to increment only when a new visible refresh
Future is installed, preserving the follower-action widget reset behavior.

## Data and Event Flow

### Incoming chat message while a room is open

1. Supabase emits the message change to the room channel filtered by
   `conversation_id`.
2. The room coordinator schedules a refresh.
3. Related events inside the short window are combined.
4. One message load replaces the page's Future.
5. The existing message cache, mention lookup, ordering, and scroll logic run
   unchanged.
6. The chat-home channel separately updates conversation preview and badge
   state because those are different visible responsibilities.

### Incoming notification

1. Supabase emits only the current user's matching notification row to the
   chat-home and, when open, notification-section channels.
2. Chat home refreshes its cached home state and reports the total badge to
   `MainShell`.
3. An open notification page refreshes its own visible list.
4. `MainShell` does not issue a third continuous realtime fetch.

### User refresh

An explicit pull-to-refresh bypasses the debounce delay but still uses the
coordinator's in-flight guard. Chat home also reloads suggested group members
because the user's follow relationships may have changed outside the current
screen.

## Error Handling

Existing user-visible failure behavior remains unchanged:

- chat home keeps cached conversations and notification counts when a fetch
  fails;
- chat room keeps cached messages when a message fetch fails;
- `MainShell` keeps the last confirmed badge;
- notification-page Futures continue to expose their existing loading, empty,
  and failure states; and
- send, follow, delete, navigation, and permission errors retain their current
  messages.

The coordinator contains errors from scheduled background work only to prevent
unhandled Future failures. It must not translate repository errors into new
user-facing text.

## Testing

### Coordinator tests

Focused unit tests will prove:

- several scheduled requests within the debounce window call refresh once;
- requests arriving during an in-flight refresh produce no overlap and at most
  one trailing refresh;
- an immediate request cancels a pending debounce delay;
- disposal cancels delayed work and prevents future work; and
- a failed scheduled refresh does not prevent a later refresh.

### Subscription contract tests

Repository and structural tests will verify:

- chat home uses its purpose-specific subscription;
- room subscriptions include the open conversation ID and exclude the general
  notification listener;
- notification subscriptions include the authenticated user's `user_id`;
- every page disposes its channel and coordinator; and
- `MainShell` no longer owns the duplicate continuous notification channel.

### Widget and regression tests

Existing tests will continue to cover:

- conversation rendering and filters;
- notification navigation, read state, deletion, and follower actions;
- room sending, media, mentions, group behavior, selection, and scrolling;
- direct-message follow enforcement;
- unread badge calculation and retention;
- application-resume refresh behavior; and
- Phase 4A presentation boundaries.

Focused tests will be added where an injectable callback can demonstrate that
manual and lifecycle refreshes use the new path without changing public
behavior.

Verification includes Dart formatting, `git diff --check`, the focused chat
suite, and complete Flutter analysis. The full mobile suite remains a major
checkpoint rather than a requirement after every individual Phase 4B edit.

## Delivery Sequence

1. Add the refresh coordinator with failing then passing unit tests.
2. Add purpose-specific repository subscription methods and contract tests.
3. Migrate `ChatRoomPage` and verify room behavior.
4. Migrate `NotificationSectionsPage` and verify notification behavior.
5. Migrate `ChatPage`, separate ordinary realtime refreshes from suggested
   people refreshes, and remove the duplicate shell subscription.
6. Run the Phase 4B focused regression gate and Flutter analysis.

Each step is committed separately so it can be reviewed or reverted without
discarding the rest of the phase.

## Phase 4B Completion Gate

Phase 4B is complete when:

- coordinator behavior is covered by deterministic tests;
- one screen never starts overlapping coordinator-owned refreshes;
- the room channel is scoped to its conversation;
- notification channels are scoped to the signed-in user;
- chat realtime events no longer reload suggested members unnecessarily;
- `MainShell` has no duplicate continuous notification subscription;
- all selected chat, unread-badge, shared-dialog, and shared-feedback tests
  pass;
- Flutter analysis reports no issues;
- `git diff --check` reports no whitespace errors; and
- the working tree contains only reviewed Phase 4B changes.

After this gate, Phase 5 can begin the separately scoped parent-child, profile,
and authentication presentation refactor.
