create extension if not exists pgcrypto;

do $$
begin
  create type public.creator_request_status as enum ('pending', 'approved', 'rejected');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.moderation_status as enum ('pending', 'approved', 'rejected', 'removed');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.link_status as enum ('pending', 'active', 'rejected', 'cancelled', 'revoked');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.report_status as enum ('pending_review', 'resolved', 'dismissed');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.sos_status as enum ('open', 'acknowledged', 'resolved');
exception
  when duplicate_object then null;
end $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text not null,
  avatar_url text,
  bio text,
  is_content_creator boolean not null default false,
  is_admin boolean not null default false,
  account_status text not null default 'active'
    check (account_status in ('active', 'suspended', 'deleted')),
  terms_version text,
  privacy_version text,
  consent_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.content_creator_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  status public.creator_request_status not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists content_creator_requests_one_pending_per_user
on public.content_creator_requests(user_id)
where status = 'pending';

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 0 and 40),
  content text not null check (char_length(content) between 0 and 1000),
  tags text[] not null default '{}',
  moderation_status public.moderation_status not null default 'pending',
  moderation_revision integer not null default 1,
  ai_toxicity_score numeric(5,4) check (ai_toxicity_score is null or ai_toxicity_score between 0 and 1),
  moderation_reason text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.post_images (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  storage_path text not null,
  public_url text,
  mime_type text check (mime_type is null or mime_type in (
    'image/png', 'image/jpeg', 'image/webp', 'image/heic', 'image/heif'
  )),
  position int not null check (position between 1 and 9),
  created_at timestamptz not null default now(),
  unique (post_id, position)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 1000),
  moderation_status public.moderation_status not null default 'pending',
  moderation_revision integer not null default 1,
  ai_toxicity_score numeric(5,4) check (ai_toxicity_score is null or ai_toxicity_score between 0 and 1),
  moderation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.content_moderation_cases (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('post', 'comment')),
  target_id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  moderation_revision integer not null check (moderation_revision > 0),
  target_snapshot jsonb not null default '{}'::jsonb,
  state text not null check (
    state in ('processing', 'admin_review', 'approved', 'rejected', 'failed', 'superseded')
  ),
  overall_risk_score numeric(5,2)
    check (overall_risk_score between 0 and 100),
  category_scores jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  user_reason text,
  provider text,
  model text,
  prompt_version text,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  claim_token uuid,
  lease_expires_at timestamptz,
  failure_code text,
  failure_message text,
  decision_source text check (decision_source in ('gemini', 'admin')),
  decided_by uuid references public.profiles(id) on delete set null,
  decision_reason text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (target_type, target_id, moderation_revision)
);

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction_type text not null default 'like' check (reaction_type in ('like', 'dislike')),
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

create table if not exists public.saves (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  target_type text not null check (target_type in ('post', 'comment', 'user')),
  target_id uuid not null,
  reason text not null check (char_length(reason) between 3 and 120),
  status public.report_status not null default 'pending_review',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parent_child_links (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid not null references public.profiles(id) on delete cascade,
  child_id uuid not null references public.profiles(id) on delete cascade,
  status public.link_status not null default 'pending',
  invite_code text unique,
  requested_by uuid references public.profiles(id) on delete set null,
  linked_at timestamptz,
  responded_at timestamptz,
  cancelled_at timestamptz,
  unlink_requested_by uuid references public.profiles(id) on delete set null,
  unlink_requested_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_id <> child_id)
);

create table if not exists public.screen_time_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.profiles(id) on delete set null,
  log_date date not null default current_date,
  minutes_used int not null check (minutes_used >= 0 and minutes_used <= 1440),
  seconds_used int not null default 0 check (seconds_used between 0 and 86400),
  source text not null default 'manual' check (source in ('manual', 'device', 'parent')),
  note text,
  created_at timestamptz not null default now(),
  unique (user_id, log_date, source)
);

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

create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mood text check (mood in ('great', 'good', 'okay', 'stressed', 'sad')),
  note text,
  message text not null check (char_length(btrim(message)) between 1 and 280),
  latitude double precision,
  longitude double precision,
  accuracy_meters double precision,
  location_captured_at timestamptz,
  location_status text not null default 'not_requested'
    check (location_status in ('not_requested', 'available', 'unavailable')),
  created_at timestamptz not null default now()
);

create table if not exists public.sos_alerts (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.profiles(id) on delete cascade,
  message text,
  status public.sos_status not null default 'open',
  acknowledged_by uuid references public.profiles(id) on delete set null,
  acknowledged_at timestamptz,
  latitude double precision,
  longitude double precision,
  accuracy_meters double precision,
  location_captured_at timestamptz,
  location_status text not null default 'unavailable'
    check (location_status in ('available', 'unavailable')),
  location_failure text,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_id, following_id),
  check (follower_id <> following_id)
);

