# Chatting Feature Design

## Status

Implemented and substantially extended as of 2026-07-11. This file is the
original approved design, not a complete description of the final chat module.
Use `Project_Overview.md` and current source/tests for the handoff. External push delivery,
chat AI moderation, calls, stickers, and reactions remain out of scope.

## Goal

Build a fully functional cloud-centric chat feature for CyanZone with direct chats, group chats, in-app notification badges, activity/system/follower notification sections, and a polished Instagram/TikTok-inspired mobile UI that stays aligned with the existing navy/cyan CyanZone theme.

## Non-goals for this phase

- No end-to-end encryption.
- No AI moderation for chat messages.
- No Perspective API usage.
- No Firebase Cloud Messaging or APNs external push delivery yet.
- No message reporting or admin review flow.
- No audio calls, video calls, media messages, stickers, reactions, or attachments.
- No "add contact" action in the chat app bar.

## Product behavior

### Chat home

The Chats tab replaces the current coming-soon placeholder. It shows:

1. An app bar titled `Chats`.
2. A create-group icon action instead of a generic `+` menu.
3. A search bar that searches:
   - followers,
   - following,
   - accepted direct chat history,
   - group chat history.
4. Three horizontal notification entry cards:
   - Activity Messages: likes, favorites/saves, comments, mentions.
   - System Notifications: system-created messages such as moderation/post failure reasons, with room for future edit/delete/appeal actions.
   - New Followers: followers created within the last 30 days.
5. Recent accepted chat history.
6. Stranger message requests in a separate area so they are not treated as recent chats.

Unread counts appear as red circular badges on notification cards, chat rows, and the bottom navigation chat tab when available.

### Direct chats

Users can open a direct chat with followers, following, or an existing accepted chat participant. A stranger is a user who is neither followed by the current user nor following the current user.

For stranger chats:

- The stranger can send up to 3 total text messages in the request conversation.
- The 4th message is blocked unless the recipient accepts the conversation or the recipient follows the sender back.
- Stranger request conversations are visible separately from recent chats.
- Stranger request conversations are excluded from group-chat suggestions and "recent chats" suggestions.

### Group chats

The create-group flow is opened from the chat home app bar. It uses a TikTok-like member picker:

- Search bar at the top.
- Suggested section first.
- Search-by-name results while typing.
- Suggested users are followers, following, and accepted recent direct chat participants only.
- Stranger request participants are excluded.
- Selected people appear in a compact selected row/chip list.
- Create button is sticky at the bottom and disabled until the group has enough selected members.

The created conversation is a group chat with text-only messages.

### Conversation screen

The chatbox follows an Instagram-like structure:

- App bar with avatar/name/subtitle.
- No call or video-call icons.
- Tapping the person/group header opens a conversation details page.
- Messages are text-only.
- Input field supports plain text send only.
- Incoming bubbles use a neutral surface.
- Outgoing bubbles use CyanZone navy/cyan styling.

### Conversation details

For this phase, the details page only needs one destructive action:

- Clear chat.

Clear chat is per current user only. It hides messages for that user by storing a per-member `cleared_at` timestamp. It does not delete messages for other participants and does not clear the other side.

### In-app notifications and badges

This phase implements in-app notification rows and badge counts using Supabase data and realtime updates.

If a user enables notification permission/settings inside the app, the UI should show relevant in-app notification indicators. External device push notifications are deferred. Firebase Cloud Messaging/APNs can be added later without replacing Supabase.

## Architecture

Use a cloud-centric Supabase architecture:

- Supabase Postgres stores conversations, members, messages, notification preferences, and notification rows.
- SQL functions handle sensitive writes such as creating conversations, sending messages, accepting requests, marking read, and clearing chat.
- Row Level Security protects chat data by membership.
- Supabase Realtime powers new message updates, unread badge refreshes, and notification-count refreshes.
- Flutter reads through a chat repository layer and renders focused presentation widgets.

This avoids the complexity of E2EE while still keeping access controlled through Supabase auth, RLS, and server-side enforcement.

## Data model

### `chat_conversations`

Stores conversation-level metadata.

- `id uuid primary key`
- `type text check in ('direct', 'group')`
- `title text nullable`
- `created_by uuid references profiles(id)`
- `requested_by uuid nullable references profiles(id)`
- `requested_to uuid nullable references profiles(id)`
- `request_status text check in ('none', 'pending', 'accepted', 'blocked')`
- `created_at timestamptz`
- `updated_at timestamptz`
- `last_message_at timestamptz nullable`

Direct conversations between the same two users must be unique.

### `chat_conversation_members`

Stores member state and per-user visibility.

- `conversation_id uuid references chat_conversations(id)`
- `user_id uuid references profiles(id)`
- `role text check in ('owner', 'member')`
- `status text check in ('active', 'pending', 'left', 'removed')`
- `joined_at timestamptz`
- `last_read_at timestamptz nullable`
- `cleared_at timestamptz nullable`

The `(conversation_id, user_id)` pair is unique.

### `chat_messages`

Stores text messages.

- `id uuid primary key`
- `conversation_id uuid references chat_conversations(id)`
- `sender_id uuid references profiles(id)`
- `body text`
- `created_at timestamptz`
- `deleted_at timestamptz nullable`

Text body must be non-empty after trimming and capped to a reasonable length, such as 2000 characters.

### `notification_preferences`

Stores current in-app notification settings.

