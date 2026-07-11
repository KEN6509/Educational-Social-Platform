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
  create type public.link_status as enum ('pending', 'active', 'rejected', 'revoked');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
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
  moderation_status public.moderation_status not null default 'approved', -- Temporary: auto-approve for testing
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
  moderation_status public.moderation_status not null default 'approved', -- Temporary: auto-approve for testing
  ai_toxicity_score numeric(5,4) check (ai_toxicity_score is null or ai_toxicity_score between 0 and 1),
  moderation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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
  description text,
  status public.report_status not null default 'open',
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
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_id <> child_id),
  unique (parent_id, child_id)
);

create table if not exists public.screen_time_logs (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.profiles(id) on delete set null,
  log_date date not null default current_date,
  minutes_used int not null check (minutes_used >= 0 and minutes_used <= 1440),
  source text not null default 'manual' check (source in ('manual', 'device', 'parent')),
  note text,
  created_at timestamptz not null default now(),
  unique (child_id, log_date, source)
);

create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mood text not null check (mood in ('great', 'good', 'okay', 'stressed', 'sad')),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.sos_alerts (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.profiles(id) on delete cascade,
  message text,
  status public.sos_status not null default 'open',
  acknowledged_by uuid references public.profiles(id) on delete set null,
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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
create index if not exists screen_time_child_date_idx on public.screen_time_logs(child_id, log_date desc);
create index if not exists check_ins_user_created_idx on public.check_ins(user_id, created_at desc);
create index if not exists sos_alerts_child_status_idx on public.sos_alerts(child_id, status, created_at desc);

-- TEMPORARY: Approve existing pending content for testing
-- Run these in Supabase SQL Editor if you have existing data
update public.posts set moderation_status = 'approved' where moderation_status = 'pending';
update public.comments set moderation_status = 'approved' where moderation_status = 'pending';

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
alter table public.check_ins enable row level security;
alter table public.sos_alerts enable row level security;
alter table public.follows enable row level security;

drop policy if exists "Profiles are visible to signed-in users" on public.profiles;
create policy "Profiles are visible to signed-in users"
on public.profiles for select
to authenticated
using (true);

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
with check (author_id = auth.uid());

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
with check (author_id = auth.uid());

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
  child_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = screen_time_logs.child_id
      and pcl.status = 'active'
  )
);

drop policy if exists "Family can add screen time" on public.screen_time_logs;
create policy "Family can add screen time"
on public.screen_time_logs for insert
to authenticated
with check (
  child_id = auth.uid()
  or exists (
    select 1 from public.parent_child_links pcl
    where pcl.parent_id = auth.uid()
      and pcl.child_id = screen_time_logs.child_id
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
with check (bucket_id = 'images');

drop policy if exists "Users can update their own post images" on storage.objects;
drop policy if exists "Authenticated users can update images" on storage.objects;
create policy "Authenticated users can update images"
on storage.objects for update
to authenticated
using (bucket_id = 'images')
with check (bucket_id = 'images');

drop policy if exists "Users can delete their own post images" on storage.objects;
drop policy if exists "Authenticated users can delete images" on storage.objects;
create policy "Authenticated users can delete images"
on storage.objects for delete
to authenticated
using (bucket_id = 'images');

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