create index if not exists profiles_created_at_idx on public.profiles(created_at desc);
create index if not exists posts_author_created_idx on public.posts(author_id, created_at desc);
create index if not exists posts_feed_idx on public.posts(moderation_status, published_at desc nulls last, created_at desc);
create index if not exists posts_tags_idx on public.posts using gin(tags);
create index if not exists post_images_post_idx on public.post_images(post_id, position);
create index if not exists comments_post_created_idx on public.comments(post_id, created_at);
create index if not exists likes_user_idx on public.likes(user_id, created_at desc);
create index if not exists saves_user_idx on public.saves(user_id, created_at desc);
create index if not exists reports_status_idx on public.reports(status, created_at desc);
create index if not exists parent_child_parent_idx on public.parent_child_links(parent_id, status);
create index if not exists parent_child_child_idx on public.parent_child_links(child_id, status);
create unique index if not exists parent_child_links_one_live_pair_idx
on public.parent_child_links (least(parent_id, child_id), greatest(parent_id, child_id))
where status in ('pending', 'active');
create index if not exists screen_time_user_date_idx on public.screen_time_logs(user_id, log_date desc);
create index if not exists screen_time_sync_user_day_idx on public.screen_time_sync_events(user_id, local_day desc);
create index if not exists screen_time_threshold_user_day_idx on public.screen_time_threshold_events(user_id, local_day desc);
create index if not exists check_ins_user_created_idx on public.check_ins(user_id, created_at desc);
create index if not exists sos_alerts_child_status_idx on public.sos_alerts(child_id, status, created_at desc);
create index if not exists supervision_notifications_user_created_idx on public.supervision_notifications(user_id, created_at desc);

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_creator_requests_updated_at on public.content_creator_requests;
create trigger set_creator_requests_updated_at
before update on public.content_creator_requests
for each row execute function public.set_updated_at();

drop trigger if exists set_posts_updated_at on public.posts;
create trigger set_posts_updated_at
before update on public.posts
for each row execute function public.set_updated_at();

drop trigger if exists set_comments_updated_at on public.comments;
create trigger set_comments_updated_at
before update on public.comments
for each row execute function public.set_updated_at();

drop trigger if exists set_reports_updated_at on public.reports;
create trigger set_reports_updated_at
before update on public.reports
for each row execute function public.set_updated_at();

drop trigger if exists set_parent_child_links_updated_at on public.parent_child_links;
create trigger set_parent_child_links_updated_at
before update on public.parent_child_links
for each row execute function public.set_updated_at();

drop trigger if exists set_sos_alerts_updated_at on public.sos_alerts;
create trigger set_sos_alerts_updated_at
before update on public.sos_alerts
for each row execute function public.set_updated_at();

create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'authenticated'
    and (
      new.is_admin is distinct from old.is_admin
      or new.is_content_creator is distinct from old.is_content_creator
      or new.account_status is distinct from old.account_status
      or new.terms_version is distinct from old.terms_version
      or new.privacy_version is distinct from old.privacy_version
      or new.consent_accepted_at is distinct from old.consent_accepted_at
    )
  then
    raise exception 'Profile privilege fields can only be changed by trusted server operations';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_profile_privilege_escalation on public.profiles;
create trigger prevent_profile_privilege_escalation
before update on public.profiles
for each row execute function public.prevent_profile_privilege_escalation();

alter table public.profiles enable row level security;
alter table public.content_creator_requests enable row level security;
alter table public.posts enable row level security;
alter table public.post_images enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.comment_likes enable row level security;
alter table public.saves enable row level security;
alter table public.shares enable row level security;
alter table public.reports enable row level security;
alter table public.parent_child_links enable row level security;
alter table public.screen_time_logs enable row level security;
alter table public.screen_time_sync_events enable row level security;
alter table public.screen_time_threshold_events enable row level security;
alter table public.check_ins enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.supervision_notifications enable row level security;
alter table public.follows enable row level security;

create or replace function public.is_profile_email_confirmed(profile_id uuid)
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1
    from auth.users
    where id = profile_id
      and email_confirmed_at is not null
  );
$$;

revoke all on function public.is_profile_email_confirmed(uuid) from public;
grant execute on function public.is_profile_email_confirmed(uuid)
  to authenticated, service_role;

drop policy if exists "Profiles are visible to signed-in users" on public.profiles;
create policy "Profiles are visible to signed-in users"
on public.profiles for select
to authenticated
using (public.is_profile_email_confirmed(id));

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "Users can request creator status" on public.content_creator_requests;
create policy "Users can request creator status"
on public.content_creator_requests for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can view own creator requests" on public.content_creator_requests;
create policy "Users can view own creator requests"
on public.content_creator_requests for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Published posts are visible" on public.posts;
create policy "Published posts are visible"
on public.posts for select
to authenticated
using (moderation_status = 'approved' or author_id = auth.uid());

