# Supabase Setup

## 1. Create Project

Create a new Supabase project named `CyanZone`.

Save:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## 2. Configure Auth

For the MVP:

- Enable email/password auth.
- Disable role selection during registration.
- Enable `Confirm Email` under the Email provider before testing mobile registration.

The `profiles` table is added in Phase 2. The signup trigger is added in Phase 3.

### Registration consent and email OTP

For an existing project, run `registration_consent_otp.sql` after `schema.sql`.
This is the only new SQL migration needed for the registration change. It adds
the consent audit columns, delays new public profiles until email confirmation,
and installs the confirmation trigger. It is safe to rerun. Do not rerun the
chat or Parent Supervision migrations for this feature.

In the hosted Supabase Dashboard:

1. Open `Authentication` -> `Providers` -> `Email`.
2. Keep Email enabled and enable `Confirm Email`.
3. Open `Authentication` -> `Email Templates` -> `Confirm signup`.
4. Set the subject to `Your CyanZone verification code`.
5. Replace the template body with:

```html
<h2>Verify your CyanZone email</h2>
<p>Enter this code in CyanZone to finish creating your account:</p>
<p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">
  {{ .Token }}
</p>
<p>If you did not create this account, you can ignore this email.</p>
```

6. Save the template.
7. Open `SQL Editor`, paste the complete `registration_consent_otp.sql`, and
   run it once.

Verify the migration:

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'terms_version',
    'privacy_version',
    'consent_accepted_at'
  )
order by column_name;

select trigger_name
from information_schema.triggers
where event_object_schema = 'auth'
  and event_object_table = 'users'
  and trigger_name in (
    'on_auth_user_created',
    'on_auth_user_email_confirmed'
  )
order by trigger_name;
```

Expected result: three consent-column rows and two auth-trigger rows. The
mobile app uses the six-digit `{{ .Token }}` value and verifies it as a signup
OTP. When a normal pending email becomes confirmed, the database rejects the
confirmation if the current Terms version, Privacy version, or acceptance time
is missing. Existing users remain usable even if their consent columns are
null, and trusted service users created already confirmed (such as the first
administrator) retain their existing creation path.

## 3. Configure Storage

Run `storage.sql` in the Supabase SQL editor.

Buckets:

- `avatars`
- `images`

The `images` bucket is shared by post images and chat image messages. Current
cleanup paths remove objects for deleted posts, unsent image messages, and group
conversations deleted after the final member exits.

## 4. Create Database Schema

Run `schema.sql` in the Supabase SQL editor after `storage.sql`.

Phase 2 creates:

- User profiles and content creator requests
- Posts, post images, comments, likes, saves, and reports
- Parent-child links
- Screen time logs
- Check-ins
- SOS alerts
- RLS starter policies
- Feed and relationship indexes
- Realtime publication entries for key live tables

Quick verification query:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles',
    'content_creator_requests',
    'posts',
    'post_images',
    'comments',
    'likes',
    'saves',
    'reports',
    'parent_child_links',
    'screen_time_logs',
    'check_ins',
    'sos_alerts'
  )
order by table_name;
```

Expected result: 12 rows.

Check RLS is enabled:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'profiles',
    'posts',
    'comments',
    'parent_child_links',
    'sos_alerts'
  );
```

Expected result: `rowsecurity` is `true` for each listed table.

### Parent Supervision

Fresh projects receive the complete Parent Supervision contract from the current
`schema.sql`. For an existing project that was created from an earlier schema,
run the complete `parent_supervision.sql` in the Supabase SQL Editor after
`schema.sql` and before mobile verification. Do not run only a copied function
or policy fragment; the tables, RPCs, notification fan-out, RLS policies, grants,
and Realtime publication entries are designed to be applied together.

The current migration is idempotent for the existing Parent Supervision data:
rerunning the complete file keeps existing alerts and records, creates the live
SOS objects, and backfills available legacy SOS coordinates and timeline events
where the stored data is sufficient.

Verify the six core module tables:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'parent_child_links',
    'check_ins',
    'sos_alerts',
    'sos_live_locations',
    'sos_events',
    'supervision_notifications'
  )
order by table_name;
```

Expected result: six rows. `sos_live_locations` holds one latest coordinate row
per SOS (the final row remains after resolution), while `sos_events` holds the
append-only triggered, per-parent acknowledged, and resolved timeline. The
supporting `screen_time_logs`,
`screen_time_sync_events`, and `screen_time_threshold_events` tables must also
exist for CyanZone usage synchronization and threshold events.

