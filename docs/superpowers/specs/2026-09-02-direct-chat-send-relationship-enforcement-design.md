# Direct Chat Send Relationship Enforcement Design

## Goal

Prevent two users from sending new direct messages after their final follow relationship is removed, while keeping their existing conversation and message history visible.

## Confirmed Behavior

- A direct conversation remains listed and can still be opened after both follow directions are removed.
- Existing direct-message history remains readable.
- Sending is allowed while either participant follows the other.
- Sending is blocked once neither participant follows the other.
- A blocked direct chat replaces its normal composer and empty-state `Start chatting` prompt with `Follow this user to continue chatting.`
- Text, image, and Send actions are unavailable while blocked.
- Group-chat behavior is unchanged.

## Root Cause

The current relationship check runs only when a user opens or creates a direct conversation through `open_direct_conversation`. Once a direct conversation exists, both participants remain active conversation members. `ChatRoomPage` has no current relationship state, and `send_chat_message` authorizes an active member without rechecking `public.follows`. Consequently, removing both follow rows does not revoke send permission.

## Considered Approaches

### 1. Mobile UI enforcement only

The chat room could query the follow relationship and disable its composer. This gives immediate feedback but is insufficient because a stale client or direct RPC call could still send a message.

### 2. Supabase enforcement only

`send_chat_message` could reject a direct message when no follow relationship exists. This is secure, but the composer would still appear usable until a send fails.

### 3. Mobile and Supabase enforcement — selected

The mobile chat room exposes the current permission clearly, while Supabase remains the final authority on every write. This prevents both misleading UI and bypasses caused by stale or modified clients.

## Backend Design

A focused RPC will report whether the authenticated member may currently send in a conversation. Group conversations return allowed for active members. Direct conversations return allowed only when both participants are active and a `public.follows` row exists in either direction.

`send_chat_message` will independently apply the same current-follow check before inserting a direct message. When no relationship exists it raises the stable error `Follow relationship required`. Existing membership, history visibility, conversation rows, and dormant message-request infrastructure remain unchanged.

## Mobile Design

`ChatRepository` will expose the conversation send-permission RPC. `ChatRoomPage` will load that permission when the room opens and refresh it when the application resumes.

For a blocked direct conversation:

- the normal text, image, and Send controls are replaced by a non-interactive follow-required notice;
- an empty message list shows the follow-required notice instead of `Start chatting`;
- existing messages remain visible and selectable under the current rules.

The backend may detect an unfollow before the UI refreshes. If a send returns `Follow relationship required`, the page keeps the unsent draft, changes to the blocked state, and shows the same follow-required message. This closes the stale-state window without subscribing the room to every follow-table change.

Injected widget-test callbacks will allow the permission loader to be tested without a live Supabase client. Group chats default to their existing send behavior and are unaffected by the direct-chat relationship gate.

## Error Handling

- Relationship denial uses `Follow this user to continue chatting.`
- The draft is cleared only after a successful send.
- Existing mappings for missing conversations, inactive membership, pending-request limits, and connectivity errors remain intact.
- Image sending relies on the same loaded permission and cannot start while the direct chat is blocked.

## Testing Scope

Implementation uses focused test-driven development:

- SQL migration tests verify that direct sends call the follow-only relationship helper and raise the stable relationship error.
- Repository tests verify the new permission RPC name and mapping.
- Chat-room widget tests verify the blocked composer, replacement of `Start chatting`, readable history, unchanged group composer, and transition to blocked state after a rejected stale send while preserving the draft.
- Only the related chat SQL, repository, model, and widget test files will run for final verification, as requested. The full Flutter suite is not required for this fix.

## Deployment

The updated complete `supabase/chat.sql` must be rerun in the Supabase SQL Editor after the code change. Its idempotent table statements preserve existing chat data, while `create or replace function` installs the new permission and send enforcement. Until this rerun occurs, the hosted backend cannot enforce the new rule or expose the permission RPC.

## Out of Scope

- Removing old direct conversations or message history.
- Restoring the hidden message-request UI.
- Changing follow/unfollow behavior.
- Changing group-chat eligibility or sending.
- Applying SQL automatically to the hosted Supabase project.