drop policy if exists "Users can create own posts" on public.posts;
create policy "Users can create own posts"
on public.posts for insert
to authenticated
with check (
  author_id = auth.uid()
  and moderation_status = 'pending'
  and moderation_revision = 1
  and ai_toxicity_score is null
  and moderation_reason is null
  and reviewed_by is null
  and reviewed_at is null
  and published_at is null
);

drop policy if exists "Authors can update own non-removed posts" on public.posts;
create policy "Authors can update own non-removed posts"
on public.posts for update
to authenticated
using (author_id = auth.uid() and moderation_status <> 'removed')
with check (author_id = auth.uid());

drop policy if exists "Post images follow post visibility" on public.post_images;
create policy "Post images follow post visibility"
on public.post_images for select
to authenticated
using (
  exists (
    select 1 from public.posts p
    where p.id = post_id
      and (p.moderation_status = 'approved' or p.author_id = auth.uid())
  )
);

drop policy if exists "Authors can add images to own posts" on public.post_images;
create policy "Authors can add images to own posts"
on public.post_images for insert
to authenticated
with check (
  exists (
    select 1 from public.posts p
    where p.id = post_id and p.author_id = auth.uid()
  )
);

drop policy if exists "Visible comments on visible posts" on public.comments;
create policy "Visible comments on visible posts"
on public.comments for select
to authenticated
using (
  author_id = auth.uid()
  or (
    moderation_status = 'approved'
    and exists (
      select 1 from public.posts p
      where p.id = post_id and p.moderation_status = 'approved'
    )
  )
);

drop policy if exists "Users can create own comments" on public.comments;
create policy "Users can create own comments"
on public.comments for insert
to authenticated
with check (
  author_id = auth.uid()
  and moderation_status = 'pending'
  and moderation_revision = 1
  and ai_toxicity_score is null
  and moderation_reason is null
);

drop policy if exists "Users can update own comments" on public.comments;
create policy "Users can update own comments"
on public.comments for update
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

drop policy if exists "Users can view own likes" on public.likes;
create policy "Users can view own likes"
on public.likes for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.posts p
    where p.id = post_id and p.moderation_status = 'approved'
  )
);

drop policy if exists "Users can manage own likes" on public.likes;
create policy "Users can manage own likes"
on public.likes for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can view comment likes" on public.comment_likes;
create policy "Users can view comment likes"
on public.comment_likes for select
to authenticated
using (true);

drop policy if exists "Users can manage own comment likes" on public.comment_likes;
create policy "Users can manage own comment likes"
on public.comment_likes for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can view own saves" on public.saves;
create policy "Users can view own saves"
on public.saves for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Follows are visible to everyone" on public.follows;
create policy "Follows are visible to everyone"
on public.follows for select
to authenticated
using (true);

drop policy if exists "Users can manage own follows" on public.follows;
create policy "Users can manage own follows"
on public.follows for all
to authenticated
using (follower_id = auth.uid())
with check (follower_id = auth.uid());

drop policy if exists "Users can manage own saves" on public.saves;
create policy "Users can manage own saves"
on public.saves for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can view shares" on public.shares;
create policy "Users can view shares"
on public.shares for select
to authenticated
using (true);

drop policy if exists "Users can record own shares" on public.shares;
create policy "Users can record own shares"
on public.shares for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users can submit reports" on public.reports;
create policy "Users can submit reports"
on public.reports for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists "Users can view own reports" on public.reports;
create policy "Users can view own reports"
on public.reports for select
to authenticated
using (reporter_id = auth.uid());

drop policy if exists "Linked family can view links" on public.parent_child_links;
create policy "Linked family can view links"
on public.parent_child_links for select
to authenticated
using (parent_id = auth.uid() or child_id = auth.uid());

drop policy if exists "Users can request family links" on public.parent_child_links;
create policy "Users can request family links"
on public.parent_child_links for insert
to authenticated
with check (parent_id = auth.uid() or child_id = auth.uid());

drop policy if exists "Linked family can update links" on public.parent_child_links;
create policy "Linked family can update links"
on public.parent_child_links for update
to authenticated
using (parent_id = auth.uid() or child_id = auth.uid())
with check (parent_id = auth.uid() or child_id = auth.uid());

drop policy if exists "Family can view screen time" on public.screen_time_logs;
create policy "Family can view screen time"
on public.screen_time_logs for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = screen_time_logs.user_id
      and pcl.status = 'active'
  )
);

drop policy if exists "Family can add screen time" on public.screen_time_logs;
create policy "Family can add screen time"
on public.screen_time_logs for insert
to authenticated
with check (
  user_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = screen_time_logs.user_id
      and pcl.status = 'active'
  )
);

