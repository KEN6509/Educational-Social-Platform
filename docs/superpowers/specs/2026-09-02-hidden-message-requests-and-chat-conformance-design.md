# Hidden Message Requests and Chat Conformance Design

## Goal

Remove message requests from the active CyanZone mobile experience without deleting their existing Supabase data or backend foundation. At the same time, align direct-chat entry and group-member selection with the SRS relationship rule: the other person must be a current Follower or Following connection.

## Decisions

- Message requests become a dormant capability, not a deleted capability.
- Existing pending request conversations, messages, notifications, database columns, and RPCs remain stored.
- Pending requests are not loaded or displayed by the active mobile UI.
- Existing accepted direct conversations and their history remain available from the Messages screen.
- A profile Message action is allowed when either user follows the other.
- A profile Message action with no follow relationship stays on the profile and shows `Follow this user before sending a message.`
- Group-member candidates are limited to the deduplicated union of Followers and Following. An accepted direct-chat history alone does not make a person eligible.
- The updated `supabase/chat.sql` remains a complete rerunnable script. Message-request SQL is not commented out because comments do not disable objects already installed in Supabase.

## Considered Approaches

### 1. Hide the feature and retain its backend foundation — selected

The mobile application stops exposing and loading requests, while existing request data and server functions remain available for possible future implementation. This avoids destructive migration and makes restoration straightforward.

### 2. Comment out request-related SQL

This would only omit code during a future script run. It would not remove or disable functions and schema objects already installed in the hosted database, and it could make fresh environments differ from the existing environment. This approach is rejected.

### 3. Delete request schema and pending conversations

This would produce the smallest active schema but would destroy pending conversations and make later restoration more expensive. This approach is rejected.

## Mobile Chat Home

The Messages screen will expose only the All, Unread, and Groups filters. It will no longer fetch request conversations, calculate request unread counts, restore or update the request cache, or render the request-specific empty state.

The existing request models and repository methods remain as dormant integration code. Existing request cache values already stored on devices are left untouched but are no longer read by the Messages screen. This preserves reversibility without spending network or rendering work on a hidden feature.

Normal direct and group conversations keep their existing realtime subscriptions, unread calculations, local recent-conversation cache, search, and history behavior.

## Relationship-Gated Direct Chat

The active mobile application will use a relationship-gated Supabase RPC when starting or opening a direct chat from a person result or another user's profile. The RPC will:

1. Require an authenticated user and a valid target profile.
2. Check for a row in `public.follows` in either direction.
3. Reject the action with a stable `Follow relationship required` error when no relationship exists.
4. Reuse the existing direct conversation when one exists.
5. Create an accepted conversation with two active members when no conversation exists.
6. Promote an old pending conversation to accepted with active members if the users later establish a follow relationship and explicitly open the chat.

The current request-capable RPC remains installed but is no longer called by active Flutter flows. This separates the production UI rule from the dormant feature and prevents active screens from accidentally creating new pending requests.

The profile page maps the stable relationship error to `Follow this user before sending a message.` and does not navigate. Other failures continue to use the existing friendly error handling. A successful call constructs the normal direct-conversation model and opens `ChatRoomPage`.

Existing accepted conversations can still be opened directly from the Messages list even if the users later unfollow each other. This preserves established chat history. The relationship gate applies when initiating through a profile or eligible-person result, as requested.

## Group-Member Conformance

`ChatRepository.fetchSuggestedGroupMembers` will use only follower and following rows. It will stop querying accepted direct conversations and their members.

The server-side group eligibility helper will independently require a `public.follows` row in either direction. It will no longer treat an accepted direct conversation or a parent-child link by itself as group-member eligibility. Both group creation and later member addition continue to call this helper, so direct RPC calls cannot bypass the SRS rule.

The user-facing group error becomes `Only followers or people you follow can be added.`

## Supabase Script and Existing Data

The request-related columns, constraints, statuses, request-capable RPC, acceptance RPC, and three-message limit remain in `supabase/chat.sql`. They are intentionally dormant rather than commented out.

The script will add or replace the relationship-gated direct-chat RPC and replace the group-member eligibility function. Rerunning the complete updated script in the Supabase SQL Editor preserves existing rows because table creation uses `if not exists`, while `create or replace function` updates function definitions. Existing request data remains present.

The repository change alone does not update the hosted database. After implementation and local verification, the updated complete `supabase/chat.sql` must be run once more for the new server rules to take effect. Any SQL Editor error must be inspected before retrying.

## Documentation

`Project_Overview.md`, the mobile README, and the Supabase setup notes will describe message requests as hidden/dormant and the active chat relationship rules as Followers/Following only. Historical specifications and implementation plans remain unchanged as records of earlier decisions.

The project overview will also record that the previous versions of the three noted SQL files were applied, while the newly changed `chat.sql` still requires reapplication after this work.

## Testing

Implementation will follow test-driven development:

- A widget test will fail until the Requests filter and request empty state are absent.
- A chat-home test will verify that the hidden request loader is not part of the active loading path.
- Profile action tests will cover successful navigation and the exact follow-first message without navigation.
- Repository/SQL tests will verify that active direct-chat entry uses the relationship-gated RPC.
- Repository tests will verify accepted direct-chat participants are not added to group suggestions.
- SQL tests will verify group creation and member addition use follow-only eligibility and that the dormant request functions remain present.
- Focused Flutter tests will run during each red-green cycle, followed by the complete Flutter test suite and `flutter analyze` before completion.

## Out of Scope

- Deleting or displaying existing pending requests.
- Building a request-acceptance UI.
- Changing normal chat realtime delivery, message history, unread behavior, or clear-chat behavior.
- Removing dormant request schema or RPCs.
- Applying SQL automatically to the hosted Supabase project.
- The later file-structure, design-pattern, and optimization review.
