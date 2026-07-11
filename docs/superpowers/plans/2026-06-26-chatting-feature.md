# Chatting Feature Implementation Plan

> Historical implementation plan. The chat module is implemented and heavily
> extended as of 2026-07-11; unchecked boxes and embedded code are not a current
> backlog. Use `Project_Overview.md`, source code, and tests for current behavior.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build CyanZone's Supabase-backed chat feature with direct chats, group chats, stranger request limits, per-user clear chat, in-app notification sections, realtime badges, and a polished mobile UI.

**Architecture:** Supabase Postgres owns chat data, RLS, and sensitive write functions. Flutter owns presentation, local interaction state, and calls a `ChatRepository` that wraps Supabase RPC/select/realtime APIs. UI is delivered as focused chat feature files and wired into the existing shell tab.

**Tech Stack:** Flutter/Dart, Supabase Flutter `^2.8.2`, Supabase Postgres SQL/RLS/functions/realtime, Flutter widget/model tests.

---

## Source spec

Use this approved design as the source of truth:

- `docs/superpowers/specs/2026-06-26-chatting-feature-design.md`

## File map

- Create `supabase/chat.sql`: chat tables, indexes, functions, policies, notification triggers, realtime publication setup.
- Modify `supabase/README.md`: mention the new chat SQL script and run order.
- Create `apps/mobile/lib/src/features/chat/data/chat_models.dart`: immutable Dart models and enum parsing for chat rows.
- Create `apps/mobile/lib/src/features/chat/data/chat_repository.dart`: Supabase queries, RPC calls, realtime channel helpers, and search helpers.
- Create `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`: reusable avatars, badges, cards, bubbles, selected chips, empty/error states.
- Create `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`: chat tab home with search, notification cards, recents, and stranger requests.
- Create `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`: IG-style text-only conversation screen.
- Create `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`: TikTok-like group member picker and create action.
- Create `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart`: clear-chat-only details page.
- Create `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`: activity/system/new-follower notification lists.
- Modify `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`: import chat page, replace `_ComingSoonPage` at the Chats tab, and add chat badge count support to `_CyanZoneNavBar`.
- Modify `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`: route the existing Message button to `createDirectConversation` when safe.
- Create `apps/mobile/test/chat_models_test.dart`: parsing and computed-state tests.
- Create `apps/mobile/test/chat_repository_test.dart`: SQL/RPC parameter tests with a fake boundary where practical.
- Create `apps/mobile/test/chat_widgets_test.dart`: widget tests for badge, card, picker, send input, and clear-chat dialog behavior.

## Task 1: Add Supabase chat schema, policies, and functions

**Files:**

- Create: `supabase/chat.sql`
- Modify: `supabase/README.md`

- [ ] **Step 1: Add the chat SQL file**

Create `supabase/chat.sql` with these sections in order:

```sql
-- Chat, message requests, and in-app notifications.
-- Safe to run after supabase/schema.sql and supabase/follow.sql.

create extension if not exists pgcrypto;

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct', 'group')),
  title text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid references public.profiles(id) on delete set null,
  requested_to uuid references public.profiles(id) on delete set null,
  request_status text not null default 'none'
    check (request_status in ('none', 'pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz
);

create table if not exists public.chat_conversation_members (
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  status text not null default 'active' check (status in ('active', 'pending', 'left', 'removed')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  cleared_at timestamptz,
  primary key (conversation_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  in_app_enabled boolean not null default true,
  chat_enabled boolean not null default true,
  activity_enabled boolean not null default true,
  system_enabled boolean not null default true,
  followers_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in (
    'chat_message',
    'like',
    'favorite',
    'comment',
    'mention',
    'system',
    'new_follower'
  )),
  actor_id uuid references public.profiles(id) on delete set null,
  post_id uuid,
  comment_id uuid,
  conversation_id uuid references public.chat_conversations(id) on delete cascade,
  message_id uuid references public.chat_messages(id) on delete cascade,
  title text not null,
  body text not null,
  action_type text,
  action_payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
```

- [ ] **Step 2: Add indexes and direct-conversation uniqueness**

Append:

```sql
create unique index if not exists chat_direct_pair_unique_idx
on public.chat_conversations (
  least(requested_by, requested_to),
  greatest(requested_by, requested_to)
)
where type = 'direct' and requested_by is not null and requested_to is not null;

create index if not exists chat_conversation_members_user_idx
on public.chat_conversation_members (user_id, status);

create index if not exists chat_messages_conversation_created_idx
on public.chat_messages (conversation_id, created_at desc);

create index if not exists notifications_user_created_idx
on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_unread_idx
on public.notifications (user_id, read_at)
where read_at is null;
```

- [ ] **Step 3: Add helper functions**

Append:

```sql
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists chat_conversations_touch_updated_at on public.chat_conversations;
create trigger chat_conversations_touch_updated_at
before update on public.chat_conversations
for each row execute function public.touch_updated_at();

create or replace function public.chat_users_have_relationship(left_user uuid, right_user uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.follows
    where (follower_id = left_user and following_id = right_user)
       or (follower_id = right_user and following_id = left_user)
  );
$$;

create or replace function public.chat_can_add_group_member(owner_id uuid, candidate_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select candidate_id <> owner_id and (
    public.chat_users_have_relationship(owner_id, candidate_id)
    or exists (
      select 1
      from public.chat_conversations c
      join public.chat_conversation_members owner_member
        on owner_member.conversation_id = c.id and owner_member.user_id = owner_id
      join public.chat_conversation_members candidate_member
        on candidate_member.conversation_id = c.id and candidate_member.user_id = candidate_id
      where c.type = 'direct'
        and c.request_status = 'accepted'
        and owner_member.status = 'active'
        and candidate_member.status = 'active'
    )
  );
$$;
```

- [ ] **Step 4: Add RPC write functions**

Append these function signatures and behavior exactly:

```sql
create or replace function public.create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  existing_id uuid;
  conversation_id uuid;
  has_relationship boolean;
begin
  if current_user_id is null then
    raise exception 'You need to sign in before messaging.';
  end if;
  if target_user_id = current_user_id then
    raise exception 'You cannot message yourself.';
  end if;

  select id into existing_id
  from public.chat_conversations
  where type = 'direct'
    and least(requested_by, requested_to) = least(current_user_id, target_user_id)
    and greatest(requested_by, requested_to) = greatest(current_user_id, target_user_id)
  limit 1;

  if existing_id is not null then
    return existing_id;
  end if;

  has_relationship := public.chat_users_have_relationship(current_user_id, target_user_id);

  insert into public.chat_conversations (
    type,
    created_by,
    requested_by,
    requested_to,
    request_status
  )
  values (
    'direct',
    current_user_id,
    current_user_id,
    target_user_id,
    case when has_relationship then 'accepted' else 'pending' end
  )
  returning id into conversation_id;

  insert into public.chat_conversation_members (conversation_id, user_id, role, status)
  values
    (conversation_id, current_user_id, 'owner', 'active'),
    (conversation_id, target_user_id, 'member', case when has_relationship then 'active' else 'pending' end);

  return conversation_id;
end;
$$;

create or replace function public.create_group_conversation(title text, member_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  conversation_id uuid;
  candidate_id uuid;
  normalized_title text := nullif(trim(title), '');
begin
  if current_user_id is null then
    raise exception 'You need to sign in before creating a group.';
  end if;
  if array_length(member_ids, 1) is null or array_length(member_ids, 1) < 1 then
    raise exception 'Choose at least one person for the group.';
  end if;

  foreach candidate_id in array member_ids loop
    if not public.chat_can_add_group_member(current_user_id, candidate_id) then
      raise exception 'Only followers, following, or accepted recent chats can be added.';
    end if;
  end loop;

  insert into public.chat_conversations (type, title, created_by, request_status)
  values ('group', normalized_title, current_user_id, 'none')
  returning id into conversation_id;

  insert into public.chat_conversation_members (conversation_id, user_id, role, status)
  values (conversation_id, current_user_id, 'owner', 'active');

  insert into public.chat_conversation_members (conversation_id, user_id, role, status)
  select conversation_id, distinct_member_id, 'member', 'active'
  from unnest(member_ids) as distinct_member_id
  where distinct_member_id <> current_user_id
  on conflict do nothing;

  return conversation_id;
end;
$$;

create or replace function public.send_chat_message(conversation_id uuid, body text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  trimmed_body text := trim(body);
  conversation_record public.chat_conversations%rowtype;
  sender_status text;
  sent_count int;
  message_id uuid;
begin
  if current_user_id is null then
    raise exception 'You need to sign in before sending messages.';
  end if;
  if length(trimmed_body) = 0 or length(trimmed_body) > 2000 then
    raise exception 'Message must be between 1 and 2000 characters.';
  end if;

  select * into conversation_record
  from public.chat_conversations
  where id = conversation_id;

  if conversation_record.id is null then
    raise exception 'Conversation not found.';
  end if;

  select status into sender_status
  from public.chat_conversation_members
  where conversation_id = send_chat_message.conversation_id
    and user_id = current_user_id;

  if sender_status is null or sender_status in ('left', 'removed') then
    raise exception 'You are not allowed to send messages here.';
  end if;

  if conversation_record.type = 'direct'
     and conversation_record.request_status = 'pending'
     and conversation_record.requested_by = current_user_id
     and not public.chat_users_have_relationship(conversation_record.requested_by, conversation_record.requested_to) then
    select count(*) into sent_count
    from public.chat_messages
    where chat_messages.conversation_id = send_chat_message.conversation_id
      and sender_id = current_user_id
      and deleted_at is null;

    if sent_count >= 3 then
      raise exception 'The recipient must accept your request before you can send more messages.';
    end if;
  end if;

  insert into public.chat_messages (conversation_id, sender_id, body)
  values (conversation_id, current_user_id, trimmed_body)
  returning id into message_id;

  update public.chat_conversations
  set last_message_at = now()
  where id = conversation_id;

  insert into public.notifications (
    user_id,
    type,
    actor_id,
    conversation_id,
    message_id,
    title,
    body
  )
  select
    member.user_id,
    'chat_message',
    current_user_id,
    conversation_id,
    message_id,
    'New message',
    trimmed_body
  from public.chat_conversation_members member
  left join public.notification_preferences prefs on prefs.user_id = member.user_id
  where member.conversation_id = send_chat_message.conversation_id
    and member.user_id <> current_user_id
    and member.status in ('active', 'pending')
    and coalesce(prefs.in_app_enabled, true)
    and coalesce(prefs.chat_enabled, true);

  return message_id;
end;
$$;

create or replace function public.accept_message_request(conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  update public.chat_conversations
  set request_status = 'accepted'
  where id = conversation_id
    and type = 'direct'
    and requested_to = current_user_id
    and request_status = 'pending';

  if not found then
    raise exception 'Message request cannot be accepted.';
  end if;

  update public.chat_conversation_members
  set status = 'active'
  where conversation_id = accept_message_request.conversation_id
    and user_id = current_user_id;
end;
$$;

create or replace function public.clear_chat(conversation_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.chat_conversation_members
  set cleared_at = now()
  where conversation_id = clear_chat.conversation_id
    and user_id = auth.uid();
$$;

create or replace function public.mark_conversation_read(conversation_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.chat_conversation_members
  set last_read_at = now()
  where conversation_id = mark_conversation_read.conversation_id
    and user_id = auth.uid();
$$;
```

- [ ] **Step 5: Add follow/activity notification triggers**

Append:

```sql
create or replace function public.create_new_follower_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, actor_id, title, body)
  select
    new.following_id,
    'new_follower',
    new.follower_id,
    'New follower',
    coalesce(profile.name, profile.email, 'Someone') || ' followed you'
  from public.profiles profile
  left join public.notification_preferences prefs on prefs.user_id = new.following_id
  where profile.id = new.follower_id
    and coalesce(prefs.in_app_enabled, true)
    and coalesce(prefs.followers_enabled, true);
  return new;
end;
$$;

drop trigger if exists follows_create_new_follower_notification on public.follows;
create trigger follows_create_new_follower_notification
after insert on public.follows
for each row execute function public.create_new_follower_notification();
```

Append concrete activity notification triggers for the existing `likes`, `saves`, and `comments` tables:

```sql
create or replace function public.create_like_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id and new.reaction_type = 'like' then
    insert into public.notifications (user_id, type, actor_id, post_id, title, body)
    select owner_id, 'like', new.user_id, new.post_id, 'New like',
      coalesce(profile.name, profile.email, 'Someone') || ' liked your post'
    from public.profiles profile
    left join public.notification_preferences prefs on prefs.user_id = owner_id
    where profile.id = new.user_id
      and coalesce(prefs.in_app_enabled, true)
      and coalesce(prefs.activity_enabled, true);
  end if;
  return new;
end;
$$;

drop trigger if exists likes_create_like_notification on public.likes;
create trigger likes_create_like_notification
after insert on public.likes
for each row execute function public.create_like_notification();

create or replace function public.create_favorite_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.user_id then
    insert into public.notifications (user_id, type, actor_id, post_id, title, body)
    select owner_id, 'favorite', new.user_id, new.post_id, 'New favorite',
      coalesce(profile.name, profile.email, 'Someone') || ' saved your post'
    from public.profiles profile
    left join public.notification_preferences prefs on prefs.user_id = owner_id
    where profile.id = new.user_id
      and coalesce(prefs.in_app_enabled, true)
      and coalesce(prefs.activity_enabled, true);
  end if;
  return new;
end;
$$;

drop trigger if exists saves_create_favorite_notification on public.saves;
create trigger saves_create_favorite_notification
after insert on public.saves
for each row execute function public.create_favorite_notification();

create or replace function public.create_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  select author_id into owner_id from public.posts where id = new.post_id;
  if owner_id is not null and owner_id <> new.author_id then
    insert into public.notifications (user_id, type, actor_id, post_id, comment_id, title, body)
    select owner_id, 'comment', new.author_id, new.post_id, new.id, 'New comment',
      coalesce(profile.name, profile.email, 'Someone') || ' commented on your post'
    from public.profiles profile
    left join public.notification_preferences prefs on prefs.user_id = owner_id
    where profile.id = new.author_id
      and coalesce(prefs.in_app_enabled, true)
      and coalesce(prefs.activity_enabled, true);
  end if;

  if new.tagged_user_id is not null and new.tagged_user_id <> new.author_id then
    insert into public.notifications (user_id, type, actor_id, post_id, comment_id, title, body)
    select new.tagged_user_id, 'mention', new.author_id, new.post_id, new.id, 'New mention',
      coalesce(profile.name, profile.email, 'Someone') || ' mentioned you'
    from public.profiles profile
    left join public.notification_preferences prefs on prefs.user_id = new.tagged_user_id
    where profile.id = new.author_id
      and coalesce(prefs.in_app_enabled, true)
      and coalesce(prefs.activity_enabled, true);
  end if;

  return new;
end;
$$;

drop trigger if exists comments_create_activity_notifications on public.comments;
create trigger comments_create_activity_notifications
after insert on public.comments
for each row execute function public.create_comment_notification();
```