drop policy if exists "Family can view check-ins" on public.check_ins;
create policy "Family can view check-ins"
on public.check_ins for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = check_ins.user_id
      and pcl.status = 'active'
  )
);

drop policy if exists "Users can create own check-ins" on public.check_ins;
create policy "Users can create own check-ins"
on public.check_ins for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Family can view sos alerts" on public.sos_alerts;
create policy "Family can view sos alerts"
on public.sos_alerts for select
to authenticated
using (
  child_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = sos_alerts.child_id
      and pcl.status = 'active'
  )
);

drop policy if exists "Children can create sos alerts" on public.sos_alerts;
create policy "Children can create sos alerts"
on public.sos_alerts for insert
to authenticated
with check (child_id = auth.uid());

drop policy if exists "Linked parents can update sos alerts" on public.sos_alerts;
create policy "Linked parents can update sos alerts"
on public.sos_alerts for update
to authenticated
using (
  exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = sos_alerts.child_id
      and pcl.status = 'active'
  )
)
with check (
  exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = sos_alerts.child_id
      and pcl.status = 'active'
  )
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'posts'
  ) then
    alter publication supabase_realtime add table public.posts;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'comments'
  ) then
    alter publication supabase_realtime add table public.comments;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'likes'
  ) then
    alter publication supabase_realtime add table public.likes;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'parent_child_links'
  ) then
    alter publication supabase_realtime add table public.parent_child_links;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sos_alerts'
  ) then
    alter publication supabase_realtime add table public.sos_alerts;
  end if;
end $$;

-- STORAGE POLICIES
-- Note: Buckets must be created manually or via dashboard before policies apply.
-- Assuming 'avatars' and 'images' buckets exist.

-- Avatars Bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Avatar images are publicly accessible" on storage.objects;
create policy "Avatar images are publicly accessible"
on storage.objects for select
using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
on storage.objects for insert
with check (
  bucket_id = 'avatars' 
  and (auth.uid())::text = (storage.foldername(name))[1]
);

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
on storage.objects for update
using (
  bucket_id = 'avatars' 
  and (auth.uid())::text = (storage.foldername(name))[1]
);

drop policy if exists "Users can delete their own avatar" on storage.objects;
create policy "Users can delete their own avatar"
on storage.objects for delete
using (
  bucket_id = 'avatars' 
  and (auth.uid())::text = (storage.foldername(name))[1]
);

-- Shared Images Bucket
insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do nothing;

drop policy if exists "Images are publicly accessible" on storage.objects;
create policy "Images are publicly accessible"
on storage.objects for select
using (bucket_id = 'images');

drop policy if exists "Users can upload their own post images" on storage.objects;
drop policy if exists "Authenticated users can upload images" on storage.objects;
create policy "Authenticated users can upload images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'images'
  and (
    (storage.foldername(name))[1] = (auth.uid())::text
    or (
      (storage.foldername(name))[1] = 'chat'
      and (storage.foldername(name))[2] = (auth.uid())::text
    )
  )
);

drop policy if exists "Users can update their own post images" on storage.objects;
drop policy if exists "Authenticated users can update images" on storage.objects;

drop policy if exists "Users can delete their own post images" on storage.objects;
drop policy if exists "Authenticated users can delete images" on storage.objects;
create policy "Authenticated users can delete images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'images'
  and (
    (storage.foldername(name))[1] = (auth.uid())::text
    or (
      (storage.foldername(name))[1] = 'chat'
      and (storage.foldername(name))[2] = (auth.uid())::text
    )
  )
);

-- 1. Fix Title Constraint
ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_title_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_title_check CHECK (char_length(title) BETWEEN 0 AND 40);

-- 2. Fix Content Constraint
ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_content_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_content_check CHECK (char_length(content) BETWEEN 0 AND 1000);

-- profile Saved/Liked visibility.
drop policy if exists "Users can view own saves" on public.saves;
create policy "Users can view own saves"
on public.saves for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.posts p
    where p.id = post_id and p.moderation_status = 'approved'
  )
);

-- Canonical Parent Supervision server-authoritative contract.
-- Keep synchronized with parent_supervision.sql for existing projects.

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

create or replace function public.request_parent_child_unlink(p_link_id uuid)
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
    raise exception 'Family link not found';
  end if;
  if v_link.status <> 'active' then
    raise exception 'Only active family links can request unlink';
  end if;
  if v_link.parent_id <> v_user_id and v_link.child_id <> v_user_id then
    raise exception 'Only linked family members can request unlink' using errcode = '42501';
  end if;
  if v_link.unlink_requested_by is not null then
    raise exception 'Unlink request already pending';
  end if;

  v_recipient_id := case
    when v_link.parent_id = v_user_id then v_link.child_id
    else v_link.parent_id
  end;

  update public.parent_child_links
  set unlink_requested_by = v_user_id,
      unlink_requested_at = now()
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
    'Family unlink request',
    coalesce(v_requester_name, 'A family member') || ' requested to unlink this family relationship.',
    'link:' || v_link.id::text || ':unlink_requested:' || v_recipient_id::text,
    v_link.id,
    v_link.child_id
  );

  return v_link;
