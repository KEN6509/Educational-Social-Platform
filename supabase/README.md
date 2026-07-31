# Supabase Setup

## 1. Create Project

Create a new Supabase project named `CyanZone`.

Save:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## 2. Configure Auth

For the prototype:

- Enable email/password auth.
- Disable role selection during registration.
- Keep email confirmation optional for local demo speed.

The `profiles` table is added in Phase 2. The signup trigger is added in Phase 3.

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
- Chat RPC helpers for conversations, messages, read state, and clearing chats
- Notification preferences and notifications
- Activity notification triggers for follows, likes, saves, comments, and mentions
- System notification triggers for creator badges and rejected posts
- Rejected-post appeal storage and submission validation
- RLS policies and realtime publication entries for chat/notification tables
- Structured group-chat mentions, admin-only `@all`, and per-recipient mention visit state

After pulling the group-mention or MVP System Notification implementation, run
the full updated `supabase/chat.sql` in the Supabase SQL Editor. Apply it only
after `schema.sql`, `follow.sql`, and `comment_mentions.sql`. The script is
idempotent for schema objects, but inspect any SQL Editor error before rerunning
it. Do not run only a copied fragment because the functions, policies, grants,
and triggers are designed to be applied together.

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
    'notify_post_rejected_on_update'
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
- Both notification triggers are present, one on `profiles` and one on `posts`.
- The notification Delete and appeal Select policies are present.
- `submit_post_appeal` returns one routine row.

Existing creator badges and rejected posts are not backfilled. To verify live
generation, use a test account and create a new state transition after applying
the SQL: change `is_content_creator` from false to true, or change a post from a
non-rejected status to `rejected`. Re-saving the same final state does not create
another notification.

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
