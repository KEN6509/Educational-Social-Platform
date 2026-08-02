-- Parent Supervision foundation migration.
-- Apply this complete file after schema.sql in the Supabase SQL Editor.

do $$
begin
  alter type public.link_status add value 'cancelled';
exception
  when duplicate_object then null;
end $$;

create or replace function public.parent_supervision_assert_role(
  p_user_id uuid,
  p_role text,
  p_excluded_link_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_role not in ('parent', 'child') then
    raise exception 'Invalid family role';
  end if;

  if p_role = 'parent' and exists (
    select 1
    from public.parent_child_links link
    where link.child_id = p_user_id
      and link.status in ('pending', 'active')
      and (p_excluded_link_id is null or link.id <> p_excluded_link_id)
  ) then
    raise exception 'This account already has the child role';
  end if;

  if p_role = 'child' and exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = p_user_id
      and link.status in ('pending', 'active')
      and (p_excluded_link_id is null or link.id <> p_excluded_link_id)
  ) then
    raise exception 'This account already has the parent role';
  end if;
end;
$$;

create or replace function public.create_parent_child_link(
  p_candidate_id uuid,
  p_requester_role text
)
returns public.parent_child_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_parent_id uuid;
  v_child_id uuid;
  v_requester_name text;
  v_link public.parent_child_links;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_candidate_id is null or p_candidate_id = v_user_id then
    raise exception 'Choose another account for a family link';
  end if;
  if p_requester_role not in ('parent', 'child') then
    raise exception 'Choose either the parent or child role';
  end if;
  if not exists (
    select 1 from public.profiles profile
    where profile.id = p_candidate_id
      and profile.account_status = 'active'
  ) then
    raise exception 'This account is not available for family linking';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(least(v_user_id, p_candidate_id)::text, 0)
  );
  perform pg_advisory_xact_lock(
    hashtextextended(greatest(v_user_id, p_candidate_id)::text, 0)
  );

  if exists (
    select 1
    from public.parent_child_links link
    where least(link.parent_id, link.child_id) = least(v_user_id, p_candidate_id)
      and greatest(link.parent_id, link.child_id) = greatest(v_user_id, p_candidate_id)
      and link.status in ('pending', 'active')
  ) then
    raise exception 'A pending or active family link already exists';
  end if;

  if p_requester_role = 'parent' then
    v_parent_id := v_user_id;
    v_child_id := p_candidate_id;
    perform public.parent_supervision_assert_role(v_user_id, 'parent');
    perform public.parent_supervision_assert_role(p_candidate_id, 'child');
  else
    v_parent_id := p_candidate_id;
    v_child_id := v_user_id;
    perform public.parent_supervision_assert_role(v_user_id, 'child');
    perform public.parent_supervision_assert_role(p_candidate_id, 'parent');
  end if;

  insert into public.parent_child_links (
    parent_id,
    child_id,
    status,
    requested_by
  ) values (
    v_parent_id,
    v_child_id,
    'pending',
    v_user_id
  )
  returning * into v_link;

  select profile.name
  into v_requester_name
  from public.profiles profile
  where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id,
    event_type,
    title,
    body,
    event_key,
    link_id,
    child_id
  ) values (
    p_candidate_id,
    'link_request',
    'Family link request',
    coalesce(v_requester_name, 'A CyanZone user') || ' sent you a family link request.',
    'link:' || v_link.id::text || ':request:' || p_candidate_id::text,
    v_link.id,
    v_child_id
  );

  return v_link;
end;
$$;

create or replace function public.accept_parent_child_link(p_link_id uuid)
returns public.parent_child_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_link public.parent_child_links;
  v_acceptor_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_link
  from public.parent_child_links link
  where link.id = p_link_id
  for update;

  if not found then
    raise exception 'Family link request not found';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'This family link request is no longer pending';
  end if;
  if v_link.requested_by = v_user_id then
    raise exception 'The requester cannot accept their own request';
  end if;
  if v_user_id not in (v_link.parent_id, v_link.child_id) then
    raise exception 'Only the recipient can accept this request' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(least(v_link.parent_id, v_link.child_id)::text, 0)
  );
  perform pg_advisory_xact_lock(
    hashtextextended(greatest(v_link.parent_id, v_link.child_id)::text, 0)
  );
  perform public.parent_supervision_assert_role(
    v_link.parent_id,
    'parent',
    v_link.id
  );
  perform public.parent_supervision_assert_role(
    v_link.child_id,
    'child',
    v_link.id
  );

  update public.parent_child_links
  set status = 'active',
      linked_at = now(),
      responded_at = now(),
      cancelled_at = null
  where id = v_link.id
  returning * into v_link;

  select profile.name into v_acceptor_name
  from public.profiles profile
  where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, link_id, child_id
  ) values (
    v_link.requested_by,
    'link_accepted',
    'Family link accepted',
    coalesce(v_acceptor_name, 'The recipient') || ' accepted your family link request.',
    'link:' || v_link.id::text || ':accepted:' || v_link.requested_by::text,
    v_link.id,
    v_link.child_id
  );

  return v_link;