end;
$$;

create or replace function public.accept_parent_child_unlink(p_link_id uuid)
returns public.parent_child_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_link public.parent_child_links;
  v_requester_id uuid;
  v_responder_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_link
  from public.parent_child_links link
  where link.id = p_link_id
  for update;

  if not found then
    raise exception 'Unlink request not found';
  end if;
  if v_link.status <> 'active' or v_link.unlink_requested_by is null then
    raise exception 'No unlink request is pending';
  end if;
  if v_link.unlink_requested_by = v_user_id then
    raise exception 'The requester cannot approve their own unlink request';
  end if;
  if v_link.parent_id <> v_user_id and v_link.child_id <> v_user_id then
    raise exception 'Only linked family members can approve unlink' using errcode = '42501';
  end if;

  v_requester_id := v_link.unlink_requested_by;

  update public.parent_child_links
  set status = 'revoked',
      revoked_at = now(),
      responded_at = now()
  where id = v_link.id
  returning * into v_link;

  select profile.name into v_responder_name
  from public.profiles profile
  where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, link_id, child_id
  ) values (
    v_requester_id,
    'link_cancelled',
    'Family link ended',
    coalesce(v_responder_name, 'Your family member') || ' approved the unlink request.',
    'link:' || v_link.id::text || ':unlink_approved:' || v_requester_id::text,
    v_link.id,
    v_link.child_id
  );

  return v_link;
end;
$$;