Verify all twelve authenticated Parent Supervision RPCs:

```sql
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'create_parent_child_link',
    'accept_parent_child_link',
    'reject_parent_child_link',
    'cancel_parent_child_link',
    'submit_safety_check_in',
    'submit_sos_alert',
    'acknowledge_sos_alert',
    'resolve_sos_alert',
    'update_sos_live_location',
    'fetch_active_sos_alert',
    'sync_screen_time_session',
    'mark_supervision_notification_read'
  )
order by routine_name;
```

Expected result: twelve rows.

Verify the owner/family read policies and Realtime publication:

```sql
select policyname, tablename, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'parent_child_links',
    'screen_time_logs',
    'check_ins',
    'sos_alerts',
    'sos_live_locations',
    'sos_events',
    'supervision_notifications'
  )
order by tablename, policyname;

select tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in (
    'parent_child_links',
    'sos_alerts',
    'sos_live_locations',
    'sos_events',
    'supervision_notifications'
  )
order by tablename;
```

The publication query must return all five listed tables. SOS GPS capture runs
approximately every 10 seconds only while CyanZone is in the foreground. It
pauses when the app is minimized, locked, or terminated, and resumes the newest
unresolved child SOS when the app returns. Resolution prevents further server
location updates. OpenStreetMap tiles are a best-effort visual layer for the
MVP/UAT and do not affect coordinate capture or Supabase updates when tiles are
unavailable. Current notification delivery is in-app Realtime only.
FCM remains deferred until device push delivery is added later; Supervision Notifications
remain separate from Messages notifications. Physical-device GPS, lifecycle,
multi-account, and live Realtime evidence remains part of the manual acceptance
pass.

## 5. Configure Authentication

Run `auth.sql` in the Supabase SQL editor after `schema.sql`.

Phase 3 adds:

- `auth.users` trigger to auto-create rows in `profiles`
- Admin helper function
- Admin RLS policies for creator requests, reports, posts, comments, and profiles

Quick signup trigger verification:

```sql
select trigger_name, event_object_schema, event_object_table
from information_schema.triggers
where trigger_name = 'on_auth_user_created';
```

Expected result: 1 row for `auth.users`.

## 6. Configure Chat and Notifications

Run `follow.sql` after `schema.sql`, then run `comment_mentions.sql`, then run `chat.sql`.

`chat.sql` adds:

- Direct and group chat tables
- Chat RPC helpers for relationship-gated active conversations, dormant message requests, messages, read state, and clearing chats
- Notification preferences and notifications
- Activity notification triggers for follows, likes, saves, comments, and mentions
- System notification triggers for creator badges, rejected posts, and posts
  moving from Pending to Approved
- Rejected-post appeal storage and submission validation
- RLS policies and realtime publication entries for chat/notification tables
- Structured group-chat mentions, admin-only `@all`, and per-recipient mention visit state

After pulling the group-mention or MVP System Notification implementation, run
the full updated `supabase/chat.sql` in the Supabase SQL Editor. Apply it only
after `schema.sql`, `follow.sql`, and `comment_mentions.sql`. The script is
idempotent for schema objects, but inspect any SQL Editor error before rerunning
it. Do not run only a copied fragment because the functions, policies, grants,
and triggers are designed to be applied together.

Message requests are currently hidden in the mobile product but their existing
rows, columns, request-capable RPC, acceptance RPC, and three-message limit are
retained for possible future use. Do not comment out those SQL sections:
comments do not disable functions already installed in Supabase and would make
fresh databases differ from existing databases.

If an earlier `chat.sql` was already applied, run the complete updated file
again. `create table if not exists` keeps existing tables and rows, while
`create or replace function` installs the latest `open_direct_conversation`,
`can_send_chat_message`, follow-gated `send_chat_message`, and follow-only
group-member rules. Existing direct conversations and messages remain stored;
when neither participant follows the other, history stays readable but new
direct messages are rejected. Inspect and resolve any SQL Editor error before
retrying.

Verify the active and dormant chat functions:

```sql
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'open_direct_conversation',
    'can_send_chat_message',
    'create_direct_conversation',
    'accept_message_request',
    'chat_can_add_group_member'
  )
order by routine_name;
```

