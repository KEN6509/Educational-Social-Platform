create extension if not exists pgcrypto;

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct', 'group')),
  title text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid references public.profiles(id) on delete cascade,
  requested_to uuid references public.profiles(id) on delete cascade,
  request_status text not null default 'none'
    check (request_status in ('none', 'pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz,
  check (
    (type = 'direct' and requested_by is not null and requested_to is not null and requested_by <> requested_to)
    or (type = 'group')
  )
);

alter table public.chat_conversations
drop constraint if exists chat_conversations_requested_by_fkey;

alter table public.chat_conversations
add constraint chat_conversations_requested_by_fkey
foreign key (requested_by) references public.profiles(id) on delete cascade;

alter table public.chat_conversations
drop constraint if exists chat_conversations_requested_to_fkey;

alter table public.chat_conversations
add constraint chat_conversations_requested_to_fkey
foreign key (requested_to) references public.profiles(id) on delete cascade;

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
  body text not null check (char_length(btrim(body)) between 1 and 10000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_for uuid[] not null default '{}'::uuid[]
);

alter table public.chat_messages
drop constraint if exists chat_messages_body_check;

alter table public.chat_messages
add constraint chat_messages_body_check
check (char_length(btrim(body)) between 1 and 10000);

alter table public.chat_messages add column if not exists deleted_for uuid[] not null default '{}'::uuid[];

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
  type text not null check (
    type in (
      'chat_message',
      'like',
      'favorite',
      'comment',
      'comment_reply',
      'comment_like',
      'mention',
      'system',
      'new_follower'
    )
  ),
  actor_id uuid references public.profiles(id) on delete set null,
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  conversation_id uuid references public.chat_conversations(id) on delete cascade,
  message_id uuid references public.chat_messages(id) on delete cascade,
  title text,
  body text,
  action_type text,
  action_payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notification_preferences add column if not exists in_app_enabled boolean not null default true;

alter table public.notification_preferences add column if not exists chat_enabled boolean not null default true;

alter table public.notification_preferences add column if not exists activity_enabled boolean not null default true;

alter table public.notification_preferences add column if not exists system_enabled boolean not null default true;

alter table public.notification_preferences add column if not exists followers_enabled boolean not null default true;

alter table public.notification_preferences add column if not exists updated_at timestamptz not null default now();

alter table public.notifications add column if not exists actor_id uuid references public.profiles(id) on delete set null;

alter table public.notifications add column if not exists post_id uuid references public.posts(id) on delete cascade;

alter table public.notifications add column if not exists comment_id uuid references public.comments(id) on delete cascade;

alter table public.notifications add column if not exists conversation_id uuid references public.chat_conversations(id) on delete cascade;

alter table public.notifications add column if not exists message_id uuid references public.chat_messages(id) on delete cascade;

alter table public.notifications add column if not exists title text;

alter table public.notifications add column if not exists body text;

alter table public.notifications add column if not exists action_type text;

alter table public.notifications add column if not exists action_payload jsonb not null default '{}'::jsonb;

alter table public.notifications add column if not exists read_at timestamptz;

alter table public.notifications
drop constraint if exists notifications_type_check;

alter table public.notifications
add constraint notifications_type_check
check (type in (
  'chat_message',
  'like',
  'favorite',
  'comment',
  'comment_reply',
  'comment_like',
  'mention',
  'system',
  'new_follower'
));

alter table public.comments
add column if not exists tagged_user_id uuid references public.profiles(id) on delete set null;

create unique index if not exists chat_conversations_direct_pair_uidx
on public.chat_conversations (
  least(requested_by, requested_to),
  greatest(requested_by, requested_to)
)
where type = 'direct'
  and requested_by is not null
  and requested_to is not null;

create index if not exists chat_conversation_members_user_status_idx
on public.chat_conversation_members (user_id, status, conversation_id);

create index if not exists chat_conversation_members_conversation_status_idx
on public.chat_conversation_members (conversation_id, status, user_id);

create index if not exists chat_messages_conversation_created_idx
on public.chat_messages (conversation_id, created_at desc);

create index if not exists chat_messages_deleted_for_gin_idx
on public.chat_messages using gin (deleted_for);

create index if not exists notifications_user_created_idx
on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_unread_idx
on public.notifications (user_id, created_at desc)
where read_at is null;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_chat_conversations_updated_at on public.chat_conversations;
create trigger touch_chat_conversations_updated_at
before update on public.chat_conversations
for each row execute function public.touch_updated_at();

drop trigger if exists touch_notification_preferences_updated_at on public.notification_preferences;
create trigger touch_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function public.touch_updated_at();

create or replace function public.chat_users_have_relationship(left_user uuid, right_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select left_user is not null
    and right_user is not null
    and left_user <> right_user
    and (
      exists (
        select 1
        from public.follows f
        where (f.follower_id = left_user and f.following_id = right_user)
           or (f.follower_id = right_user and f.following_id = left_user)
      )
      or exists (
        select 1
        from public.parent_child_links pcl
        where pcl.status = 'active'
          and (
            (pcl.parent_id = left_user and pcl.child_id = right_user)
            or (pcl.parent_id = right_user and pcl.child_id = left_user)
          )
      )
    );
$$;

create or replace function public.chat_can_add_group_member(owner_id uuid, candidate_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.chat_users_have_relationship(owner_id, candidate_id)
    or exists (
      select 1
      from public.chat_conversations c
      join public.chat_conversation_members owner_member
        on owner_member.conversation_id = c.id
       and owner_member.user_id = owner_id
       and owner_member.status = 'active'
      join public.chat_conversation_members candidate_member
        on candidate_member.conversation_id = c.id
       and candidate_member.user_id = candidate_id
       and candidate_member.status = 'active'
      where c.type = 'direct'
        and c.request_status = 'accepted'
    );
$$;

create or replace function public.chat_is_conversation_member(p_conversation_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = p_user_id
      and cm.status in ('active', 'pending')
      and p_user_id = auth.uid()
  );
$$;

create or replace function public.create_direct_conversation(target_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_conversation_id uuid;
  v_request_status text;
  v_member_status text;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if target_user_id is null or target_user_id = v_current_user then
    raise exception 'Target user is invalid';
  end if;

  if not exists (select 1 from public.profiles p where p.id = target_user_id) then
    raise exception 'Target user not found';
  end if;

  select c.id into v_conversation_id
  from public.chat_conversations c
  where c.type = 'direct'
    and least(c.requested_by, c.requested_to) = least(v_current_user, target_user_id)
    and greatest(c.requested_by, c.requested_to) = greatest(v_current_user, target_user_id)
  limit 1;

  if v_conversation_id is not null then
    return v_conversation_id;
  end if;

  if public.chat_users_have_relationship(v_current_user, target_user_id) then
    v_request_status := 'accepted';
    v_member_status := 'active';
  else
    v_request_status := 'pending';
    v_member_status := 'pending';
  end if;

  begin
    insert into public.chat_conversations (
      type,
      created_by,
      requested_by,
      requested_to,
      request_status,
      last_message_at
    )
    values (
      'direct',
      v_current_user,
      v_current_user,
      target_user_id,
      v_request_status,
      now()
    )
    returning id into v_conversation_id;
  exception
    when unique_violation then
      select c.id into v_conversation_id
      from public.chat_conversations c
      where c.type = 'direct'
        and least(c.requested_by, c.requested_to) = least(v_current_user, target_user_id)
        and greatest(c.requested_by, c.requested_to) = greatest(v_current_user, target_user_id)
      limit 1;

      if v_conversation_id is null then
        raise;
      end if;

      return v_conversation_id;
  end;

  insert into public.chat_conversation_members (conversation_id, user_id, role, status)
  values
    (v_conversation_id, v_current_user, 'owner', 'active'),
    (v_conversation_id, target_user_id, 'member', v_member_status)
  on conflict (conversation_id, user_id) do update
  set status = case
        when excluded.status = 'active' then 'active'
        else public.chat_conversation_members.status
      end,
      joined_at = coalesce(public.chat_conversation_members.joined_at, now());

  return v_conversation_id;
end;
$$;

create or replace function public.create_group_conversation(title text, member_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_conversation_id uuid;
  v_title text := nullif(btrim(title), '');
  v_member_id uuid;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if v_title is not null and char_length(v_title) > 80 then
    raise exception 'Group title must be 80 characters or fewer';
  end if;

  insert into public.chat_conversations (type, title, created_by, request_status, last_message_at)
  values ('group', v_title, v_current_user, 'none', now())
  returning id into v_conversation_id;

  insert into public.chat_conversation_members (conversation_id, user_id, role, status)
  values (v_conversation_id, v_current_user, 'owner', 'active');

  for v_member_id in
    select distinct unnest(coalesce(member_ids, '{}'::uuid[]))
  loop
    if v_member_id is not null and v_member_id <> v_current_user then
      if not public.chat_can_add_group_member(v_current_user, v_member_id) then
        raise exception 'Cannot add group member % without relationship or accepted direct chat', v_member_id;
      end if;

      insert into public.chat_conversation_members (conversation_id, user_id, role, status)
      values (v_conversation_id, v_member_id, 'member', 'active')
      on conflict (conversation_id, user_id) do nothing;
    end if;
  end loop;

  return v_conversation_id;
end;
$$;

create or replace function public.rename_group_conversation(p_conversation_id uuid, p_title text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_title text := nullif(btrim(p_title), '');
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if v_title is not null and char_length(v_title) > 80 then
    raise exception 'Group title must be 80 characters or fewer';
  end if;

  update public.chat_conversations c
  set title = v_title,
      updated_at = now()
  where c.id = p_conversation_id
    and c.type = 'group'
    and exists (
      select 1
      from public.chat_conversation_members cm
      where cm.conversation_id = c.id
        and cm.user_id = v_current_user
        and cm.status = 'active'
    );

  if not found then
    raise exception 'Group conversation not found';
  end if;
end;
$$;

create or replace function public.add_group_members(p_conversation_id uuid, p_member_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_member_id uuid;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.chat_conversations c
    join public.chat_conversation_members cm
      on cm.conversation_id = c.id
     and cm.user_id = v_current_user
     and cm.status = 'active'
    where c.id = p_conversation_id
      and c.type = 'group'
  ) then
    raise exception 'Group conversation not found';
  end if;

  for v_member_id in
    select distinct unnest(coalesce(p_member_ids, '{}'::uuid[]))
  loop
    if v_member_id is not null and v_member_id <> v_current_user then
      if not public.chat_can_add_group_member(v_current_user, v_member_id) then
        raise exception 'Cannot add group member % without relationship or accepted direct chat', v_member_id;
      end if;

      insert into public.chat_conversation_members (conversation_id, user_id, role, status)
      values (p_conversation_id, v_member_id, 'member', 'active')
      on conflict (conversation_id, user_id) do update
      set status = 'active',
          joined_at = coalesce(public.chat_conversation_members.joined_at, now());
    end if;
  end loop;
end;
$$;

create or replace function public.chat_image_storage_paths_from_body(p_body text)
returns text[]
language plpgsql
immutable
set search_path = public
as $$
declare
  v_raw text;
  v_json jsonb;
  v_paths text[] := '{}'::text[];
  v_legacy_path text;
begin
  if p_body like 'cz-image:%' then
    v_raw := btrim(substring(p_body from char_length('cz-image:') + 1));
    begin
      v_json := v_raw::jsonb;
      if jsonb_typeof(v_json) = 'object' and v_json ? 'path' then
        v_paths := array_append(v_paths, v_json ->> 'path');
      end if;
    exception when others then
      v_legacy_path := coalesce(
        nullif(split_part(v_raw, '/storage/v1/object/public/images/', 2), ''),
        split_part(v_raw, '/storage/v1/object/public/post-images/', 2)
      );
      if btrim(v_legacy_path) <> '' then
        v_paths := array_append(v_paths, v_legacy_path);
      end if;
    end;
  elsif p_body like 'cz-images:%' then
    v_raw := btrim(substring(p_body from char_length('cz-images:') + 1));
    begin
      v_json := v_raw::jsonb;
      if jsonb_typeof(v_json) = 'array' then
        select coalesce(
          array_agg(
            case
              when jsonb_typeof(item) = 'object' then item ->> 'path'
              when jsonb_typeof(item) = 'string' then coalesce(
                nullif(split_part(trim(both '"' from item::text), '/storage/v1/object/public/images/', 2), ''),
                split_part(trim(both '"' from item::text), '/storage/v1/object/public/post-images/', 2)
              )
              else null
            end
          ) filter (
            where (
              jsonb_typeof(item) = 'object'
              and item ? 'path'
              and btrim(item ->> 'path') <> ''
            )
            or (
              jsonb_typeof(item) = 'string'
              and btrim(coalesce(
                nullif(split_part(trim(both '"' from item::text), '/storage/v1/object/public/images/', 2), ''),
                split_part(trim(both '"' from item::text), '/storage/v1/object/public/post-images/', 2)
              )) <> ''
            )
          ),
          '{}'::text[]
        )
        into v_paths
        from jsonb_array_elements(v_json) item;
      end if;
    exception when others then
      v_paths := '{}'::text[];
    end;
  end if;

  return coalesce(v_paths, '{}'::text[]);
end;
$$;

create or replace function public.chat_delete_message_storage_objects(p_body text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paths text[] := public.chat_image_storage_paths_from_body(p_body);
begin
  if coalesce(array_length(v_paths, 1), 0) = 0 then
    return;
  end if;

  delete from storage.objects
  where bucket_id = 'images'
    and name = any(v_paths);
exception when others then
  raise notice 'Chat image storage cleanup skipped: %', sqlerrm;
end;
$$;

create or replace function public.chat_prune_message_if_fully_deleted(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation_id uuid;
  v_body text;
begin
  select m.conversation_id, m.body into v_conversation_id, v_body
  from public.chat_messages m
  where m.id = p_message_id;

  if v_conversation_id is null then
    return;
  end if;

  if not exists (
    select 1
    from public.chat_conversation_members cm
    join public.chat_messages m
      on m.id = p_message_id
     and m.conversation_id = cm.conversation_id
    where cm.conversation_id = v_conversation_id
      and cm.status in ('active', 'pending')
      and not (cm.user_id = any(m.deleted_for))
  ) then
    perform public.chat_delete_message_storage_objects(v_body);

    delete from public.chat_messages m
    where m.id = p_message_id;
  end if;
end;
$$;

create or replace function public.chat_delete_group_messages_if_empty(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.chat_conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.status in ('active', 'pending')
  ) then
    perform public.chat_delete_message_storage_objects(m.body)
    from public.chat_messages m
    join public.chat_conversations c
      on c.id = p_conversation_id
     and c.type = 'group'
    where m.conversation_id = p_conversation_id;

    delete from public.chat_messages m
    using public.chat_conversations c
    where m.conversation_id = p_conversation_id
      and c.id = p_conversation_id
      and c.type = 'group';
  end if;
end;
$$;

create or replace function public.remove_group_member(p_conversation_id uuid, p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if p_member_id is null or p_member_id = v_current_user then
    raise exception 'Cannot remove this member';
  end if;

  if not exists (
    select 1
    from public.chat_conversation_members cm
    join public.chat_conversations c
      on c.id = cm.conversation_id
     and c.type = 'group'
    where cm.conversation_id = p_conversation_id
      and cm.user_id = v_current_user
      and cm.role = 'owner'
      and cm.status = 'active'
  ) then
    raise exception 'Only group admins can remove members';
  end if;

  update public.chat_conversation_members cm
  set status = 'removed',
      cleared_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = p_member_id
    and cm.role <> 'owner'
    and cm.status = 'active';

  if not found then
    raise exception 'Group member not found';
  end if;

  perform public.chat_delete_group_messages_if_empty(p_conversation_id);
end;
$$;

create or replace function public.exit_group_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.chat_conversation_members cm
  set status = 'left',
      cleared_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = v_current_user
    and cm.status = 'active'
    and exists (
      select 1
      from public.chat_conversations c
      where c.id = p_conversation_id
        and c.type = 'group'
    );

  if not found then
    raise exception 'Group membership not found';
  end if;

  perform public.chat_delete_group_messages_if_empty(p_conversation_id);
end;
$$;

create or replace function public.delete_chat_message_for_me(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.chat_messages m
  set deleted_for = (
    select array_agg(distinct user_id)
    from unnest(m.deleted_for || v_current_user) as user_id
  )
  where m.id = p_message_id
    and exists (
      select 1
      from public.chat_conversation_members cm
      where cm.conversation_id = m.conversation_id
        and cm.user_id = v_current_user
        and cm.status in ('active', 'pending')
    );

  if not found then
    raise exception 'Message not found';
  end if;

  perform public.chat_prune_message_if_fully_deleted(p_message_id);
end;
$$;

create or replace function public.restore_chat_message_for_me(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.chat_messages m
  set deleted_for = array_remove(m.deleted_for, v_current_user)
  where m.id = p_message_id
    and exists (
      select 1
      from public.chat_conversation_members cm
      where cm.conversation_id = m.conversation_id
        and cm.user_id = v_current_user
        and cm.status in ('active', 'pending')
    );

  if not found then
    raise exception 'Message not found';
  end if;
end;
$$;

create or replace function public.unsend_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_body text;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  select m.body into v_body
  from public.chat_messages m
  where m.id = p_message_id
    and m.sender_id = v_current_user
    and m.created_at >= now() - interval '10 minutes'
    and exists (
      select 1
      from public.chat_conversation_members cm
      where cm.conversation_id = m.conversation_id
        and cm.user_id = v_current_user
        and cm.status in ('active', 'pending')
    );

  if not found then
    raise exception 'Message can no longer be unsent';
  end if;

  perform public.chat_delete_message_storage_objects(v_body);

  delete from public.chat_messages m
  where m.id = p_message_id;
end;
$$;

create or replace function public.send_chat_message(p_conversation_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_conversation public.chat_conversations%rowtype;
  v_message_id uuid;
  v_pending_message_count int;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 10000 then
    raise exception 'Message body must be 1 to 10000 characters';
  end if;

  if p_conversation_id is null then
    raise exception 'Conversation id is required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_conversation_id::text, 0));

  select c.* into v_conversation
  from public.chat_conversations c
  where c.id = p_conversation_id
  for update;

  if not found then
    raise exception 'Conversation not found';
  end if;

  if not exists (
    select 1
    from public.chat_conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = v_current_user
      and cm.status = 'active'
  ) then
    raise exception 'Active conversation membership required';
  end if;

  if v_conversation.type = 'direct'
    and v_conversation.request_status = 'pending'
    and v_conversation.requested_by = v_current_user
    and not public.chat_users_have_relationship(v_conversation.requested_by, v_conversation.requested_to)
  then
    select count(*) into v_pending_message_count
    from public.chat_messages m
    where m.conversation_id = p_conversation_id
      and m.sender_id = v_current_user
      and m.deleted_at is null;

    if v_pending_message_count >= 3 then
      raise exception 'Pending message requests are limited to 3 messages';
    end if;
  end if;

  insert into public.chat_messages (conversation_id, sender_id, body)
  values (p_conversation_id, v_current_user, v_body)
  returning id into v_message_id;

  update public.chat_conversations c
  set last_message_at = now()
  where c.id = p_conversation_id;

  update public.chat_conversation_members cm
  set last_read_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = v_current_user;

  begin
    insert into public.notifications (
      user_id,
      type,
      actor_id,
      conversation_id,
      message_id,
      title,
      body,
      action_type,
      action_payload
    )
    select
      cm.user_id,
      'chat_message',
      v_current_user,
      p_conversation_id,
      v_message_id,
      'New message',
      left(v_body, 160),
      'open_conversation',
      jsonb_build_object('conversation_id', p_conversation_id, 'message_id', v_message_id)
    from public.chat_conversation_members cm
    left join public.notification_preferences np
      on np.user_id = cm.user_id
    where cm.conversation_id = p_conversation_id
      and cm.user_id <> v_current_user
      and cm.status in ('active', 'pending')
      and coalesce(np.in_app_enabled, true)
      and coalesce(np.chat_enabled, true);
  exception
    when undefined_column or check_violation or foreign_key_violation then
      raise notice 'Chat message saved but notification insert skipped: %', sqlerrm;
  end;

  return v_message_id;
end;
$$;

create or replace function public.accept_message_request(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.chat_conversations c
  set request_status = 'accepted'
  where c.id = p_conversation_id
    and c.type = 'direct'
    and c.request_status = 'pending'
    and c.requested_to = v_current_user;

  if not found then
    raise exception 'Pending message request not found';
  end if;

  update public.chat_conversation_members cm
  set status = 'active',
      joined_at = coalesce(cm.joined_at, now())
  where cm.conversation_id = p_conversation_id
    and cm.user_id = v_current_user
    and cm.status = 'pending';
end;
$$;

create or replace function public.clear_chat(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.chat_conversation_members cm
  set cleared_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = v_current_user
    and cm.status in ('active', 'pending');

  if not found then
    raise exception 'Conversation membership not found';
  end if;
end;
$$;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.chat_conversation_members cm
  set last_read_at = now()
  where cm.conversation_id = p_conversation_id
    and cm.user_id = v_current_user
    and cm.status in ('active', 'pending');

  if not found then
    raise exception 'Conversation membership not found';
  end if;

  update public.notifications n
  set read_at = coalesce(n.read_at, now())
  where n.user_id = v_current_user
    and n.conversation_id = p_conversation_id
    and n.read_at is null;
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  update public.notifications n
  set read_at = coalesce(n.read_at, now())
  where n.id = p_notification_id
    and n.user_id = v_current_user;

  if not found then
    raise exception 'Notification not found';
  end if;
end;
$$;

create or replace function public.mark_notification_section_read(p_section text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  if p_section = 'activity' then
    update public.notifications n
    set read_at = coalesce(n.read_at, now())
    where n.user_id = v_current_user
      and n.read_at is null
      and n.type not in ('system', 'new_follower', 'chat_message');
  elsif p_section = 'followers' then
    update public.notifications n
    set read_at = coalesce(n.read_at, now())
    where n.user_id = v_current_user
      and n.read_at is null
      and n.type = 'new_follower';
  elsif p_section = 'system' then
    update public.notifications n
    set read_at = coalesce(n.read_at, now())
    where n.user_id = v_current_user
      and n.read_at is null
      and n.type = 'system';
  else
    raise exception 'Unsupported notification section: %', p_section;
  end if;
end;
$$;

create or replace function public.notify_new_follower()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.following_id <> new.follower_id then
    delete from public.notifications
    where user_id = new.following_id
      and type = 'new_follower'
      and actor_id = new.follower_id;

    insert into public.notifications (user_id, type, actor_id, title, body, action_type, action_payload)
    select
      new.following_id,
      'new_follower',
      new.follower_id,
      'New follower',
      'Someone started following you',
      'open_profile',
      jsonb_build_object('user_id', new.follower_id)
    where exists (select 1 from public.profiles p where p.id = new.following_id)
      and coalesce((
        select np.in_app_enabled and np.followers_enabled
        from public.notification_preferences np
        where np.user_id = new.following_id
      ), true);
  end if;

  return new;
end;
$$;

create or replace function public.notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author_id uuid;
begin
  if new.reaction_type = 'like' then
    select p.author_id into v_post_author_id
    from public.posts p
    where p.id = new.post_id;

    if v_post_author_id is not null and v_post_author_id <> new.user_id then
      insert into public.notifications (user_id, type, actor_id, post_id, title, body, action_type, action_payload)
      select
        v_post_author_id,
        'like',
        new.user_id,
        new.post_id,
        'New like',
        'Someone liked your post',
        'open_post',
        jsonb_build_object('post_id', new.post_id)
      where coalesce((
        select np.in_app_enabled and np.activity_enabled
        from public.notification_preferences np
        where np.user_id = v_post_author_id
      ), true)
        and not exists (
          select 1
          from public.notifications existing
          where existing.user_id = v_post_author_id
            and existing.type = 'like'
            and existing.actor_id = new.user_id
            and existing.post_id = new.post_id
        );
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.notify_post_favorite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author_id uuid;
begin
  select p.author_id into v_post_author_id
  from public.posts p
  where p.id = new.post_id;

  if v_post_author_id is not null and v_post_author_id <> new.user_id then
    insert into public.notifications (user_id, type, actor_id, post_id, title, body, action_type, action_payload)
    select
      v_post_author_id,
      'favorite',
      new.user_id,
      new.post_id,
      'New favorite',
      'Someone saved your post',
      'open_post',
      jsonb_build_object('post_id', new.post_id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_post_author_id
    ), true)
      and not exists (
        select 1
        from public.notifications existing
        where existing.user_id = v_post_author_id
          and existing.type = 'favorite'
          and existing.actor_id = new.user_id
          and existing.post_id = new.post_id
      );
  end if;

  return new;
end;
$$;

create or replace function public.notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author_id uuid;
  v_parent_author_id uuid;
begin
  select p.author_id into v_post_author_id
  from public.posts p
  where p.id = new.post_id;

  if new.parent_comment_id is not null then
    select parent.author_id into v_parent_author_id
    from public.comments parent
    where parent.id = new.parent_comment_id;
  end if;

  if v_post_author_id is not null and v_post_author_id <> new.author_id then
    insert into public.notifications (user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload)
    select
      v_post_author_id,
      case when new.parent_comment_id is null then 'comment' else 'comment_reply' end,
      new.author_id,
      new.post_id,
      new.id,
      case when new.parent_comment_id is null then 'New comment' else 'New reply' end,
      case when new.parent_comment_id is null then 'commented on your post' else 'replied to a comment on your post' end,
      'open_post',
      jsonb_build_object('post_id', new.post_id, 'comment_id', new.id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_post_author_id
    ), true);
  end if;

  if v_parent_author_id is not null
    and v_parent_author_id <> new.author_id
    and v_parent_author_id is distinct from v_post_author_id
  then
    insert into public.notifications (user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload)
    select
      v_parent_author_id,
      'comment_reply',
      new.author_id,
      new.post_id,
      new.id,
      'New reply',
      'replied to your comment',
      'open_post',
      jsonb_build_object('post_id', new.post_id, 'comment_id', new.id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_parent_author_id
    ), true);
  end if;

  if new.tagged_user_id is not null
    and new.tagged_user_id <> new.author_id
    and new.tagged_user_id is distinct from v_post_author_id
  then
    insert into public.notifications (user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload)
    select
      new.tagged_user_id,
      'mention',
      new.author_id,
      new.post_id,
      new.id,
      'New mention',
      'mentioned you',
      'open_post',
      jsonb_build_object('post_id', new.post_id, 'comment_id', new.id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = new.tagged_user_id
    ), true);
  end if;

  return new;
end;
$$;

create or replace function public.notify_comment_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_comment_author_id uuid;
  v_post_id uuid;
begin
  select c.author_id, c.post_id
  into v_comment_author_id, v_post_id
  from public.comments c
  where c.id = new.comment_id;

  if v_comment_author_id is not null and v_comment_author_id <> new.user_id then
    insert into public.notifications (user_id, type, actor_id, post_id, comment_id, title, body, action_type, action_payload)
    select
      v_comment_author_id,
      'comment_like',
      new.user_id,
      v_post_id,
      new.comment_id,
      'Comment liked',
      'liked your comment',
      'open_post',
      jsonb_build_object('post_id', v_post_id, 'comment_id', new.comment_id)
    where coalesce((
      select np.in_app_enabled and np.activity_enabled
      from public.notification_preferences np
      where np.user_id = v_comment_author_id
    ), true)
      and not exists (
        select 1
        from public.notifications existing
        where existing.user_id = v_comment_author_id
          and existing.type = 'comment_like'
          and existing.actor_id = new.user_id
          and existing.comment_id = new.comment_id
      );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_new_follower_on_insert on public.follows;
create trigger notify_new_follower_on_insert
after insert on public.follows
for each row execute function public.notify_new_follower();

drop trigger if exists notify_post_like_on_insert on public.likes;
create trigger notify_post_like_on_insert
after insert on public.likes
for each row execute function public.notify_post_like();

drop trigger if exists notify_post_favorite_on_insert on public.saves;
create trigger notify_post_favorite_on_insert
after insert on public.saves
for each row execute function public.notify_post_favorite();

drop trigger if exists notify_post_comment_on_insert on public.comments;
create trigger notify_post_comment_on_insert
after insert on public.comments
for each row execute function public.notify_post_comment();

drop trigger if exists notify_comment_like_on_insert on public.comment_likes;
create trigger notify_comment_like_on_insert
after insert on public.comment_likes
for each row execute function public.notify_comment_like();

alter table public.chat_conversations enable row level security;
alter table public.chat_conversation_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Conversations visible to members" on public.chat_conversations;
create policy "Conversations visible to members"
on public.chat_conversations for select
to authenticated
using (
  public.chat_is_conversation_member(chat_conversations.id, auth.uid())
);

drop policy if exists "Members visible to conversation members" on public.chat_conversation_members;
create policy "Members visible to conversation members"
on public.chat_conversation_members for select
to authenticated
using (
  public.chat_is_conversation_member(chat_conversation_members.conversation_id, auth.uid())
);

drop policy if exists "Users update own chat member state" on public.chat_conversation_members;

drop policy if exists "Messages visible to active or pending members" on public.chat_messages;
create policy "Messages visible to active or pending members"
on public.chat_messages for select
to authenticated
  using (
  deleted_at is null
  and not (auth.uid() = any(deleted_for))
  and exists (
    select 1
    from public.chat_conversation_members cm
    where cm.conversation_id = chat_messages.conversation_id
      and cm.user_id = auth.uid()
      and cm.status in ('active', 'pending')
      and (cm.cleared_at is null or chat_messages.created_at > cm.cleared_at)
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

revoke execute on function public.chat_users_have_relationship(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.chat_can_add_group_member(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.chat_is_conversation_member(uuid, uuid) from public, anon;

revoke execute on function public.create_direct_conversation(uuid) from public, anon;
revoke execute on function public.create_group_conversation(text, uuid[]) from public, anon;
revoke execute on function public.send_chat_message(uuid, text) from public, anon;
revoke execute on function public.accept_message_request(uuid) from public, anon;
revoke execute on function public.clear_chat(uuid) from public, anon;
revoke execute on function public.rename_group_conversation(uuid, text) from public, anon;
revoke execute on function public.add_group_members(uuid, uuid[]) from public, anon;
revoke execute on function public.exit_group_conversation(uuid) from public, anon;
revoke execute on function public.remove_group_member(uuid, uuid) from public, anon;
revoke execute on function public.delete_chat_message_for_me(uuid) from public, anon;
revoke execute on function public.restore_chat_message_for_me(uuid) from public, anon;
revoke execute on function public.unsend_chat_message(uuid) from public, anon;
revoke execute on function public.mark_conversation_read(uuid) from public, anon;
revoke execute on function public.mark_notification_read(uuid) from public, anon;
revoke execute on function public.mark_notification_section_read(text) from public, anon;

grant execute on function public.chat_is_conversation_member(uuid, uuid) to authenticated;
grant execute on function public.create_direct_conversation(uuid) to authenticated;
grant execute on function public.create_group_conversation(text, uuid[]) to authenticated;
grant execute on function public.send_chat_message(uuid, text) to authenticated;
grant execute on function public.accept_message_request(uuid) to authenticated;
grant execute on function public.clear_chat(uuid) to authenticated;
grant execute on function public.rename_group_conversation(uuid, text) to authenticated;
grant execute on function public.add_group_members(uuid, uuid[]) to authenticated;
grant execute on function public.exit_group_conversation(uuid) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid) to authenticated;
grant execute on function public.delete_chat_message_for_me(uuid) to authenticated;
grant execute on function public.restore_chat_message_for_me(uuid) to authenticated;
grant execute on function public.unsend_chat_message(uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_notification_section_read(text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'chat_conversations'
    ) then
      alter publication supabase_realtime add table public.chat_conversations;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'chat_conversation_members'
    ) then
      alter publication supabase_realtime add table public.chat_conversation_members;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'chat_messages'
    ) then
      alter publication supabase_realtime add table public.chat_messages;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'notifications'
    ) then
      alter publication supabase_realtime add table public.notifications;
    end if;
  end if;
end $$;
