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
- RLS policies and realtime publication entries for chat/notification tables

### Chat activity notification triggers

Apply `supabase/chat.sql` to the live Supabase database after pulling chat
notification changes. The Activity page depends on notification trigger types
including `comment_reply`, `comment_like`, and `mention`. Existing
notifications are not backfilled automatically; create a new comment, reply,
mention, or comment like after applying the SQL to verify the live trigger path.

## 7. Client Usage

- Flutter uses `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- React admin uses `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
- Express API uses `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.

Never expose the service role key in Flutter or React.
