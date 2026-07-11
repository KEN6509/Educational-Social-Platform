# Group Chat Mentions Design

**Date:** July 12, 2026  
**Status:** Approved

## Goal

Add reliable member mentions to group chat without placing chat events in the post-focused Activity section. Mentions must support member autocomplete, repeated visible mentions, profile navigation, unread mention navigation, an admin-only `@all` option, and a durable data model suitable for later FCM/APNs delivery.

## Scope

This implementation covers group text messages only. Direct chats do not show mention suggestions. Image-only and shared-post messages do not carry mentions in this pass. Device push delivery remains part of the later FCM/APNs cycle.

## Composer Experience

- Typing `@` at the start of a token opens a member suggestion panel above the composer.
- Suggestions contain active group members other than the current user and filter by display name as the user types.
- Selecting a member inserts `@Display Name` and a trailing space.
- The same member may be visibly inserted multiple times in one message.
- For an active group admin, `@all` is the first suggestion. Non-admin members never see or submit `@all`.
- Selecting `@all` inserts the literal `@all` token. It targets every other active group member at send time.
- Editing or deleting part of an inserted token invalidates that entity unless its complete token still occupies the recorded span. Sending never infers a recipient from unselected plain `@text`.

## Data Model

Add a normalized `public.chat_message_mentions` table with:

- `message_id` referencing `chat_messages` with cascade deletion
- `mentioned_user_id` referencing `profiles`
- `display_text` containing the selected label, or `@all`
- `start_offset` and `end_offset` identifying a visible occurrence in message content
- `created_at`
- `visited_at`, set when the recipient navigates to or visits the mention target

The primary uniqueness rule covers `(message_id, mentioned_user_id, start_offset)`, allowing the same member to appear repeatedly in one bubble. Recipient event queries deduplicate by `(message_id, mentioned_user_id)`, so one message produces only one notification/event for a recipient regardless of repeated visible occurrences or overlap with `@all`.

RLS permits active conversation members to read mention entities for visible messages. Clients cannot insert arbitrary rows directly; mention creation occurs inside the message-send RPC so membership, group type, sender authority, offsets, and recipient IDs are validated atomically.

## Send and Validation Flow

The text-message send RPC accepts structured mention entities in addition to message content.

For each entity, SQL verifies:

1. The conversation is a group and the sender is an active member.
2. The referenced message span matches the submitted display text.
3. A normal recipient is another active group member.
4. `@all` is submitted only by an active group admin.

`@all` expands to all other active members. Duplicate recipients are collapsed for event creation while individual visible entity rows remain available for rendering.

Invalid mention metadata rejects the send rather than silently notifying the wrong user. Plain text still sends normally when it contains no selected mention entities.

## Reading and Navigation

- Mention spans render in the same dark green used for tappable comment mentions.
- Every normal `@Display Name` occurrence is independently tappable and opens the selected member's profile.
- `@all` uses the same dark-green style but is not a profile link.
- The chat home conversation row shows an `@` indicator when the current user has an unvisited mention in that conversation.
- Opening a conversation with unread mentions positions the room at the oldest unvisited mentioned message.
- Inside the room, an `@` floating button appears above the existing jump-to-bottom button while unvisited mentions remain.
- Pressing it visits the oldest remaining mention, then later mentions in chronological order.
- A message with repeated mentions of the current user appears once in this navigation sequence.
- Visiting a target marks that recipient/message event visited. The button and conversation indicator disappear when none remain.
- Unsend and message deletion automatically remove related mention rows through cascading deletion.

## Notification Boundary

Group-chat mention events belong only to Chats. They do not create Activity rows or appear in the Activity notification page.

For this cycle, the durable unvisited mention record, conversation `@` indicator, room navigation button, and normal chat unread state are the in-app notification experience. The later push cycle will use the same deduplicated message-recipient events for FCM/APNs delivery.

## Offline and Realtime Behaviour

- Mention entities are included in message payloads and recent-message cache data so cached bubbles retain styling and profile targets.
- Realtime message refresh also reloads mention state.
- If a cached profile target is unavailable, tapping the mention attempts normal profile loading and shows the existing friendly failure path when necessary.
- Offline navigation can jump only to mentioned messages present in the local recent-message cache.

## Error Handling

- Failed member loading hides the suggestion panel without blocking plain text chat.
- A rejected mention send keeps the draft and shows a friendly send error.
- If group membership changes before send, the server rejects invalid recipients; the user can refresh suggestions and retry.
- Marking a mention visited is optimistic in the UI and retried by the same refresh paths used for chat read state.

## Testing

Tests cover:

- Parsing and caching multiple mention entities
- Repeated visible mentions with one recipient event
- Admin-only `@all` expansion and non-admin rejection
- Membership and offset validation in SQL contract tests
- Autocomplete filtering and insertion
- Dark-green rendering and profile navigation
- Conversation `@` indicator
- Oldest-first room entry and `@` button traversal
- Deduplication when a member is named directly and through `@all`
- Cascade behaviour for unsent/deleted messages
- Regression coverage for ordinary text, image, shared-post, unread-divider, and jump-to-bottom behaviour

## Manual Supabase Step

After implementation and local verification, the user must run the updated `supabase/chat.sql` in the Supabase SQL Editor. No automated remote migration will be performed. The handoff must call out the exact file and provide a short verification query.

## Approved UI Polish

- The shared mention/accent color is `#128C7E`, matching group-chat sender names.
- The mention suggestion list overlays the chat history above the composer and never pushes messages upward.
- At most four suggestion rows are visible; additional rows scroll inside the overlay.
- `@all` uses the same avatar size and text-column alignment as member rows, with a `#128C7E` avatar.
- Dividers begin at the name/text column, not beneath the avatar.
- Tapping chat space outside the composer and suggestion overlay dismisses both the keyboard and mention list.
- The conversation mention indicator is a centered white `@` on a `#128C7E` circular background.
- The in-room mention-navigation `@` is optically centered.
- Mention-only message bubbles shrink-wrap their content instead of expanding to the maximum bubble width.