- `user_id uuid primary key references profiles(id)`
- `in_app_enabled boolean default true`
- `chat_enabled boolean default true`
- `activity_enabled boolean default true`
- `system_enabled boolean default true`
- `followers_enabled boolean default true`
- `updated_at timestamptz`

### `notifications`

Stores in-app notification rows for chat badges and the three notification sections.

- `id uuid primary key`
- `user_id uuid references profiles(id)`
- `type text`
- `actor_id uuid nullable references profiles(id)`
- `post_id uuid nullable`
- `comment_id uuid nullable`
- `conversation_id uuid nullable references chat_conversations(id)`
- `message_id uuid nullable references chat_messages(id)`
- `title text`
- `body text`
- `action_type text nullable`
- `action_payload jsonb default '{}'`
- `read_at timestamptz nullable`
- `created_at timestamptz`

Notification `type` values for this phase:

- `chat_message`
- `like`
- `favorite`
- `comment`
- `mention`
- `system`
- `new_follower`

## Server-side functions

### `create_direct_conversation(target_user_id uuid)`

Creates or returns the direct conversation between the current user and target user.

- If either user follows the other, request status is `accepted`.
- If neither follows the other, request status is `pending`.
- Adds both users as members.
- Recipient member is pending for stranger requests.

### `create_group_conversation(title text, member_ids uuid[])`

Creates a group conversation.

- Current user becomes owner.
- Members must be followers, following, or accepted recent chat participants.
- Stranger request users are rejected.
- Creates the initial member rows in one transaction.

### `send_chat_message(conversation_id uuid, body text)`

Sends a text-only message.

- Requires current user membership.
- Rejects empty or too-long text.
- Rejects sending to left/removed conversations.
- Enforces the 3-message stranger request cap for pending stranger conversations.
- Inserts a `chat_message` notification for other active/pending members if their preferences allow it.
- Updates `last_message_at`.

### `accept_message_request(conversation_id uuid)`

Allows the requested recipient to accept a pending direct conversation.

- Sets request status to `accepted`.
- Sets recipient member status to `active`.
- Keeps existing messages visible.

### `clear_chat(conversation_id uuid)`

Sets the current member's `cleared_at` to the current timestamp.

### `mark_conversation_read(conversation_id uuid)`

Sets the current member's `last_read_at` to the current timestamp.

## RLS requirements

- Users can select conversations where they are members.
- Users can select member rows only for conversations they belong to.
- Users can select messages only for conversations they belong to.
- Direct inserts into sensitive chat tables are blocked; writes go through SQL functions.
- Users can update only their own member row fields such as `last_read_at` and `cleared_at`.
- Users can select and update only their own notification preference and notification rows.

## Flutter structure

Create a focused chat feature folder:

- `apps/mobile/lib/src/features/chat/data/chat_models.dart`
- `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`

Modify:

- `apps/mobile/lib/src/features/shell/presentation/main_shell.dart` to replace the Chats placeholder with `ChatPage`.
- Profile message actions can later route to `create_direct_conversation`, but this can be included only if the existing profile button integration is small and safe.

## UI direction

The UI should feel refined, calm, and social rather than generic.

- Preserve the project palette: navy `#0B1F3E`, cyan `#4490AD`, light background `#FAFCFC`, input grey `#F1F5F9`, border `#E2E8F0`.
- Use soft cards, rounded search fields, compact badges, and clear avatar hierarchy.
- Add subtle depth through shadows and tinted cyan surfaces, not unrelated colors.
- Keep destructive clear-chat styling red and explicit.
- Empty states should be friendly and useful, for example guiding the user to search followers/following or create a group.

## Error handling

- If Supabase is unavailable, show a friendly retry state on chat home and conversation screens.
- If sending fails, keep the typed message in the input and show an error snackbar.
- If the stranger limit is reached, show a clear message: the recipient must accept the request before more messages can be sent.
- If a group member selection is invalid, keep the picker open and explain that stranger request users cannot be added.
- If clear chat fails, keep the current message list and show a retry snackbar.

## Testing and verification

Database verification:

- Review SQL constraints and RLS policies.
- Verify functions enforce the stranger limit and group membership rules.

Flutter verification:

- Model parsing tests for conversations, messages, notifications, and members.
- Repository tests using a fake data source where practical.
- Widget tests for chat home empty/list/badge states.
- Widget tests for group picker selection and disabled/enabled create button.
- Widget tests for conversation input sending and clear-chat confirmation.

Manual verification:

- Accepted direct chat appears in recents.
- Stranger request does not appear in recents.
- Stranger sender can send messages 1, 2, and 3, but not 4.
- Accepting a request enables normal chat.
- Group suggestions exclude stranger request users.
- Clear chat hides messages for only the current user.
- Red badges update after new chat/activity/system/follower notifications.

## Rollout order

1. Add database schema, functions, policies, and triggers.
2. Add Flutter chat data models and repository.
3. Add chat home UI and wire it into the shell.
4. Add direct conversation and text messaging.
5. Add group creation and group messaging.
6. Add conversation details and per-user clear chat.
7. Add in-app notifications, badges, and realtime subscriptions.
8. Run formatting, analysis, and tests.

## Self-review notes

- No Perspective API remains in the chat design.
- Chat moderation and AI review are explicitly out of scope.
- External push notifications are deferred; in-app notification data and badges are in scope.
- Stranger recent chats are explicitly excluded from recents and group suggestions.
- Clear chat is explicitly current-user-only.
- The design is large but cohesive enough for one implementation plan because all pieces share one chat data model and UI entry point.
