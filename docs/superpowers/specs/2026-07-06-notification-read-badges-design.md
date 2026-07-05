# Notification Read State, Badge Counts, and Unread Filter Design

Date: 2026-07-06

## Scope

This spec covers fixes and refinements for the chat notification module:

- Activity tracking/read-state behavior
- Activity post navigation failure handling
- Activity/System/New Followers badge clearing
- Chat tab bottom-bar badge count
- Per-conversation unread message badges
- Messages filter bar with new Unread category

System Notifications content design remains out of scope; only read-state and badge behavior are included.

## Root cause summary

The current implementation has three separate issues:

1. Activity comments/replies/mentions only appear if the live Supabase database has the updated notification triggers. The repo SQL supports these events, but old database triggers will not update themselves and old events will not backfill automatically.
2. Activity/System/New Followers pages display notifications but do not mark them as read when the user leaves the page. Therefore `read_at` stays null and red badges remain.
3. Conversation rows currently do not calculate unread message counts from message/member state, and the bottom navigation chat badge only counts `chat_message` notifications.

## Activity tracking and missing post handling

The repo keeps explicit activity notification types:

- `like`
- `favorite`
- `comment`
- `comment_reply`
- `comment_like`
- `mention`

The implementation should keep SQL tests covering the related triggers and add clear developer documentation or migration notes that the updated `supabase/chat.sql` must be applied to the live Supabase database. Existing notifications created before the trigger update do not need to be backfilled in this pass.

When a user taps an Activity row:

- If the related post exists and is approved, open the post detail page.
- If the post is deleted, pending, rejected, removed, missing, or otherwise unavailable, do not navigate.
- Show a snackbar: `This post can't be viewed. It may be deleted or not approved yet.`

## Marking notification sections as read

When a user opens Activity, System Notifications, or New Followers and then leaves that page, the app should mark that section's unread notifications as read.

Implementation behavior:

- Add a repository method to mark all unread notifications for a `NotificationSection`.
- Activity marks all unread non-chat, non-system, non-new-follower notifications.
- System marks unread `system` notifications.
- New Followers marks unread `new_follower` notifications, including items filtered out by the 30-day UI if they are still unread.
- Chat message notifications are not marked read by opening these notification-section pages; chat read behavior remains tied to chat room/conversation read handling.
- After returning from a notification-section page, the Chats page refreshes counts so the shortcut red badge disappears unless new unread notifications arrived.

## Badge count rules

### Notification shortcut badges

Activity, System, and New Followers shortcut badges display the exact unread count for that section.

### Conversation row badges

Each conversation row displays the unread message count for that conversation.

Unread message count should be calculated from:

- messages in the conversation
- `chat_conversation_members.last_read_at`
- excluding messages sent by the current user
- excluding deleted messages
- excluding messages hidden by `cleared_at`

### Bottom-bar chat badge

The bottom message icon badge should not sum every unread notification. It should count sources:

- Activity unread count greater than 0 contributes `1`
- System unread count greater than 0 contributes `1`
- New Followers unread count greater than 0 contributes `1`
- Each conversation with unread messages contributes `1`

Example: Activity has 5 unread, System has 2 unread, New Followers has 0 unread, and 3 conversations have unread messages. Bottom badge = `1 + 1 + 0 + 3 = 5`.

## Messages filter bar

The Messages filter order becomes:

- All
- Unread
- Groups
- Requests

Filter behavior:

- All: all accepted conversations
- Unread: conversations where `unreadCount > 0`
- Groups: group conversations
- Requests: message requests from the latest 30 days

Filter chip design:

- Default chip background is white.
- Every category chip has a visible border.
- Selected chip keeps the current dark green selected style.
- Text should stay comfortable and not too bold.

Unread empty state:

- Reuse the visual style of the existing `No recent message requests` state.
- Title: `No chats in Unread`
- Subtitle/action text: `View all chats`
- `View all chats` uses the same dark green as the selected category.
- Tapping `View all chats` switches the filter back to All.

## Testing

Add or update tests for:

- Activity unavailable post snackbar behavior.
- Notification section page marks section notifications read when leaving.
- Chats page refreshes counts after returning from Activity/System/New Followers.
- Repository calculates unread conversation counts correctly.
- Bottom-bar badge source-count logic.
- Messages filter bar includes All, Unread, Groups, Requests in that order.
- Unread empty state shows `No chats in Unread` and `View all chats`.
- Tapping `View all chats` switches back to All.

Run formatting, analysis, focused tests, and the full Flutter test suite before claiming completion.
