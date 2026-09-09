-- Apply after chat.sql and parent_supervision.sql.
-- This migration is safe to rerun. It enables Android FCM delivery while
-- keeping phone-push and in-app notification preferences independent.

alter table public.notification_preferences
  add column if not exists push_enabled boolean not null default false;

alter table public.notifications
  add column if not exists in_app_visible boolean not null default true;

alter table public.supervision_notifications
  add column if not exists in_app_visible boolean not null default true;

update public.notifications
set in_app_visible = true
where in_app_visible is null;

update public.supervision_notifications
set in_app_visible = true
where in_app_visible is null;

create table if not exists public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  device_id text not null check (char_length(btrim(device_id)) between 8 and 160),
  token text not null unique check (char_length(btrim(token)) between 20 and 4096),
  platform text not null check (platform in ('android')),
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create index if not exists push_device_tokens_user_active_idx
on public.push_device_tokens(user_id, is_active, updated_at desc);

create index if not exists push_device_tokens_active_token_idx
on public.push_device_tokens(token)
where is_active;

create table if not exists public.push_deliveries (
  id uuid primary key default gen_random_uuid(),
  source_table text not null check (
    source_table in ('notifications', 'supervision_notifications')
  ),
  source_id uuid not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (
    category in ('chat', 'activity', 'system', 'followers')
  ),
  status text not null default 'processing' check (
    status in ('processing', 'delivered', 'partial', 'skipped', 'failed')
  ),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  success_count integer not null default 0 check (success_count >= 0),
  failure_count integer not null default 0 check (failure_count >= 0),
  last_error_code text check (last_error_code is null or char_length(last_error_code) <= 160),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_table, source_id)
);

create index if not exists push_deliveries_status_updated_idx
on public.push_deliveries(status, updated_at desc);

create or replace function public.push_notification_category(
  p_source_table text,
  p_event_type text
)
returns text
language sql
immutable
as $$
  select case
    when p_source_table = 'supervision_notifications' then 'system'
    when p_source_table = 'notifications' and p_event_type = 'chat_message' then 'chat'
    when p_source_table = 'notifications' and p_event_type in (
      'like', 'favorite', 'comment', 'comment_reply', 'comment_like', 'mention'
    ) then 'activity'
    when p_source_table = 'notifications' and p_event_type = 'new_follower' then 'followers'
    when p_source_table = 'notifications' and p_event_type = 'system' then 'system'
    else null
  end;
$$;

create or replace function public.enforce_notification_channel_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category text;
  v_in_app boolean := true;
  v_push boolean := false;
  v_category_enabled boolean := true;
begin
  v_category := public.push_notification_category(
    tg_table_name,
    case
      when tg_table_name = 'notifications' then new.type
      else new.event_type
    end
  );

  select
    coalesce(np.in_app_enabled, true),
    coalesce(np.push_enabled, false),
    case v_category
      when 'chat' then coalesce(np.chat_enabled, true)
      when 'activity' then coalesce(np.activity_enabled, true)
      when 'system' then coalesce(np.system_enabled, true)
      when 'followers' then coalesce(np.followers_enabled, true)
      else true
    end
  into v_in_app, v_push, v_category_enabled
  from public.notification_preferences np
  where np.user_id = new.user_id;

  v_in_app := coalesce(v_in_app, true);
  v_push := coalesce(v_push, false);
  v_category_enabled := coalesce(v_category_enabled, true);

  if v_category is null or not v_category_enabled or (not v_in_app and not v_push) then
    return null;
  end if;

  new.in_app_visible := v_in_app;
  return new;
end;
$$;

drop trigger if exists enforce_notification_channel_preferences
on public.notifications;
create trigger enforce_notification_channel_preferences
before insert on public.notifications
for each row execute function public.enforce_notification_channel_preferences();

drop trigger if exists enforce_supervision_notification_channel_preferences
on public.supervision_notifications;
create trigger enforce_supervision_notification_channel_preferences
before insert on public.supervision_notifications
for each row execute function public.enforce_notification_channel_preferences();

drop policy if exists "Users view own notifications" on public.notifications;
create policy "Users view own notifications"
on public.notifications for select
to authenticated
using (user_id = auth.uid() and in_app_visible);

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications"
on public.notifications for update
to authenticated
using (user_id = auth.uid() and in_app_visible)
with check (user_id = auth.uid() and in_app_visible);