Expected result: all five routines are present. Active Flutter entry points use
`open_direct_conversation`, and direct chat rooms use `can_send_chat_message`;
the request-capable functions remain dormant.

Verify the mention objects:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name = 'chat_message_mentions';

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'send_chat_message',
    'fetch_unvisited_chat_mentions',
    'mark_chat_mention_visited'
  )
order by routine_name;
```

Verify the MVP System Notification and appeal objects:

```sql
select to_regclass('public.post_appeals') as post_appeals_table;

select trigger_name, event_object_table
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in (
    'notify_content_creator_awarded_on_update',
    'notify_post_rejected_on_update',
    'notify_post_approved_on_update'
  )
order by trigger_name;

select policyname, tablename, cmd
from pg_policies
where schemaname = 'public'
  and (
    policyname = 'Users delete own notifications'
    or policyname = 'Users view own post appeals'
  )
order by policyname;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'submit_post_appeal';
```

Expected results:

- `post_appeals_table` is `public.post_appeals`.
- All three notification triggers are present: one on `profiles` and two on
  `posts`.
- The notification Delete and appeal Select policies are present.
- `submit_post_appeal` returns one routine row.

Existing creator badges and moderation outcomes are not backfilled. To verify
live generation, use a test account and create a new state transition after
applying the SQL: change `is_content_creator` from false to true, change a post
from a non-rejected status to `rejected`, or change a post specifically from
`pending` to `approved`. Re-saving the same final state does not create another
notification. The Administration Portal AI queue now reads and writes real
moderation cases through the privileged API.

### Administration Portal

Run `admin_portal.sql` after `chat.sql`.

The migration adds the administrator audit trail, duplicate unresolved-report
protection, appeal review access, and the trusted account, creator-request,
report, and appeal decision functions used by the Express Admin API.

Fresh projects receive the simplified report lifecycle from the current
`schema.sql` and `admin_portal.sql`: `pending_review`, `resolved`, and
`dismissed`, with reason-only reports. Existing databases created from the
earlier Open/Reviewing schema must run `report_flow_simplification.sql` after
`admin_portal.sql`. Review that script before executing it because it replaces
the enum and drops `reports.description`. It is committed for manual use and is
not applied to the live Supabase project automatically.

Verify:

```sql
select to_regclass('public.admin_action_audit');

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'set_user_account_status',
    'set_user_creator_status',
    'review_creator_request',
    'decide_report_case',
    'decide_post_appeal'
  )
order by routine_name;
```

Expected results:

- `to_regclass` returns `public.admin_action_audit`.
- The routine query returns five rows.

### Gemini moderation

Run `ai_moderation.sql` after `admin_portal.sql` for an existing project. The
complete migration creates `content_moderation_cases`, revisioned moderation
results, RLS policies, and the service-role RPCs used by the Express API:

- `prepare_content_moderation`
- `apply_ai_moderation_result`
- `mark_content_moderation_failed`
- `decide_content_moderation_case`

It is designed to be rerun: table/index/policy creation is guarded and the
functions are replaced with their current definitions. Inspect any SQL Editor
error before retrying. The Gemini key is configured only in the API environment;
Supabase does not call Gemini directly.

Verify the hosted objects:

```sql
select to_regclass('public.content_moderation_cases');

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'prepare_content_moderation',
    'apply_ai_moderation_result',
    'mark_content_moderation_failed',
    'decide_content_moderation_case'
  )
order by routine_name;

select relname, relrowsecurity
from pg_class
where oid = 'public.content_moderation_cases'::regclass;
```

Expected results are one `content_moderation_cases` table, four routine rows,
and `relrowsecurity = true`. This is live SQL verification: it checks the
deployed database objects, RLS, and API prerequisites. It is unrelated to chat
history consistency.

### Chat activity notification triggers

Apply `supabase/chat.sql` to the live Supabase database after pulling chat
notification changes. The Activity page depends on notification trigger types
including `comment_reply`, `comment_like`, and `mention`. Existing
notifications are not backfilled automatically; create a new comment, reply,
mention, or comment like after applying the SQL to verify the live trigger path.

Current mobile notifications are in-app Supabase rows and badges. External
FCM/APNs device push delivery is not configured yet.

## 7. Client Usage

- Flutter uses `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- React admin uses `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
- Express API uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.

Never expose the service role key in Flutter or React.
