# Chat Follow-Gate Supabase Upgrade Design

Date: 2026-09-13
Status: Approved for implementation planning

## Context

The current `supabase/chat.sql` already defines `can_send_chat_message` and
checks it inside `send_chat_message`. A hosted project that ran an older copy
of `chat.sql` can still lack those changes. In that state, mobile permission
checks fail and the older send function may accept a direct message after the
last follow relationship is removed.

## Selected Approach

Add a dedicated `supabase/chat_follow_gate_upgrade.sql` for existing CyanZone
databases. Keep `supabase/chat.sql` as the canonical complete setup for fresh
projects. Document which file fresh and existing projects should run.

The upgrade file will:

- create or replace `public.can_send_chat_message(uuid)`;
- replace `public.send_chat_message(uuid, text, jsonb)` with the current
  follow-gated implementation;
- apply the required authenticated execution grants;
- revoke access from `public` and `anon`; and
- finish with read-only verification queries.

## Safety

The script must not drop or truncate chat tables, delete conversations, delete
messages, or change existing history. Existing direct conversations remain
readable. It changes only callable database functions and their permissions.

The legacy two-argument `send_chat_message(uuid, text)` overload may be dropped
to prevent PostgREST from selecting an obsolete signature. This does not alter
stored rows.

## Runtime Behaviour

For an active group member, sending continues normally. For a direct chat,
sending is allowed only while either participant follows the other. When no
follow row exists in either direction, both the permission RPC and the final
send RPC deny the operation. Mobile can therefore block its composer before
sending, while Supabase remains authoritative against stale or modified
clients.

## Documentation

Update `supabase/README.md` so:

- fresh projects run the complete `chat.sql`;
- projects configured from an older `chat.sql` may run the focused upgrade;
- the upgrade's dependency order is explicit; and
- users know that SQL files are not applied automatically by a Git pull or
  Vercel deployment.

## Verification

Automated source tests will require the upgrade file to contain the permission
function, the protected send check, grants, revokes, and non-destructive
verification statements. Existing chat SQL and Flutter chat tests must remain
passing.

Manual hosted verification will confirm that both function signatures exist
and that the deployed `send_chat_message` definition calls
`can_send_chat_message`.

## Out of Scope

- Deleting existing direct-chat history.
- Restoring the hidden message-request UI.
- Changing group membership rules.
- Automatically applying SQL to the hosted Supabase project.
- Building a full Supabase CLI migration pipeline during this MVP correction.
