alter table public.comments
add column if not exists is_pinned boolean not null default false,
add column if not exists pinned_by uuid references public.profiles(id) on delete set null,
add column if not exists pinned_at timestamptz;

create index if not exists comments_post_pinned_created_idx
on public.comments (post_id, is_pinned desc, pinned_at desc, created_at);

drop policy if exists "Post authors can moderate comments" on public.comments;
create policy "Post authors can moderate comments"
on public.comments for update
to authenticated
using (
  exists (
    select 1 from public.posts p
    where p.id = post_id and p.author_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.posts p
    where p.id = post_id and p.author_id = auth.uid()
  )
);