- [ ] **Step 6: Add RLS policies**

Append:

```sql
alter table public.chat_conversations enable row level security;
alter table public.chat_conversation_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Chat conversations visible to members" on public.chat_conversations;
create policy "Chat conversations visible to members"
on public.chat_conversations for select
to authenticated
using (
  exists (
    select 1 from public.chat_conversation_members member
    where member.conversation_id = id
      and member.user_id = auth.uid()
  )
);

drop policy if exists "Chat members visible to conversation members" on public.chat_conversation_members;
create policy "Chat members visible to conversation members"
on public.chat_conversation_members for select
to authenticated
using (
  exists (
    select 1 from public.chat_conversation_members viewer
    where viewer.conversation_id = conversation_id
      and viewer.user_id = auth.uid()
  )
);

drop policy if exists "Users update own chat member state" on public.chat_conversation_members;
create policy "Users update own chat member state"
on public.chat_conversation_members for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Chat messages visible to members" on public.chat_messages;
create policy "Chat messages visible to members"
on public.chat_messages for select
to authenticated
using (
  exists (
    select 1 from public.chat_conversation_members member
    where member.conversation_id = chat_messages.conversation_id
      and member.user_id = auth.uid()
      and member.status in ('active', 'pending')
      and (member.cleared_at is null or chat_messages.created_at > member.cleared_at)
  )
);

drop policy if exists "Users manage own notification preferences" on public.notification_preferences;
create policy "Users manage own notification preferences"
on public.notification_preferences for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users view own notifications" on public.notifications;
create policy "Users view own notifications"
on public.notifications for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications"
on public.notifications for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
```

- [ ] **Step 7: Add realtime publication commands**

Append:

```sql
alter publication supabase_realtime add table public.chat_conversations;
alter publication supabase_realtime add table public.chat_conversation_members;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.notifications;
```

If a table is already part of the publication in the target Supabase project, rerunning may report it already exists. Treat that as a deploy-time notice and keep the file idempotent elsewhere.

- [ ] **Step 8: Document run order**

Modify `supabase/README.md` to include:

```markdown
Run `supabase/chat.sql` after `supabase/schema.sql` and `supabase/follow.sql` to install direct chats, group chats, message requests, in-app notifications, and chat realtime tables.
```

- [ ] **Step 9: Verify SQL references locally**

Run:

```powershell
rg -n "chat_conversations|create_direct_conversation|send_chat_message|notification_preferences" supabase\chat.sql
```

Expected: matches for each table and RPC function.

## Task 2: Add chat Dart models and parsing tests

**Files:**

- Create: `apps/mobile/lib/src/features/chat/data/chat_models.dart`
- Test: `apps/mobile/test/chat_models_test.dart`

- [ ] **Step 1: Write model parsing tests**

Create `apps/mobile/test/chat_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';

void main() {
  test('ChatConversation parses direct request state and unread count', () {
    final conversation = ChatConversation.fromMap({
      'id': 'conversation-1',
      'type': 'direct',
      'title': null,
      'request_status': 'pending',
      'last_message_at': '2026-06-26T08:00:00.000Z',
      'unread_count': 3,
      'other_user_id': 'user-2',
      'other_user_name': 'Ming',
      'other_user_avatar_url': null,
      'last_message_body': 'hello',
    });

    expect(conversation.id, 'conversation-1');
    expect(conversation.type, ChatConversationType.direct);
    expect(conversation.requestStatus, ChatRequestStatus.pending);
    expect(conversation.isRequest, isTrue);
    expect(conversation.displayTitle, 'Ming');
    expect(conversation.unreadCount, 3);
  });

  test('ChatMessage trims body and detects current user ownership', () {
    final message = ChatMessage.fromMap({
      'id': 'message-1',
      'conversation_id': 'conversation-1',
      'sender_id': 'user-1',
      'body': '  hi  ',
      'created_at': '2026-06-26T08:01:00.000Z',
    }, currentUserId: 'user-1');

    expect(message.body, 'hi');
    expect(message.isMine, isTrue);
  });

  test('ChatNotification groups activity, system, and follower sections', () {
    final activity = ChatNotification.fromMap({
      'id': 'n1',
      'type': 'favorite',
      'title': 'Saved',
      'body': 'Someone saved your post',
      'created_at': '2026-06-26T08:02:00.000Z',
      'read_at': null,
    });
    final system = ChatNotification.fromMap({
      'id': 'n2',
      'type': 'system',
      'title': 'Post failed',
      'body': 'Please edit the post',
      'created_at': '2026-06-26T08:03:00.000Z',
      'read_at': '2026-06-26T08:04:00.000Z',
    });

    expect(activity.section, NotificationSection.activity);
    expect(activity.isUnread, isTrue);
    expect(system.section, NotificationSection.system);
    expect(system.isUnread, isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
cd apps\mobile
flutter test test\chat_models_test.dart
```

Expected: fail because `chat_models.dart` does not exist.

- [ ] **Step 3: Implement the models**

Create `apps/mobile/lib/src/features/chat/data/chat_models.dart`:

```dart
enum ChatConversationType { direct, group }

enum ChatRequestStatus { none, pending, accepted, blocked }

enum ChatMemberStatus { active, pending, left, removed }

enum NotificationSection { activity, system, followers, chat }

ChatConversationType _conversationTypeFrom(String? value) {
  return value == 'group'
      ? ChatConversationType.group
      : ChatConversationType.direct;
}

ChatRequestStatus _requestStatusFrom(String? value) {
  return ChatRequestStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ChatRequestStatus.none,
  );
}

ChatMemberStatus _memberStatusFrom(String? value) {
  return ChatMemberStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ChatMemberStatus.active,
  );
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _intFrom(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.isSelected = false,
  });

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final bool isSelected;

  factory ChatParticipant.fromMap(Map<String, dynamic> map) {
    final fallback = map['email']?.toString() ?? 'CyanZone user';
    return ChatParticipant(
      id: map['id'].toString(),
      name: (map['name']?.toString().trim().isNotEmpty ?? false)
          ? map['name'].toString()
          : fallback,
      email: map['email']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
    );
  }

  ChatParticipant copyWith({bool? isSelected}) {
    return ChatParticipant(
      id: id,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.requestStatus,
    required this.unreadCount,
    this.title,
    this.otherUserId,
    this.otherUserName,
    this.otherUserAvatarUrl,
    this.lastMessageBody,
    this.lastMessageAt,
  });

  final String id;
  final ChatConversationType type;
  final ChatRequestStatus requestStatus;
  final int unreadCount;
  final String? title;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserAvatarUrl;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;

  bool get isGroup => type == ChatConversationType.group;
  bool get isRequest => requestStatus == ChatRequestStatus.pending;

  String get displayTitle {
    if (isGroup) return title?.trim().isNotEmpty == true ? title! : 'Group chat';
    return otherUserName?.trim().isNotEmpty == true ? otherUserName! : 'CyanZone user';
  }

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: map['id'].toString(),
      type: _conversationTypeFrom(map['type']?.toString()),
      requestStatus: _requestStatusFrom(map['request_status']?.toString()),
      unreadCount: _intFrom(map['unread_count']),
      title: map['title']?.toString(),
      otherUserId: map['other_user_id']?.toString(),
      otherUserName: map['other_user_name']?.toString(),
      otherUserAvatarUrl: map['other_user_avatar_url']?.toString(),
      lastMessageBody: map['last_message_body']?.toString(),
      lastMessageAt: _dateTimeOrNull(map['last_message_at']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;

  factory ChatMessage.fromMap(
    Map<String, dynamic> map, {
    required String currentUserId,
  }) {
    final senderId = map['sender_id'].toString();
    return ChatMessage(
      id: map['id'].toString(),
      conversationId: map['conversation_id'].toString(),
      senderId: senderId,
      body: map['body'].toString().trim(),
      createdAt: _dateTimeOrNull(map['created_at']) ?? DateTime.now(),
      isMine: senderId == currentUserId,
    );
  }
}

class ChatNotification {
  const ChatNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  NotificationSection get section {
    if (type == 'system') return NotificationSection.system;
    if (type == 'new_follower') return NotificationSection.followers;
    if (type == 'chat_message') return NotificationSection.chat;
    return NotificationSection.activity;
  }

  factory ChatNotification.fromMap(Map<String, dynamic> map) {
    return ChatNotification(
      id: map['id'].toString(),
      type: map['type'].toString(),
      title: map['title']?.toString() ?? 'Notification',
      body: map['body']?.toString() ?? '',
      createdAt: _dateTimeOrNull(map['created_at']) ?? DateTime.now(),
      readAt: _dateTimeOrNull(map['read_at']),
    );
  }
}
```

- [ ] **Step 4: Run model tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_models_test.dart
```

Expected: all tests pass.

## Task 3: Add the chat repository

**Files:**

- Create: `apps/mobile/lib/src/features/chat/data/chat_repository.dart`
- Test: `apps/mobile/test/chat_repository_test.dart`

- [ ] **Step 1: Write repository constant tests**

Create `apps/mobile/test/chat_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/chat/data/chat_repository.dart';