end;
$$;

create or replace function public.reject_parent_child_link(p_link_id uuid)
returns public.parent_child_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_link public.parent_child_links;
  v_recipient_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_link
  from public.parent_child_links link
  where link.id = p_link_id
  for update;

  if not found then
    raise exception 'Family link request not found';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'This family link request is no longer pending';
  end if;
  if v_link.requested_by <> v_user_id
    and v_user_id in (v_link.parent_id, v_link.child_id) then
    null;
  else
    raise exception 'Only the recipient can reject this request' using errcode = '42501';
  end if;

  update public.parent_child_links
  set status = 'rejected',
      responded_at = now()
  where id = v_link.id
  returning * into v_link;

  select profile.name into v_recipient_name
  from public.profiles profile
  where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, link_id, child_id
  ) values (
    v_link.requested_by,
    'link_rejected',
    'Family link declined',
    coalesce(v_recipient_name, 'The recipient') || ' declined your family link request.',
    'link:' || v_link.id::text || ':rejected:' || v_link.requested_by::text,
    v_link.id,
    v_link.child_id
  );

  return v_link;
end;
$$;

create or replace function public.cancel_parent_child_link(p_link_id uuid)
returns public.parent_child_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_link public.parent_child_links;
  v_recipient_id uuid;
  v_requester_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_link
  from public.parent_child_links link
  where link.id = p_link_id
  for update;

  if not found then
    raise exception 'Family link request not found';
  end if;
  if v_link.status <> 'pending' then
    raise exception 'This family link request is no longer pending';
  end if;
  if not (v_link.requested_by = v_user_id) then
    raise exception 'Only the requester can cancel this request' using errcode = '42501';
  end if;

  v_recipient_id := case
    when v_link.parent_id = v_user_id then v_link.child_id
    else v_link.parent_id
  end;

  update public.parent_child_links
  set status = 'cancelled',
      cancelled_at = now()
  where id = v_link.id
  returning * into v_link;

  select profile.name into v_requester_name
  from public.profiles profile
  where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, link_id, child_id
  ) values (
    v_recipient_id,
    'link_cancelled',
    'Family link request cancelled',
    coalesce(v_requester_name, 'The requester') || ' cancelled the family link request.',
    'link:' || v_link.id::text || ':cancelled:' || v_recipient_id::text,
    v_link.id,
    v_link.child_id
  );

  return v_link;
end;
$$;

revoke all on function public.parent_supervision_assert_role(uuid, text, uuid)
from public, anon, authenticated;
revoke all on function public.create_parent_child_link(uuid, text) from public;
revoke all on function public.accept_parent_child_link(uuid) from public;
revoke all on function public.reject_parent_child_link(uuid) from public;
revoke all on function public.cancel_parent_child_link(uuid) from public;

grant execute on function public.create_parent_child_link(uuid, text)
to authenticated;
grant execute on function public.accept_parent_child_link(uuid)
to authenticated;
grant execute on function public.reject_parent_child_link(uuid)
to authenticated;
grant execute on function public.cancel_parent_child_link(uuid)
to authenticated;

alter table public.parent_child_links
  add column if not exists responded_at timestamptz,
  add column if not exists cancelled_at timestamptz;

alter table public.parent_child_links
  drop constraint if exists parent_child_links_parent_id_child_id_key;

create unique index if not exists parent_child_links_one_live_pair_idx
on public.parent_child_links (
  least(parent_id, child_id),
  greatest(parent_id, child_id)
)
where status in ('pending', 'active');

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'screen_time_logs'
      and column_name = 'child_id'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'screen_time_logs'
      and column_name = 'user_id'
  ) then
    alter table public.screen_time_logs rename column child_id to user_id;
  end if;
end $$;

alter table public.screen_time_logs
  add column if not exists seconds_used integer not null default 0
    check (seconds_used between 0 and 86400);

update public.screen_time_logs
set seconds_used = minutes_used * 60
where seconds_used = 0
  and minutes_used > 0;

create table if not exists public.screen_time_sync_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_session_id text not null,
  local_day date not null,
  seconds_used integer not null check (seconds_used > 0 and seconds_used <= 86400),
  timezone_offset_minutes integer not null
    check (timezone_offset_minutes between -840 and 840),
  created_at timestamptz not null default now(),
  unique (user_id, client_session_id)
);

