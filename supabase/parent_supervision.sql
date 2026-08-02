-- Parent Supervision foundation migration.
-- Apply this complete file after schema.sql in the Supabase SQL Editor.

do $$
begin
  alter type public.link_status add value 'cancelled';
exception
  when duplicate_object then null;
end $$;

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