drop policy if exists "Users view own supervision notifications"
on public.supervision_notifications;
create policy "Users view own supervision notifications"
on public.supervision_notifications for select
to authenticated
using (user_id = auth.uid() and in_app_visible);

alter table public.push_device_tokens enable row level security;
alter table public.push_deliveries enable row level security;

drop policy if exists "Users view own push devices" on public.push_device_tokens;
create policy "Users view own push devices"
on public.push_device_tokens for select
to authenticated
using (user_id = auth.uid() and is_active);

revoke insert, update, delete on public.push_device_tokens from anon, authenticated;
revoke insert, update, delete on public.push_deliveries from anon, authenticated;

create or replace function public.register_push_device(
  p_user_id uuid,
  p_device_id text,
  p_token text,
  p_platform text default 'android'
)
returns public.push_device_tokens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device public.push_device_tokens;
begin
  if p_user_id is null or p_platform <> 'android'
     or char_length(btrim(coalesce(p_device_id, ''))) not between 8 and 160
     or char_length(btrim(coalesce(p_token, ''))) not between 20 and 4096 then
    raise exception 'Invalid push device registration';
  end if;

  update public.push_device_tokens
  set is_active = false, updated_at = now()
  where user_id = p_user_id
    and device_id = p_device_id
    and token <> p_token;

  update public.push_device_tokens
  set user_id = p_user_id,
      device_id = p_device_id,
      platform = p_platform,
      is_active = true,
      last_seen_at = now(),
      updated_at = now()
  where token = p_token
  returning * into v_device;

  if not found then
    insert into public.push_device_tokens (user_id, device_id, token, platform)
    values (p_user_id, p_device_id, p_token, p_platform)
    returning * into v_device;
  end if;

  return v_device;
end;
$$;

create or replace function public.deactivate_push_device(
  p_user_id uuid,
  p_device_id text
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.push_device_tokens
  set is_active = false, updated_at = now()
  where user_id = p_user_id and device_id = p_device_id;
$$;

create or replace function public.claim_push_delivery(
  p_source_table text,
  p_source_id uuid,
  p_user_id uuid,
  p_category text
)
returns table (delivery_id uuid, claimed boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delivery public.push_deliveries;
begin
  insert into public.push_deliveries (source_table, source_id, user_id, category, status)
  values (p_source_table, p_source_id, p_user_id, p_category, 'processing')
  on conflict (source_table, source_id) do nothing;

  select * into v_delivery
  from public.push_deliveries
  where source_table = p_source_table and source_id = p_source_id
  for update;

  if v_delivery.status in ('delivered', 'partial', 'skipped') then
    return query select v_delivery.id, false, v_delivery.status;
    return;
  end if;

  if v_delivery.status = 'processing'
     and v_delivery.started_at is not null
     and v_delivery.started_at > now() - interval '2 minutes' then
    return query select v_delivery.id, false, 'processing';
    return;
  end if;

  update public.push_deliveries
  set status = 'processing',
      attempt_count = attempt_count + 1,
      started_at = now(),
      updated_at = now()
  where id = v_delivery.id;

  return query select v_delivery.id, true, 'claimed';
end;
$$;

create or replace function public.complete_push_delivery(
  p_delivery_id uuid,
  p_status text,
  p_success_count integer,
  p_failure_count integer,
  p_last_error_code text default null
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.push_deliveries
  set status = p_status,
      success_count = greatest(p_success_count, 0),
      failure_count = greatest(p_failure_count, 0),
      last_error_code = left(p_last_error_code, 160),
      completed_at = now(),
      updated_at = now()
  where id = p_delivery_id and status = 'processing';
$$;

revoke execute on function public.register_push_device(uuid, text, text, text)
from public, anon, authenticated;
revoke execute on function public.deactivate_push_device(uuid, text)
from public, anon, authenticated;
revoke execute on function public.claim_push_delivery(text, uuid, uuid, text)
from public, anon, authenticated;
revoke execute on function public.complete_push_delivery(uuid, text, integer, integer, text)
from public, anon, authenticated;

grant execute on function public.register_push_device(uuid, text, text, text)
to service_role;
grant execute on function public.deactivate_push_device(uuid, text)
to service_role;
grant execute on function public.claim_push_delivery(text, uuid, uuid, text)
to service_role;
grant execute on function public.complete_push_delivery(uuid, text, integer, integer, text)
to service_role;

alter table public.notifications replica identity full;
alter table public.supervision_notifications replica identity full;