create table if not exists public.screen_time_threshold_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_day date not null,
  threshold_hours integer not null check (threshold_hours >= 3),
  created_at timestamptz not null default now(),
  unique (user_id, local_day, threshold_hours)
);

alter table public.check_ins
  add column if not exists message text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists accuracy_meters double precision,
  add column if not exists location_captured_at timestamptz,
  add column if not exists location_status text not null default 'not_requested'
    check (location_status in ('not_requested', 'available', 'unavailable'));

update public.check_ins
set message = coalesce(nullif(btrim(note), ''), 'Safety Check-In')
where message is null;

alter table public.check_ins
  alter column message set not null,
  alter column mood drop not null;

alter table public.check_ins
  drop constraint if exists check_ins_message_length_check;

alter table public.check_ins
  add constraint check_ins_message_length_check
  check (char_length(btrim(message)) between 1 and 280);

alter table public.sos_alerts
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists accuracy_meters double precision,
  add column if not exists location_captured_at timestamptz,
  add column if not exists location_status text not null default 'unavailable'
    check (location_status in ('available', 'unavailable')),
  add column if not exists location_failure text,
  add column if not exists resolved_by uuid
    references public.profiles(id) on delete set null;

create table if not exists public.supervision_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in (
    'link_request',
    'link_accepted',
    'link_rejected',
    'link_cancelled',
    'check_in_sent',
    'check_in_received',
    'sos_opened',
    'sos_acknowledged',
    'sos_resolved',
    'screen_time_threshold'
  )),
  title text not null,
  body text not null,
  event_key text not null,
  link_id uuid references public.parent_child_links(id) on delete set null,
  check_in_id uuid references public.check_ins(id) on delete set null,
  sos_id uuid references public.sos_alerts(id) on delete set null,
  child_id uuid references public.profiles(id) on delete set null,
  threshold_hours integer,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, event_key)
);

create index if not exists screen_time_user_date_idx
on public.screen_time_logs(user_id, log_date desc);

create index if not exists screen_time_sync_user_day_idx
on public.screen_time_sync_events(user_id, local_day desc);

create index if not exists screen_time_threshold_user_day_idx
on public.screen_time_threshold_events(user_id, local_day desc);

create index if not exists supervision_notifications_user_created_idx
on public.supervision_notifications(user_id, created_at desc);

alter table public.screen_time_sync_events enable row level security;
alter table public.screen_time_threshold_events enable row level security;
alter table public.supervision_notifications enable row level security;

drop policy if exists "Users can request family links"
on public.parent_child_links;
drop policy if exists "Linked family can update links"
on public.parent_child_links;
drop policy if exists "Family can add screen time"
on public.screen_time_logs;
drop policy if exists "Users can create own check-ins"
on public.check_ins;
drop policy if exists "Children can create sos alerts"
on public.sos_alerts;
drop policy if exists "Linked parents can update sos alerts"
on public.sos_alerts;

drop policy if exists "Family can view screen time"
on public.screen_time_logs;
create policy "Family can view screen time"
on public.screen_time_logs for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = screen_time_logs.user_id
      and link.status = 'active'
  )
);

drop policy if exists "Family can view check-ins"
on public.check_ins;
drop policy if exists "Active family views child safety records"
on public.check_ins;
create policy "Active family views child safety records"
on public.check_ins for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = check_ins.user_id
      and link.status = 'active'
  )
);

drop policy if exists "Family can view sos alerts"
on public.sos_alerts;
drop policy if exists "Active family views child SOS records"
on public.sos_alerts;
create policy "Active family views child SOS records"
on public.sos_alerts for select
to authenticated
using (
  child_id = auth.uid()
  or exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = sos_alerts.child_id
      and link.status = 'active'
  )
);

drop policy if exists "Users view own screen time sync events"
on public.screen_time_sync_events;
create policy "Users view own screen time sync events"
on public.screen_time_sync_events for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users view own threshold events"
on public.screen_time_threshold_events;
create policy "Users view own threshold events"
on public.screen_time_threshold_events for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Users view own supervision notifications"
on public.supervision_notifications;
create policy "Users view own supervision notifications"
on public.supervision_notifications for select
to authenticated
using (user_id = auth.uid());

