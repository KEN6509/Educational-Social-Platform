alter table public.comments
add column if not exists tagged_user_id uuid references public.profiles(id) on delete set null,
add column if not exists tagged_user_name text;

create index if not exists comments_tagged_user_idx
on public.comments (tagged_user_id)
where tagged_user_id is not null;
