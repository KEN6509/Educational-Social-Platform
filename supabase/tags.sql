-- The tag-request workflow is not implemented by the mobile app or
-- Administration Portal. Remove the obsolete table if an older version of
-- this migration created it.
drop table if exists public.tag_requests;

create table if not exists public.tag_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  position int not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.tag_categories(id) on delete cascade,
  name text not null,
  slug text not null unique,
  position int not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (category_id, name),
  unique (category_id, position)
);

create index if not exists tags_category_position_idx
on public.tags(category_id, position);

create index if not exists tags_active_slug_idx
on public.tags(is_active, slug);

drop trigger if exists set_tags_updated_at on public.tags;
create trigger set_tags_updated_at
before update on public.tags
for each row execute function public.set_updated_at();

alter table public.tag_categories enable row level security;
alter table public.tags enable row level security;

drop policy if exists "Signed-in users can view tag categories" on public.tag_categories;
create policy "Signed-in users can view tag categories"
on public.tag_categories for select
to authenticated
using (true);

drop policy if exists "Admins can manage tag categories" on public.tag_categories;
create policy "Admins can manage tag categories"
on public.tag_categories for all
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

drop policy if exists "Signed-in users can view active tags" on public.tags;
create policy "Signed-in users can view active tags"
on public.tags for select
to authenticated
using (is_active = true);

drop policy if exists "Admins can manage tags" on public.tags;
create policy "Admins can manage tags"
on public.tags for all
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

insert into public.tag_categories (name, position)
values
  ('Academic Subjects', 1),
  ('Sports', 2),
  ('Music', 3),
  ('Creative Arts', 4)
on conflict (name) do update set position = excluded.position;

with category as (
  select id, name from public.tag_categories
),
seed(name, category_name, slug, position) as (
  values
    ('English', 'Academic Subjects', 'english', 1),
    ('Malay', 'Academic Subjects', 'malay', 2),
    ('Chinese', 'Academic Subjects', 'chinese', 3),
    ('Tamil', 'Academic Subjects', 'tamil', 4),
    ('Mathematics', 'Academic Subjects', 'mathematics', 5),
    ('Additional Mathematics', 'Academic Subjects', 'additional-mathematics', 6),
    ('Physics', 'Academic Subjects', 'physics', 7),
    ('Chemistry', 'Academic Subjects', 'chemistry', 8),
    ('Biology', 'Academic Subjects', 'biology', 9),
    ('General Science', 'Academic Subjects', 'general-science', 10),
    ('History', 'Academic Subjects', 'history', 11),
    ('Geography', 'Academic Subjects', 'geography', 12),
    ('Visual Arts', 'Academic Subjects', 'visual-arts', 13),
    ('Accounting', 'Academic Subjects', 'accounting', 14),
    ('Economics', 'Academic Subjects', 'economics', 15),
    ('Business Studies', 'Academic Subjects', 'business-studies', 16),
    ('Marketing', 'Academic Subjects', 'marketing', 17),
    ('Basketball', 'Sports', 'basketball', 1),
    ('Football', 'Sports', 'football', 2),
    ('Badminton', 'Sports', 'badminton', 3),
    ('Volleyball', 'Sports', 'volleyball', 4),
    ('Tennis', 'Sports', 'tennis', 5),
    ('Ping Pong', 'Sports', 'ping-pong', 6),
    ('Fitness', 'Sports', 'fitness', 7),
    ('Taekwondo', 'Sports', 'taekwondo', 8),
    ('Karate', 'Sports', 'karate', 9),
    ('Silat', 'Sports', 'silat', 10),
    ('Chess', 'Sports', 'chess', 11),
    ('Guitar', 'Music', 'guitar', 1),
    ('Piano', 'Music', 'piano', 2),
    ('Singing', 'Music', 'singing', 3),
    ('Vocal Training', 'Music', 'vocal-training', 4),
    ('Photography', 'Creative Arts', 'photography', 1),
    ('Videography', 'Creative Arts', 'videography', 2),
    ('Graphic Design', 'Creative Arts', 'graphic-design', 3),
    ('Animation', 'Creative Arts', 'animation', 4)
)
insert into public.tags (category_id, name, slug, position)
select category.id, seed.name, seed.slug, seed.position
from seed
join category on category.name = seed.category_name
on conflict (slug) do update set
  name = excluded.name,
  category_id = excluded.category_id,
  position = excluded.position,
  is_active = true;