revoke insert, update, delete on public.parent_child_links from authenticated;
revoke insert, update, delete on public.screen_time_logs from authenticated;
revoke insert, update, delete on public.screen_time_sync_events from authenticated;
revoke insert, update, delete on public.screen_time_threshold_events from authenticated;
revoke insert, update, delete on public.check_ins from authenticated;
revoke insert, update, delete on public.sos_alerts from authenticated;
revoke insert, update, delete on public.supervision_notifications from authenticated;

grant select on public.parent_child_links to authenticated;
grant select on public.screen_time_logs to authenticated;
grant select on public.screen_time_sync_events to authenticated;
grant select on public.screen_time_threshold_events to authenticated;
grant select on public.check_ins to authenticated;
grant select on public.sos_alerts to authenticated;
grant select on public.supervision_notifications to authenticated;

alter table public.parent_child_links replica identity full;
alter table public.sos_alerts replica identity full;
alter table public.supervision_notifications replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'parent_child_links'
  ) then
    alter publication supabase_realtime add table public.parent_child_links;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sos_alerts'
  ) then
    alter publication supabase_realtime add table public.sos_alerts;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'supervision_notifications'
  ) then
    alter publication supabase_realtime add table public.supervision_notifications;
  end if;
end $$;

create or replace function public.submit_safety_check_in(
  p_message text,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_accuracy_meters double precision default null,
  p_location_captured_at timestamptz default null
)
returns public.check_ins
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_child_name text;
  v_check_in public.check_ins;
  v_location_status text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_message, ''))) not between 1 and 280 then
    raise exception 'Check-In message must be between 1 and 280 characters';
  end if;
  if not exists (
    select 1 from public.parent_child_links link
    where link.child_id = v_user_id and link.status = 'active'
  ) then
    raise exception 'No active parent link';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'Both latitude and longitude are required together';
  end if;

  v_location_status := case
    when p_latitude is not null then 'available'
    else 'not_requested'
  end;

  insert into public.check_ins (
    user_id, message, note, latitude, longitude, accuracy_meters,
    location_captured_at, location_status
  ) values (
    v_user_id, btrim(p_message), btrim(p_message), p_latitude, p_longitude,
    p_accuracy_meters, p_location_captured_at, v_location_status
  ) returning * into v_check_in;

  select profile.name into v_child_name
  from public.profiles profile where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, check_in_id, child_id
  )
  select link.parent_id, 'check_in_received', 'Safety Check-In',
    coalesce(v_child_name, 'Your child') || ' sent a Safety Check-In.',
    'check-in:' || v_check_in.id::text || ':' || link.parent_id::text,
    v_check_in.id, v_user_id
  from public.parent_child_links link
  where link.child_id = v_user_id and link.status = 'active';

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, check_in_id, child_id
  ) values (
    v_user_id, 'check_in_sent', 'Check-In sent',
    'Your Safety Check-In was shared with your linked parents.',
    'check-in:' || v_check_in.id::text || ':' || v_user_id::text,
    v_check_in.id, v_user_id
  );

  return v_check_in;
end;
$$;

create or replace function public.submit_sos_alert(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_accuracy_meters double precision default null,
  p_location_captured_at timestamptz default null,
  p_location_failure text default null
)
returns public.sos_alerts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_child_name text;
  v_sos public.sos_alerts;
  v_location_status text;
  v_location_failure text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.parent_child_links link
    where link.child_id = v_user_id and link.status = 'active'
  ) then
    raise exception 'No active parent link';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'Both latitude and longitude are required together';
  end if;

  v_location_status := case when p_latitude is null then 'unavailable' else 'available' end;
  v_location_failure := case
    when p_latitude is null then coalesce(nullif(btrim(p_location_failure), ''), 'Location unavailable')
    else null
  end;

  insert into public.sos_alerts (
    child_id, message, status, latitude, longitude, accuracy_meters,
    location_captured_at, location_status, location_failure
  ) values (
    v_user_id, 'Emergency SOS triggered', 'open', p_latitude, p_longitude,
    p_accuracy_meters, p_location_captured_at, v_location_status,
    v_location_failure
  ) returning * into v_sos;

  select profile.name into v_child_name
  from public.profiles profile where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, sos_id, child_id
  )
  select link.parent_id, 'sos_opened', 'SOS alert',
    coalesce(v_child_name, 'Your child') || ' sent an SOS alert.',
    'sos:' || v_sos.id::text || ':opened:' || link.parent_id::text,
    v_sos.id, v_user_id
  from public.parent_child_links link
  where link.child_id = v_user_id and link.status = 'active';

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, sos_id, child_id
  ) values (
    v_user_id, 'sos_opened', 'SOS sent',
    case when v_location_status = 'available'
      then 'Your SOS and location were shared with your linked parents.'
      else 'Your SOS was shared with your linked parents. Location unavailable.'
    end,
    'sos:' || v_sos.id::text || ':opened:' || v_user_id::text,
    v_sos.id, v_user_id
  );

  return v_sos;