void main() {
  test('ChatRepository exposes stable RPC names', () {
    expect(ChatRepository.createDirectConversationRpc, 'create_direct_conversation');
    expect(ChatRepository.createGroupConversationRpc, 'create_group_conversation');
    expect(ChatRepository.sendChatMessageRpc, 'send_chat_message');
    expect(ChatRepository.acceptMessageRequestRpc, 'accept_message_request');
    expect(ChatRepository.clearChatRpc, 'clear_chat');
    expect(ChatRepository.markConversationReadRpc, 'mark_conversation_read');
  });

  test('ChatRepository search normalizes whitespace', () {
    expect(ChatRepository.normalizeSearchTerm('  Ming  Jiang '), 'ming jiang');
    expect(ChatRepository.normalizeSearchTerm(''), '');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
cd apps\mobile
flutter test test\chat_repository_test.dart
```

Expected: fail because `chat_repository.dart` does not exist.

- [ ] **Step 3: Implement repository API**

Create `apps/mobile/lib/src/features/chat/data/chat_repository.dart`:

```dart
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_models.dart';

class ChatRepository {
  ChatRepository(this._client);

  static const createDirectConversationRpc = 'create_direct_conversation';
  static const createGroupConversationRpc = 'create_group_conversation';
  static const sendChatMessageRpc = 'send_chat_message';
  static const acceptMessageRequestRpc = 'accept_message_request';
  static const clearChatRpc = 'clear_chat';
  static const markConversationReadRpc = 'mark_conversation_read';

  static const conversationSelectColumns = '''
    id,
    type,
    title,
    request_status,
    last_message_at,
    requested_by,
    requested_to,
    chat_messages(body, created_at, sender_id),
    chat_conversation_members(user_id, status, last_read_at, profiles(id, name, email, avatar_url))
  ''';

  final SupabaseClient _client;

  String get _currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AuthException('You need to sign in before using chat.');
    }
    return id;
  }

  static String normalizeSearchTerm(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String> createDirectConversation(String targetUserId) async {
    final response = await _client.rpc(
      createDirectConversationRpc,
      params: {'target_user_id': targetUserId},
    );
    return response.toString();
  }

  Future<String> createGroupConversation({
    required String? title,
    required List<String> memberIds,
  }) async {
    final response = await _client.rpc(
      createGroupConversationRpc,
      params: {
        'title': title ?? '',
        'member_ids': memberIds,
      },
    );
    return response.toString();
  }

  Future<String> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final response = await _client.rpc(
      sendChatMessageRpc,
      params: {
        'conversation_id': conversationId,
        'body': body,
      },
    );
    return response.toString();
  }

  Future<void> acceptMessageRequest(String conversationId) async {
    await _client.rpc(
      acceptMessageRequestRpc,
      params: {'conversation_id': conversationId},
    );
  }

  Future<void> clearChat(String conversationId) async {
    await _client.rpc(clearChatRpc, params: {'conversation_id': conversationId});
  }

  Future<void> markConversationRead(String conversationId) async {
    await _client.rpc(
      markConversationReadRpc,
      params: {'conversation_id': conversationId},
    );
  }

  Future<List<ChatConversation>> fetchConversations() async {
    final rows = await _client
        .from('chat_conversations')
        .select(conversationSelectColumns)
        .order('last_message_at', ascending: false, nullsFirst: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(_conversationFromJoinedRow)
        .where((conversation) => !conversation.isRequest)
        .toList();
  }

  Future<List<ChatConversation>> fetchMessageRequests() async {
    final rows = await _client
        .from('chat_conversations')
        .select(conversationSelectColumns)
        .eq('type', 'direct')
        .eq('request_status', 'pending')
        .order('last_message_at', ascending: false, nullsFirst: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(_conversationFromJoinedRow)
        .where((conversation) => conversation.isRequest)
        .toList();
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    final userId = _currentUserId;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => ChatMessage.fromMap(row, currentUserId: userId))
        .toList();
  }

  Future<List<ChatNotification>> fetchNotifications(NotificationSection section) async {
    var query = _client.from('notifications').select().order('created_at', ascending: false);
    if (section == NotificationSection.activity) {
      query = query.inFilter('type', ['like', 'favorite', 'comment', 'mention']);
    } else if (section == NotificationSection.system) {
      query = query.eq('type', 'system');
    } else if (section == NotificationSection.followers) {
      final cutoff = DateTime.now().subtract(const Duration(days: 30)).toUtc().toIso8601String();
      query = query.eq('type', 'new_follower').gte('created_at', cutoff);
    } else {
      query = query.eq('type', 'chat_message');
    }
    final rows = await query;
    return rows
        .cast<Map<String, dynamic>>()
        .map(ChatNotification.fromMap)
        .toList();
  }

  Future<int> fetchUnreadChatCount() async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('type', 'chat_message')
        .filter('read_at', 'is', null);
    return rows.length;
  }

  Future<Map<NotificationSection, int>> fetchUnreadNotificationCounts() async {
    final rows = await _client
        .from('notifications')
        .select('type')
        .filter('read_at', 'is', null);
    final counts = {
      NotificationSection.activity: 0,
      NotificationSection.system: 0,
      NotificationSection.followers: 0,
      NotificationSection.chat: 0,
    };
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final notification = ChatNotification.fromMap({
        'id': 'count',
        'type': row['type'],
        'title': '',
        'body': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      counts[notification.section] = (counts[notification.section] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<ChatParticipant>> searchPeopleAndChats(String term) async {
    final normalized = normalizeSearchTerm(term);
    if (normalized.isEmpty) return fetchSuggestedGroupMembers();
    final rows = await _client
        .from('profiles')
        .select('id, name, email, avatar_url')
        .or('name.ilike.%$normalized%,email.ilike.%$normalized%')
        .limit(30);
    return rows
        .cast<Map<String, dynamic>>()
        .where((row) => row['id'] != _currentUserId)
        .map(ChatParticipant.fromMap)
        .toList();
  }

  Future<List<ChatParticipant>> fetchSuggestedGroupMembers() async {
    final currentUserId = _currentUserId;
    final followerRows = await _client
        .from('follows')
        .select('profiles!follows_follower_id_fkey(id, name, email, avatar_url)')
        .eq('following_id', currentUserId)
        .limit(20);
    final followingRows = await _client
        .from('follows')
        .select('profiles!follows_following_id_fkey(id, name, email, avatar_url)')
        .eq('follower_id', currentUserId)
        .limit(20);

    final byId = <String, ChatParticipant>{};
    for (final row in followerRows.cast<Map<String, dynamic>>()) {
      final profile = row['profiles'];
      if (profile is Map<String, dynamic>) {
        final participant = ChatParticipant.fromMap(profile);
        byId[participant.id] = participant;
      }
    }
    for (final row in followingRows.cast<Map<String, dynamic>>()) {
      final profile = row['profiles'];
      if (profile is Map<String, dynamic>) {
        final participant = ChatParticipant.fromMap(profile);
        byId[participant.id] = participant;
      }
    }
    return byId.values.toList();
  }

  RealtimeChannel subscribeToChatChanges({
    required String channelName,
    required void Function() onChange,
  }) {
    final channel = _client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  ChatConversation _conversationFromJoinedRow(Map<String, dynamic> row) {
    final members = (row['chat_conversation_members'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final otherMember = members.firstWhere(
      (member) => member['user_id'] != _currentUserId,
      orElse: () => const {},
    );
    final profile = otherMember['profiles'];
    final messageRows = (row['chat_messages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((left, right) {
        return (right['created_at'] ?? '').toString().compareTo((left['created_at'] ?? '').toString());
      });
    final latestMessage = messageRows.isEmpty ? null : messageRows.first;

    return ChatConversation.fromMap({
      'id': row['id'],
      'type': row['type'],
      'title': row['title'],
      'request_status': row['request_status'],
      'last_message_at': row['last_message_at'],
      'unread_count': 0,
      'other_user_id': profile is Map<String, dynamic> ? profile['id'] : null,
      'other_user_name': profile is Map<String, dynamic> ? profile['name'] ?? profile['email'] : null,
      'other_user_avatar_url': profile is Map<String, dynamic> ? profile['avatar_url'] : null,
      'last_message_body': latestMessage?['body'],
    });
  }
}
```

- [ ] **Step 4: Run repository tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_repository_test.dart
```

Expected: all tests pass.

## Task 4: Add reusable chat widgets

**Files:**

- Create: `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart`
- Test: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Write widget tests for badge and message bubble**

Create the first section of `apps/mobile/test/chat_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cyanzone_mobile/src/features/chat/presentation/chat_widgets.dart';

void main() {
  testWidgets('UnreadBadge hides zero and shows capped count', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 0)));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 120)));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('ChatMessageBubble aligns current user messages to the right', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageBubble(body: 'Hello', isMine: true),
        ),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
    final align = tester.widget<Align>(find.byType(Align).first);
    expect(align.alignment, Alignment.centerRight);
  });
}
```

- [ ] **Step 2: Run widget tests to verify they fail**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: fail because `chat_widgets.dart` does not exist.

- [ ] **Step 3: Implement reusable widgets**

Create `apps/mobile/lib/src/features/chat/presentation/chat_widgets.dart` with:

```dart
import 'package:flutter/material.dart';

import '../data/chat_models.dart';

const chatNavy = Color(0xFF0B1F3E);
const chatCyan = Color(0xFF4490AD);
const chatBackground = Color(0xFFFAFCFC);
const chatInput = Color(0xFFF1F5F9);
const chatBorder = Color(0xFFE2E8F0);
const chatDanger = Color(0xFFE11D48);

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: chatDanger,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 46,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: chatCyan.withValues(alpha: 0.14),
      foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
      child: Text(
        initial,
        style: const TextStyle(
          color: chatNavy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: chatInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.body,
    required this.isMine,
  });

  final String body;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.74,
        ),
        decoration: BoxDecoration(
          color: isMine ? chatNavy : chatInput,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 5),
            bottomRight: Radius.circular(isMine ? 5 : 18),
          ),
        ),
        child: Text(
          body,
          style: TextStyle(
            color: isMine ? Colors.white : chatNavy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: ChatAvatar(
        name: conversation.displayTitle,
        avatarUrl: conversation.otherUserAvatarUrl,
      ),
      title: Text(
        conversation.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: chatNavy,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        conversation.lastMessageBody ?? (conversation.isRequest ? 'Message request' : 'Start chatting'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: UnreadBadge(count: conversation.unreadCount),
    );
  }
}

class NotificationEntryCard extends StatelessWidget {
  const NotificationEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 178,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chatBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0B1F3E),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: chatCyan),
                const Spacer(),
                UnreadBadge(count: count),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: chatNavy, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run widget tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: all tests pass.

## Task 5: Build the Chats home tab

**Files:**

- Create: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add a chat page smoke test**

Append to `apps/mobile/test/chat_widgets_test.dart`:

```dart
testWidgets('ChatPage renders title and search field with injected loader', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatPage(
        loadConversations: () async => const [],
        loadRequests: () async => const [],
        loadCounts: () async => const {
          NotificationSection.activity: 0,
          NotificationSection.system: 0,
          NotificationSection.followers: 0,
          NotificationSection.chat: 0,
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Chats'), findsOneWidget);
  expect(find.text('Search followers, following, chats'), findsOneWidget);
  expect(find.text('No chats yet'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: fail because `ChatPage` is not defined or imported.

- [ ] **Step 3: Implement `ChatPage`**

Create `apps/mobile/lib/src/features/chat/presentation/chat_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_room_page.dart';
import 'chat_widgets.dart';
import 'create_group_chat_page.dart';
import 'notification_sections_page.dart';

typedef ConversationLoader = Future<List<ChatConversation>> Function();
typedef CountLoader = Future<Map<NotificationSection, int>> Function();

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.loadConversations,
    this.loadRequests,
    this.loadCounts,
  });

  final ConversationLoader? loadConversations;
  final ConversationLoader? loadRequests;
  final CountLoader? loadCounts;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _repository;
  late Future<_ChatHomeState> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(Supabase.instance.client);
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ChatHomeState> _load() async {
    final conversations = await (widget.loadConversations?.call() ?? _repository.fetchConversations());
    final requests = await (widget.loadRequests?.call() ?? _repository.fetchMessageRequests());
    final counts = await (widget.loadCounts?.call() ?? _repository.fetchUnreadNotificationCounts());
    return _ChatHomeState(conversations: conversations, requests: requests, counts: counts);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  List<ChatConversation> _filtered(List<ChatConversation> conversations) {
    final normalized = ChatRepository.normalizeSearchTerm(_query);
    if (normalized.isEmpty) return conversations;
    return conversations.where((conversation) {
      return conversation.displayTitle.toLowerCase().contains(normalized) ||
          (conversation.lastMessageBody ?? '').toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Create group chat',
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupChatPage()),
              );
              if (mounted) _refresh();
            },
          ),
        ],
      ),
      body: FutureBuilder<_ChatHomeState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ChatErrorState(onRetry: _refresh);
          }
          final state = snapshot.data ?? const _ChatHomeState();
          final conversations = _filtered(state.conversations);
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                ChatSearchField(
                  controller: _searchController,
                  hintText: 'Search followers, following, chats',
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 142,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      NotificationEntryCard(
                        title: 'Activity Messages',
                        subtitle: 'Likes, favorites, comments, mentions',
                        icon: Icons.bolt_rounded,
                        count: state.counts[NotificationSection.activity] ?? 0,
                        onTap: () => _openNotifications(NotificationSection.activity),
                      ),
                      const SizedBox(width: 12),
                      NotificationEntryCard(
                        title: 'System Notifications',
                        subtitle: 'Post status, reasons, next actions',
                        icon: Icons.campaign_rounded,
                        count: state.counts[NotificationSection.system] ?? 0,
                        onTap: () => _openNotifications(NotificationSection.system),
                      ),
                      const SizedBox(width: 12),
                      NotificationEntryCard(
                        title: 'New Followers',
                        subtitle: 'Followers from the last 30 days',
                        icon: Icons.person_add_alt_1_rounded,
                        count: state.counts[NotificationSection.followers] ?? 0,
                        onTap: () => _openNotifications(NotificationSection.followers),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Recent chats'),
                if (conversations.isEmpty)
                  const _EmptyChatState()
                else
                  ...conversations.map(
                    (conversation) => ConversationTile(
                      conversation: conversation,
                      onTap: () => _openRoom(conversation),
                    ),
                  ),
                if (state.requests.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Message requests'),
                  ...state.requests.map(
                    (conversation) => ConversationTile(
                      conversation: conversation,
                      onTap: () => _openRoom(conversation),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openNotifications(NotificationSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSectionsPage(initialSection: section),
      ),
    );
  }

  Future<void> _openRoom(ChatConversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(conversation: conversation),
      ),
    );
    if (mounted) _refresh();
  }
}

class _ChatHomeState {
  const _ChatHomeState({
    this.conversations = const [],
    this.requests = const [],
    this.counts = const {},
  });

  final List<ChatConversation> conversations;
  final List<ChatConversation> requests;
  final Map<NotificationSection, int> counts;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: chatNavy,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: chatBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, color: chatCyan, size: 38),
          SizedBox(height: 10),
          Text('No chats yet', style: TextStyle(color: chatNavy, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text('Search followers/following or create a group to begin.'),
        ],
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load chats.'),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Add imports to the test**

Modify `apps/mobile/test/chat_widgets_test.dart` imports:

```dart
import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_page.dart';
```

- [ ] **Step 5: Run chat page tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: all tests pass after the route pages from Tasks 6-8 exist. If imports fail at this point, pause Task 5 and complete Tasks 6-8 before rerunning this test.

## Task 6: Build conversation room and clear-chat details

**Files:**

- Create: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Create: `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add room send and clear tests**

Append:

```dart
testWidgets('ChatRoomPage keeps text when send fails', (tester) async {
  final conversation = ChatConversation.fromMap({
    'id': 'c1',
    'type': 'direct',
    'request_status': 'accepted',
    'unread_count': 0,
    'other_user_name': 'Ming',
  });

  await tester.pumpWidget(
    MaterialApp(
      home: ChatRoomPage(
        conversation: conversation,
        loadMessages: () async => const [],
        sendMessage: (_, __) async => throw Exception('network'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'hello');
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pump();

  expect(find.text('hello'), findsOneWidget);
});
```

- [ ] **Step 2: Implement `ChatDetailsPage`**

Create `apps/mobile/lib/src/features/chat/presentation/chat_details_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage({
    super.key,
    required this.conversation,
    this.clearChat,
  });

  final ChatConversation conversation;
  final Future<void> Function(String conversationId)? clearChat;

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _isClearing = false;

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This only clears the chat for you. Other people will still keep their messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      final action = widget.clearChat ?? ChatRepository(Supabase.instance.client).clearChat;
      await action(widget.conversation.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear chat. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(title: Text(widget.conversation.displayTitle)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ChatAvatar(name: widget.conversation.displayTitle, avatarUrl: widget.conversation.otherUserAvatarUrl, size: 72),
          const SizedBox(height: 18),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            tileColor: Colors.white,
            leading: const Icon(Icons.cleaning_services_rounded, color: chatDanger),
            title: const Text('Clear chat', style: TextStyle(color: chatDanger, fontWeight: FontWeight.w800)),
            subtitle: const Text('Only clears messages for your account'),
            trailing: _isClearing ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: _isClearing ? null : _clear,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Implement `ChatRoomPage`**

Create `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_details_page.dart';
import 'chat_widgets.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    super.key,
    required this.conversation,
    this.loadMessages,
    this.sendMessage,
  });

  final ChatConversation conversation;
  final Future<List<ChatMessage>> Function()? loadMessages;
  final Future<void> Function(String conversationId, String body)? sendMessage;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late final ChatRepository _repository;
  late Future<List<ChatMessage>> _messagesFuture;
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(Supabase.instance.client);
    _messagesFuture = widget.loadMessages?.call() ?? _repository.fetchMessages(widget.conversation.id);
    _repository.markConversationRead(widget.conversation.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final action = widget.sendMessage ?? (String id, String text) async {
        await _repository.sendMessage(conversationId: id, body: text);
      };
      await action(widget.conversation.id, body);
      _controller.clear();
      setState(() {
        _messagesFuture = widget.loadMessages?.call() ?? _repository.fetchMessages(widget.conversation.id);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().contains('recipient must accept') ? 'The recipient must accept your request before more messages can be sent.' : 'Could not send message. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatDetailsPage(conversation: widget.conversation)),
          ),
          child: Row(
            children: [
              ChatAvatar(name: widget.conversation.displayTitle, avatarUrl: widget.conversation.otherUserAvatarUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.conversation.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<ChatMessage>>(
              future: _messagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Say hi with a kind message.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return ChatMessageBubble(body: message.body, isMine: message.isMine);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        filled: true,
                        fillColor: chatInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _send,
                    icon: _isSending
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run room/widget tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: all tests pass.

## Task 7: Build group creation

**Files:**

- Create: `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add group picker test**

Append:

```dart
testWidgets('CreateGroupChatPage enables create after selecting a person', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CreateGroupChatPage(
        loadSuggested: () async => const [
          ChatParticipant(id: 'u2', name: 'Ming'),
        ],
        createGroup: (_, __) async => 'c1',
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create')).onPressed, isNull);
  await tester.tap(find.text('Ming'));
  await tester.pump();
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create')).onPressed, isNotNull);
});
```

- [ ] **Step 2: Implement `CreateGroupChatPage`**

Create `apps/mobile/lib/src/features/chat/presentation/create_group_chat_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

class CreateGroupChatPage extends StatefulWidget {
  const CreateGroupChatPage({
    super.key,
    this.loadSuggested,
    this.searchPeople,
    this.createGroup,
  });

  final Future<List<ChatParticipant>> Function()? loadSuggested;
  final Future<List<ChatParticipant>> Function(String term)? searchPeople;
  final Future<String> Function(String? title, List<String> memberIds)? createGroup;

  @override
  State<CreateGroupChatPage> createState() => _CreateGroupChatPageState();
}

class _CreateGroupChatPageState extends State<CreateGroupChatPage> {
  late final ChatRepository _repository;
  late Future<List<ChatParticipant>> _peopleFuture;
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(Supabase.instance.client);
    _peopleFuture = widget.loadSuggested?.call() ?? _repository.fetchSuggestedGroupMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _peopleFuture = widget.loadSuggested?.call() ?? _repository.fetchSuggestedGroupMembers();
      } else {
        _peopleFuture = widget.searchPeople?.call(value) ?? _repository.searchPeopleAndChats(value);
      }
    });
  }

  void _toggle(ChatParticipant person) {
    setState(() {
      if (_selectedIds.contains(person.id)) {
        _selectedIds.remove(person.id);
      } else {
        _selectedIds.add(person.id);
      }
    });
  }

  Future<void> _create() async {
    if (_selectedIds.isEmpty || _isCreating) return;
    setState(() => _isCreating = true);
    try {
      final action = widget.createGroup ?? _repository.createGroupConversation;
      final id = await action(_titleController.text.trim().isEmpty ? null : _titleController.text.trim(), _selectedIds.toList());
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().contains('Only followers') ? 'Only followers, following, or accepted recent chats can be added.' : 'Could not create group. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(title: const Text('Create group chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: chatBorder)),
                  ),
                ),
                const SizedBox(height: 10),
                ChatSearchField(controller: _searchController, hintText: 'Search by name', onChanged: _search),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChatParticipant>>(
              future: _peopleFuture,
              builder: (context, snapshot) {
                final people = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (people.isEmpty) {
                  return const Center(child: Text('No suggested people yet.'));
                }
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                      child: Text(
                        _searchController.text.trim().isEmpty ? 'Suggested' : 'Search results',
                        style: const TextStyle(color: chatNavy, fontWeight: FontWeight.w900),
                      ),
                    ),
                    ...people.map((person) {
                      final selected = _selectedIds.contains(person.id);
                      return ListTile(
                        onTap: () => _toggle(person),
                        leading: ChatAvatar(name: person.name, avatarUrl: person.avatarUrl),
                        title: Text(person.name),
                        subtitle: person.email == null ? null : Text(person.email!),
                        trailing: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? chatCyan : chatBorder),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _selectedIds.isEmpty || _isCreating ? null : _create,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: Text(_isCreating ? 'Creating...' : 'Create'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run group picker tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: all tests pass.

## Task 8: Build notification sections

**Files:**

- Create: `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`
- Modify: `apps/mobile/test/chat_widgets_test.dart`

- [ ] **Step 1: Add notification section smoke test**

Append:

```dart
testWidgets('NotificationSectionsPage shows selected section title', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NotificationSectionsPage(
        initialSection: NotificationSection.system,
        loadNotifications: (_) async => const [],
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('System Notifications'), findsOneWidget);
  expect(find.text('No notifications here yet.'), findsOneWidget);
});
```

- [ ] **Step 2: Implement `NotificationSectionsPage`**

Create `apps/mobile/lib/src/features/chat/presentation/notification_sections_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

class NotificationSectionsPage extends StatefulWidget {
  const NotificationSectionsPage({
    super.key,
    required this.initialSection,
    this.loadNotifications,
  });

  final NotificationSection initialSection;
  final Future<List<ChatNotification>> Function(NotificationSection section)? loadNotifications;

  @override
  State<NotificationSectionsPage> createState() => _NotificationSectionsPageState();
}

class _NotificationSectionsPageState extends State<NotificationSectionsPage> {
  late NotificationSection _section;
  late final ChatRepository _repository;
  late Future<List<ChatNotification>> _future;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _repository = ChatRepository(Supabase.instance.client);
    _future = _load();
  }

  Future<List<ChatNotification>> _load() {
    return widget.loadNotifications?.call(_section) ?? _repository.fetchNotifications(_section);
  }

  void _switch(NotificationSection section) {
    setState(() {
      _section = section;
      _future = _load();
    });
  }

  String get _title {
    switch (_section) {
      case NotificationSection.activity:
        return 'Activity Messages';
      case NotificationSection.system:
        return 'System Notifications';
      case NotificationSection.followers:
        return 'New Followers';
      case NotificationSection.chat:
        return 'Chat Messages';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackground,
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _SectionChip(label: 'Activity', selected: _section == NotificationSection.activity, onTap: () => _switch(NotificationSection.activity)),
                _SectionChip(label: 'System', selected: _section == NotificationSection.system, onTap: () => _switch(NotificationSection.system)),
                _SectionChip(label: 'Followers', selected: _section == NotificationSection.followers, onTap: () => _switch(NotificationSection.followers)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ChatNotification>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return const Center(child: Text('No notifications here yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      leading: Icon(notification.isUnread ? Icons.circle_notifications_rounded : Icons.notifications_none_rounded, color: notification.isUnread ? chatDanger : chatCyan),
                      title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(notification.body),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
```

- [ ] **Step 3: Run notification widget tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_widgets_test.dart
```

Expected: all tests pass.

## Task 9: Wire chat into shell and profile message action

**Files:**

- Modify: `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`

- [ ] **Step 1: Replace the temporary shell Chats page**

In `apps/mobile/lib/src/features/shell/presentation/main_shell.dart`, add:

```dart
import '../../chat/presentation/chat_page.dart';
```

Replace the page at the Chats tab around the existing `title: 'Chats'` coming-soon page with:

```dart
const ChatPage(),
```

- [ ] **Step 2: Add chat badge support to the nav bar**

Change `_CyanZoneNavBar` constructor to accept:

```dart
const _CyanZoneNavBar({
  required this.selectedIndex,
  required this.onTap,
  this.chatBadgeCount = 0,
});

final int selectedIndex;
final ValueChanged<int> onTap;
final int chatBadgeCount;
```

Wrap the Chats icon in a `Stack`:

```dart
Stack(
  clipBehavior: Clip.none,
  children: [
    const Icon(Icons.chat_bubble_outline_rounded),
    if (chatBadgeCount > 0)
      Positioned(
        right: -8,
        top: -6,
        child: UnreadBadge(count: chatBadgeCount),
      ),
  ],
)
```

Add the chat widget import:

```dart
import '../../chat/presentation/chat_widgets.dart';
```

- [ ] **Step 3: Load shell badge count**

In `_MainShellState`, add:

```dart
int _chatBadgeCount = 0;
late final ChatRepository _chatRepository;
```

Initialize after Supabase is available:

```dart
_chatRepository = ChatRepository(Supabase.instance.client);
_refreshChatBadge();
```

Add:

```dart
Future<void> _refreshChatBadge() async {
  try {
    final count = await _chatRepository.fetchUnreadChatCount();
    if (mounted) setState(() => _chatBadgeCount = count);
  } catch (_) {
    if (mounted) setState(() => _chatBadgeCount = 0);
  }
}
```

Pass it to `_CyanZoneNavBar`:

```dart
chatBadgeCount: _chatBadgeCount,
```

Add:

```dart
import '../../chat/data/chat_repository.dart';
```

- [ ] **Step 4: Route profile Message button**

In `apps/mobile/lib/src/features/profile/presentation/profile_page.dart`, find the existing Message button coming-soon action. Replace its action with:

```dart
final repository = ChatRepository(Supabase.instance.client);
final conversationId = await repository.createDirectConversation(profile.id);
if (!context.mounted) return;
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ChatRoomPage(
      conversation: ChatConversation.fromMap({
        'id': conversationId,
        'type': 'direct',
        'request_status': profile.isFollowing ? 'accepted' : 'pending',
        'unread_count': 0,
        'other_user_id': profile.id,
        'other_user_name': profile.name ?? profile.email,
        'other_user_avatar_url': profile.avatarUrl,
      }),
    ),
  ),
);
```

Add imports:

```dart
import '../../chat/data/chat_models.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_room_page.dart';
```

- [ ] **Step 5: Run analyzer for wiring issues**

Run:

```powershell
cd apps\mobile
flutter analyze
```

Expected: no new chat-related analyzer errors.

## Task 10: Realtime refresh and notification preferences

**Files:**

- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_page.dart`
- Modify: `apps/mobile/lib/src/features/chat/presentation/chat_room_page.dart`
- Modify: `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`

- [ ] **Step 1: Subscribe chat home to realtime changes**

In `_ChatPageState`, add:

```dart
RealtimeChannel? _channel;
```

After `_repository` initialization:

```dart
_channel = _repository.subscribeToChatChanges(
  channelName: 'chat-home',
  onChange: _refresh,
);
```

In `dispose`:

```dart
final channel = _channel;
if (channel != null) {
  _repository.unsubscribe(channel);
}
```

- [ ] **Step 2: Subscribe room to message changes**

In `_ChatRoomPageState`, add:

```dart
RealtimeChannel? _channel;
```

After `_messagesFuture` initialization:

```dart
_channel = _repository.subscribeToChatChanges(
  channelName: 'chat-room-${widget.conversation.id}',
  onChange: () {
    if (mounted) {
      setState(() {
        _messagesFuture = widget.loadMessages?.call() ?? _repository.fetchMessages(widget.conversation.id);
      });
    }
  },
);
```

In `dispose`:

```dart
final channel = _channel;
if (channel != null) {
  _repository.unsubscribe(channel);
}
```

- [ ] **Step 3: Add in-app notification switches to settings**

In `apps/mobile/lib/src/features/profile/presentation/settings_page.dart`, add a simple section titled `In-app notifications` with switches for:

```dart
in_app_enabled
chat_enabled
activity_enabled
system_enabled
followers_enabled
```

Read and write the row through `notification_preferences`. The switches affect in-app rows and badges only. Label the section text:

```dart
These settings control CyanZone in-app badges and notification lists. Phone push notifications are not enabled yet.
```

- [ ] **Step 4: Run analyzer**

Run:

```powershell
cd apps\mobile
flutter analyze
```

Expected: no new chat/settings analyzer errors.

## Task 11: Final verification pass

**Files:**

- All files touched above.

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
cd apps\mobile
dart format lib\src\features\chat lib\src\features\shell\presentation\main_shell.dart lib\src\features\profile\presentation\profile_page.dart lib\src\features\profile\presentation\settings_page.dart test\chat_models_test.dart test\chat_repository_test.dart test\chat_widgets_test.dart
```

Expected: formatter completes and lists formatted files or no changed files.

- [ ] **Step 2: Run focused chat tests**

Run:

```powershell
cd apps\mobile
flutter test test\chat_models_test.dart test\chat_repository_test.dart test\chat_widgets_test.dart
```

Expected: all focused chat tests pass.

- [ ] **Step 3: Run full mobile test suite**

Run:

```powershell
cd apps\mobile
flutter test
```

Expected: all mobile tests pass. If unrelated pre-existing failures appear, capture exact failing test names and rerun the focused chat tests to prove chat scope.

- [ ] **Step 4: Run analyzer**

Run:

```powershell
cd apps\mobile
flutter analyze
```

Expected: no new analyzer issues from chat files.

- [ ] **Step 5: Check docs/spec references**

Run:

```powershell
rg -n "Perspective|PERSPECTIVE_API_KEY|message reporting|Firebase Cloud Messaging handles" Project_Overview.md docs apps supabase
```

Expected: no stale claim that chat uses Perspective, message reporting, or Firebase Cloud Messaging in this phase.

- [ ] **Step 6: Review git diff**

Run:

```powershell
git diff -- docs\superpowers\specs\2026-06-26-chatting-feature-design.md docs\superpowers\plans\2026-06-26-chatting-feature.md supabase\chat.sql supabase\README.md apps\mobile\lib\src\features\chat apps\mobile\lib\src\features\shell\presentation\main_shell.dart apps\mobile\lib\src\features\profile\presentation\profile_page.dart apps\mobile\lib\src\features\profile\presentation\settings_page.dart apps\mobile\test\chat_models_test.dart apps\mobile\test\chat_repository_test.dart apps\mobile\test\chat_widgets_test.dart
```

Expected: diff contains only chat-related schema, UI, repository, tests, docs, and explicit shell/profile/settings wiring.

## Plan self-review

- Spec coverage: Tasks 1-11 cover Supabase schema, RLS, write functions, direct chats, group chats, stranger 3-message cap, current-user-only clear chat, in-app notifications, red badges, notification preferences, search, recent chats excluding requests, and no chat moderation.
- Placeholder scan: No unfinished implementation markers are intentionally used in the plan.
- Type consistency: RPC names, Dart class names, enum names, and file paths are consistent across tasks.
- Scope note: External FCM/APNs push and AI moderation are intentionally excluded from the build tasks.