create or replace function public.reject_parent_child_unlink(p_link_id uuid)
returns public.parent_child_links
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_link public.parent_child_links;
  v_requester_id uuid;
  v_responder_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_link
  from public.parent_child_links link
  where link.id = p_link_id
  for update;

  if not found then
    raise exception 'Unlink request not found';
  end if;
  if v_link.status <> 'active' or v_link.unlink_requested_by is null then
    raise exception 'No unlink request is pending';
  end if;
  if v_link.unlink_requested_by = v_user_id then
    raise exception 'The requester cannot reject their own unlink request';
  end if;
  if v_link.parent_id <> v_user_id and v_link.child_id <> v_user_id then
    raise exception 'Only linked family members can reject unlink' using errcode = '42501';
  end if;

  v_requester_id := v_link.unlink_requested_by;

  update public.parent_child_links
  set unlink_requested_by = null,
      unlink_requested_at = null,
      responded_at = now()
  where id = v_link.id
  returning * into v_link;

  select profile.name into v_responder_name
  from public.profiles profile
  where profile.id = v_user_id;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, link_id, child_id
  ) values (
    v_requester_id,
    'link_rejected',
    'Unlink request declined',
    coalesce(v_responder_name, 'Your family member') || ' declined the unlink request.',
    'link:' || v_link.id::text || ':unlink_rejected:' || v_requester_id::text,
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
revoke all on function public.request_parent_child_unlink(uuid) from public;
revoke all on function public.accept_parent_child_unlink(uuid) from public;
revoke all on function public.reject_parent_child_unlink(uuid) from public;

grant execute on function public.create_parent_child_link(uuid, text)
to authenticated;
grant execute on function public.accept_parent_child_link(uuid)
to authenticated;
grant execute on function public.reject_parent_child_link(uuid)
to authenticated;
grant execute on function public.cancel_parent_child_link(uuid)
to authenticated;
grant execute on function public.request_parent_child_unlink(uuid)
to authenticated;
grant execute on function public.accept_parent_child_unlink(uuid)
to authenticated;
grant execute on function public.reject_parent_child_unlink(uuid)
to authenticated;

alter table public.parent_child_links
  add column if not exists responded_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists unlink_requested_by uuid references public.profiles(id) on delete set null,
  add column if not exists unlink_requested_at timestamptz;

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

create table if not exists public.sos_live_locations (
  sos_id uuid primary key references public.sos_alerts(id) on delete cascade,
  child_id uuid not null references public.profiles(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_meters double precision not null default 0
    check (accuracy_meters >= 0),
  captured_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.sos_events (
  id uuid primary key default gen_random_uuid(),
  sos_id uuid not null references public.sos_alerts(id) on delete cascade,
  event_type text not null
    check (event_type in ('triggered', 'acknowledged', 'resolved')),
  actor_user_id uuid not null references public.profiles(id) on delete restrict,
  actor_name text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists sos_events_one_trigger_idx
on public.sos_events (sos_id)
where event_type = 'triggered';

create unique index if not exists sos_events_one_parent_ack_idx
on public.sos_events (sos_id, actor_user_id)
where event_type = 'acknowledged';

create unique index if not exists sos_events_one_resolution_idx
on public.sos_events (sos_id)
where event_type = 'resolved';

create index if not exists sos_events_sos_created_idx
on public.sos_events (sos_id, created_at);

insert into public.sos_live_locations (
  sos_id, child_id, latitude, longitude, accuracy_meters, captured_at, updated_at
)
select alert.id, alert.child_id, alert.latitude, alert.longitude,
  coalesce(alert.accuracy_meters, 0),
  coalesce(alert.location_captured_at, alert.created_at),
  coalesce(alert.updated_at, alert.created_at)
from public.sos_alerts alert
where alert.location_status = 'available'
  and alert.latitude is not null
  and alert.longitude is not null
on conflict (sos_id) do nothing;

insert into public.sos_events (
  sos_id, event_type, actor_user_id, actor_name, created_at
)
select alert.id, 'triggered', alert.child_id,
  coalesce(profile.name, 'CyanZone child'), alert.created_at
from public.sos_alerts alert
left join public.profiles profile on profile.id = alert.child_id
on conflict (sos_id) where event_type = 'triggered' do nothing;

insert into public.sos_events (
  sos_id, event_type, actor_user_id, actor_name, created_at
)
select alert.id, 'acknowledged', alert.acknowledged_by,
  coalesce(profile.name, 'Linked parent'),
  coalesce(alert.acknowledged_at, alert.updated_at, alert.created_at)
from public.sos_alerts alert
left join public.profiles profile on profile.id = alert.acknowledged_by
where alert.acknowledged_by is not null
on conflict (sos_id, actor_user_id)
where event_type = 'acknowledged' do nothing;

insert into public.sos_events (
  sos_id, event_type, actor_user_id, actor_name, created_at
)
select alert.id, 'resolved', alert.resolved_by,
  coalesce(profile.name, 'Linked parent'),
  coalesce(alert.resolved_at, alert.updated_at, alert.created_at)
from public.sos_alerts alert
left join public.profiles profile on profile.id = alert.resolved_by
where alert.resolved_by is not null
on conflict (sos_id) where event_type = 'resolved' do nothing;

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
alter table public.sos_live_locations enable row level security;
alter table public.sos_events enable row level security;

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

drop policy if exists "Active family views SOS live locations"
on public.sos_live_locations;
create policy "Active family views SOS live locations"
on public.sos_live_locations for select
to authenticated
using (
  child_id = auth.uid()
  or exists (
    select 1
    from public.parent_child_links link
    where link.parent_id = auth.uid()
      and link.child_id = sos_live_locations.child_id
      and link.status = 'active'
  )
);

drop policy if exists "Active family views SOS events"
on public.sos_events;
create policy "Active family views SOS events"
on public.sos_events for select
to authenticated
using (
  exists (
    select 1
    from public.sos_alerts alert
    where alert.id = sos_events.sos_id
      and (
        alert.child_id = auth.uid()
        or exists (
          select 1
          from public.parent_child_links link
          where link.parent_id = auth.uid()
            and link.child_id = alert.child_id
            and link.status = 'active'
        )
      )
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
revoke insert, update, delete on public.sos_live_locations from authenticated;
revoke insert, update, delete on public.sos_events from authenticated;
revoke insert, update, delete on public.supervision_notifications from authenticated;

grant select on public.parent_child_links to authenticated;
grant select on public.screen_time_logs to authenticated;
grant select on public.screen_time_sync_events to authenticated;
grant select on public.screen_time_threshold_events to authenticated;
grant select on public.check_ins to authenticated;
grant select on public.sos_alerts to authenticated;
grant select on public.sos_live_locations to authenticated;
grant select on public.sos_events to authenticated;
grant select on public.supervision_notifications to authenticated;

alter table public.parent_child_links replica identity full;
alter table public.sos_alerts replica identity full;
alter table public.sos_live_locations replica identity full;
alter table public.sos_events replica identity full;
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
      and tablename = 'sos_live_locations'
  ) then
    alter publication supabase_realtime add table public.sos_live_locations;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'sos_events'
  ) then
    alter publication supabase_realtime add table public.sos_events;
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

  insert into public.sos_events (
    sos_id, event_type, actor_user_id, actor_name, created_at
  ) values (
    v_sos.id, 'triggered', v_user_id,
    coalesce(v_child_name, 'CyanZone child'), v_sos.created_at
  );

  if v_location_status = 'available' then
    insert into public.sos_live_locations (
      sos_id, child_id, latitude, longitude, accuracy_meters, captured_at
    ) values (
      v_sos.id, v_user_id, p_latitude, p_longitude,
      coalesce(p_accuracy_meters, 0),
      coalesce(p_location_captured_at, now())
    );
  end if;

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
  v_event_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select alert.* into v_sos
  from public.sos_alerts alert
  where alert.id = p_sos_id
    and exists (
      select 1 from public.parent_child_links link
      where link.parent_id = v_user_id
        and link.child_id = alert.child_id
        and link.status = 'active'
    )
  for update;

  if not found then
    raise exception 'Only an active linked parent can acknowledge this SOS' using errcode = '42501';
  end if;
  if v_sos.status = 'resolved' then
    return v_sos;
  end if;

  select profile.name into v_parent_name
  from public.profiles profile where profile.id = v_user_id;

  insert into public.sos_events (
    sos_id, event_type, actor_user_id, actor_name
  ) values (
    v_sos.id, 'acknowledged', v_user_id,
    coalesce(v_parent_name, 'Linked parent')
  )
  on conflict (sos_id, actor_user_id)
  where event_type = 'acknowledged' do nothing
  returning id into v_event_id;

  if v_event_id is null then
    return v_sos;
  end if;

  update public.sos_alerts alert
  set status = case
        when alert.status = 'open' then 'acknowledged'
        else alert.status
      end,
      acknowledged_by = coalesce(alert.acknowledged_by, v_user_id),
      acknowledged_at = coalesce(alert.acknowledged_at, now())
  where alert.id = p_sos_id
    and alert.status in ('open', 'acknowledged')
  returning alert.* into v_sos;

  insert into public.supervision_notifications (
    user_id, event_type, title, body, event_key, sos_id, child_id
  )
  select recipient.user_id, 'sos_acknowledged', 'SOS acknowledged',
    coalesce(v_parent_name, 'A linked parent') || ' acknowledged the SOS.',
    'sos:' || v_sos.id::text || ':acknowledged:' || v_user_id::text || ':' ||
      recipient.user_id::text,
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

  select alert.* into v_sos
  from public.sos_alerts alert
  where alert.id = p_sos_id
    and exists (
      select 1 from public.parent_child_links link
      where link.parent_id = v_user_id
        and link.child_id = alert.child_id
        and link.status = 'active'
    )
  for update;

  if not found then
    raise exception 'Only an active linked parent can resolve this SOS' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.sos_events event
    where event.sos_id = p_sos_id
      and event.event_type = 'acknowledged'
      and event.actor_user_id = v_user_id
  ) then
    raise exception 'Current parent must acknowledge before resolving';
  end if;
  if v_sos.status = 'resolved' then
    return v_sos;
  end if;

  update public.sos_alerts alert
  set status = 'resolved',
      resolved_by = v_user_id,
      resolved_at = now()
  where alert.id = p_sos_id
    and alert.status in ('open', 'acknowledged')
  returning alert.* into v_sos;

  select profile.name into v_parent_name
  from public.profiles profile where profile.id = v_user_id;

  insert into public.sos_events (
    sos_id, event_type, actor_user_id, actor_name
  ) values (
    v_sos.id, 'resolved', v_user_id,
    coalesce(v_parent_name, 'Linked parent')
  )
  on conflict (sos_id) where event_type = 'resolved' do nothing;

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

create or replace function public.update_sos_live_location(
  p_sos_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision,
  p_location_captured_at timestamptz
)
returns public.sos_live_locations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_sos public.sos_alerts;
  v_location public.sos_live_locations;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_latitude is null or p_longitude is null
      or p_latitude not between -90 and 90
      or p_longitude not between -180 and 180 then
    raise exception 'Invalid SOS location';
  end if;

  select alert.* into v_sos
  from public.sos_alerts alert
  where alert.id = p_sos_id
    and alert.child_id = v_user_id
    and alert.status in ('open', 'acknowledged')
  for update;

  if not found then
    raise exception 'Only the child can update an unresolved SOS location'
      using errcode = '42501';
  end if;

  insert into public.sos_live_locations (
    sos_id, child_id, latitude, longitude, accuracy_meters,
    captured_at, updated_at
  ) values (
    p_sos_id, v_user_id, p_latitude, p_longitude,
    greatest(coalesce(p_accuracy_meters, 0), 0),
    coalesce(p_location_captured_at, now()), now()
  )
  on conflict (sos_id) do update
  set latitude = excluded.latitude,
      longitude = excluded.longitude,
      accuracy_meters = excluded.accuracy_meters,
      captured_at = excluded.captured_at,
      updated_at = now()
  returning * into v_location;

  update public.sos_alerts alert
  set latitude = v_location.latitude,
      longitude = v_location.longitude,
      accuracy_meters = v_location.accuracy_meters,
      location_captured_at = v_location.captured_at,
      location_status = 'available',
      location_failure = null
  where alert.id = p_sos_id;

  return v_location;
end;
$$;

create or replace function public.fetch_active_sos_alert()
returns setof public.sos_alerts
language sql
stable
security definer
set search_path = public
as $$
  select alert.*
  from public.sos_alerts alert
  where alert.child_id = auth.uid()
    and alert.status in ('open', 'acknowledged')
  order by alert.created_at desc
  limit 1;
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
revoke all on function public.update_sos_live_location(uuid, double precision, double precision, double precision, timestamptz) from public;
revoke all on function public.fetch_active_sos_alert() from public;
revoke all on function public.mark_supervision_notification_read(uuid) from public;

grant execute on function public.submit_safety_check_in(text, double precision, double precision, double precision, timestamptz) to authenticated;
grant execute on function public.submit_sos_alert(double precision, double precision, double precision, timestamptz, text) to authenticated;
grant execute on function public.acknowledge_sos_alert(uuid) to authenticated;
grant execute on function public.resolve_sos_alert(uuid) to authenticated;
grant execute on function public.update_sos_live_location(uuid, double precision, double precision, double precision, timestamptz) to authenticated;
grant execute on function public.fetch_active_sos_alert() to authenticated;
grant execute on function public.mark_supervision_notification_read(uuid) to authenticated;

create or replace function public.sync_screen_time_session(
  p_client_session_id text,
  p_local_day date,
  p_seconds_used integer,
  p_timezone_offset_minutes integer
)
returns table (
  daily_seconds integer,
  next_threshold_hours integer,
  applied boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_applied_count integer := 0;
  v_threshold_inserted integer := 0;
  v_total_seconds integer := 0;
  v_threshold integer;
  v_user_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if nullif(btrim(p_client_session_id), '') is null then
    raise exception 'Client session ID is required';
  end if;
  if p_local_day is null or p_local_day > current_date + 1 then
    raise exception 'Invalid local screen-time day';
  end if;
  if p_seconds_used not between 1 and 86400 then
    raise exception 'Screen-time seconds must be between 1 and 86400';
  end if;
  if p_timezone_offset_minutes not between -840 and 840 then
    raise exception 'Invalid timezone offset';
  end if;

  insert into public.screen_time_sync_events (
    user_id, client_session_id, local_day, seconds_used,
    timezone_offset_minutes
  ) values (
    v_user_id, btrim(p_client_session_id), p_local_day, p_seconds_used,
    p_timezone_offset_minutes
  )
  on conflict (user_id, client_session_id) do nothing;
  get diagnostics v_applied_count = row_count;

  if v_applied_count = 1 then
    insert into public.screen_time_logs (
      user_id, log_date, minutes_used, seconds_used, source
    ) values (
      v_user_id, p_local_day, p_seconds_used / 60, p_seconds_used, 'device'
    )
    on conflict (user_id, log_date, source) do update
    set seconds_used = least(
          86400,
          public.screen_time_logs.seconds_used + excluded.seconds_used
        ),
        minutes_used = least(
          1440,
          (public.screen_time_logs.seconds_used + excluded.seconds_used) / 60
        );
  end if;

  select coalesce(log.seconds_used, 0)
  into v_total_seconds
  from public.screen_time_logs log
  where log.user_id = v_user_id
    and log.log_date = p_local_day
    and log.source = 'device';
  v_total_seconds := coalesce(v_total_seconds, 0);

  if v_applied_count = 1 and v_total_seconds >= 10800 then
    select profile.name into v_user_name
    from public.profiles profile where profile.id = v_user_id;

    for v_threshold in
      select generate_series(3, v_total_seconds / 3600)
    loop
      insert into public.screen_time_threshold_events (
        user_id, local_day, threshold_hours
      ) values (
        v_user_id, p_local_day, v_threshold
      ) on conflict (user_id, local_day, threshold_hours) do nothing;
      get diagnostics v_threshold_inserted = row_count;

      if v_threshold_inserted = 1 then
        insert into public.supervision_notifications (
          user_id, event_type, title, body, event_key, child_id,
          threshold_hours
        )
        select recipient.user_id, 'screen_time_threshold',
          'Screen-time update',
          coalesce(v_user_name, 'A family member') || ' reached ' ||
            v_threshold::text || ' hours in CyanZone today.',
          'screen-time:' || v_user_id::text || ':' || p_local_day::text || ':' ||
            v_threshold::text || ':' || recipient.user_id::text,
          v_user_id, v_threshold
        from (
          select v_user_id as user_id
          union
          select link.parent_id
          from public.parent_child_links link
          where link.child_id = v_user_id and link.status = 'active'
        ) recipient;
      end if;
    end loop;
  end if;

  return query select
    v_total_seconds,
    greatest(3, (v_total_seconds / 3600) + 1),
    v_applied_count = 1;
end;
$$;

revoke all on function public.sync_screen_time_session(text, date, integer, integer)
from public;
grant execute on function public.sync_screen_time_session(text, date, integer, integer)
to authenticated;