end;
$$;

create or replace function public.acknowledge_sos_alert(p_sos_id uuid)
returns public.sos_alerts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_sos public.sos_alerts;
  v_parent_name text;
  v_first_acknowledgement boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.sos_alerts alert
  set status = 'acknowledged',
      acknowledged_by = v_user_id,
      acknowledged_at = now()
  where alert.id = p_sos_id
    and alert.status = 'open'
    and alert.acknowledged_by is null
    and exists (
      select 1 from public.parent_child_links link
      where link.parent_id = v_user_id
        and link.child_id = alert.child_id
        and link.status = 'active'
    )
  returning alert.* into v_sos;

  if found then
    v_first_acknowledgement := true;
  else
    select alert.* into v_sos
    from public.sos_alerts alert
    where alert.id = p_sos_id
      and exists (
        select 1 from public.parent_child_links link
        where link.parent_id = v_user_id
          and link.child_id = alert.child_id
          and link.status = 'active'
      );
    if not found then
      raise exception 'Only an active linked parent can acknowledge this SOS' using errcode = '42501';
    end if;
  end if;

  if v_first_acknowledgement then
    select profile.name into v_parent_name
    from public.profiles profile where profile.id = v_user_id;

    insert into public.supervision_notifications (
      user_id, event_type, title, body, event_key, sos_id, child_id
    )
    select recipient.user_id, 'sos_acknowledged', 'SOS acknowledged',
      coalesce(v_parent_name, 'A linked parent') || ' acknowledged the SOS.',
      'sos:' || v_sos.id::text || ':acknowledged:' || recipient.user_id::text,
      v_sos.id, v_sos.child_id
    from (
      select v_sos.child_id as user_id
      union
      select link.parent_id from public.parent_child_links link
      where link.child_id = v_sos.child_id and link.status = 'active'
    ) recipient;
  end if;

  return v_sos;
end;
$$;

create or replace function public.resolve_sos_alert(p_sos_id uuid)
returns public.sos_alerts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_sos public.sos_alerts;
  v_parent_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.sos_alerts alert
  set status = 'resolved',
      resolved_by = v_user_id,
      resolved_at = now()
  where alert.id = p_sos_id
    and alert.status = 'acknowledged'
    and exists (
      select 1 from public.parent_child_links link
      where link.parent_id = v_user_id
        and link.child_id = alert.child_id
        and link.status = 'active'
    )
  returning alert.* into v_sos;

  if not found then
    raise exception 'Only an active linked parent can resolve an acknowledged SOS';
  end if;

  select profile.name into v_parent_name
  from public.profiles profile where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, sos_id, child_id
  )
  select recipient.user_id, 'sos_resolved', 'SOS resolved',
    coalesce(v_parent_name, 'A linked parent') || ' resolved the SOS.',
    'sos:' || v_sos.id::text || ':resolved:' || recipient.user_id::text,
    v_sos.id, v_sos.child_id
  from (
    select v_sos.child_id as user_id
    union
    select link.parent_id from public.parent_child_links link
    where link.child_id = v_sos.child_id and link.status = 'active'
  ) recipient;

  return v_sos;
end;
$$;

create or replace function public.mark_supervision_notification_read(
  p_notification_id uuid
)
returns public.supervision_notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification public.supervision_notifications;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.supervision_notifications notification
  set read_at = coalesce(notification.read_at, now())
  where notification.id = p_notification_id
    and notification.user_id = auth.uid()
  returning notification.* into v_notification;

  if not found then
    raise exception 'Supervision notification not found' using errcode = '42501';
  end if;
  return v_notification;
end;
$$;

revoke all on function public.submit_safety_check_in(text, double precision, double precision, double precision, timestamptz) from public;
revoke all on function public.submit_sos_alert(double precision, double precision, double precision, timestamptz, text) from public;
revoke all on function public.acknowledge_sos_alert(uuid) from public;
revoke all on function public.resolve_sos_alert(uuid) from public;
revoke all on function public.mark_supervision_notification_read(uuid) from public;

grant execute on function public.submit_safety_check_in(text, double precision, double precision, double precision, timestamptz) to authenticated;
grant execute on function public.submit_sos_alert(double precision, double precision, double precision, timestamptz, text) to authenticated;
grant execute on function public.acknowledge_sos_alert(uuid) to authenticated;
grant execute on function public.resolve_sos_alert(uuid) to authenticated;
grant execute on function public.mark_supervision_notification_read(uuid) to authenticated;
