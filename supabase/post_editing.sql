drop policy if exists "Authors can update images on own posts" on public.post_images;
create policy "Authors can update images on own posts"
on public.post_images for update
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

drop policy if exists "Authors can delete images on own posts" on public.post_images;
create policy "Authors can delete images on own posts"
on public.post_images for delete
to authenticated
using (
  exists (
    select 1 from public.posts p
    where p.id = post_id and p.author_id = auth.uid()
  )
);

create or replace function public.delete_old_rejected_posts()
returns void
language sql
security definer
set search_path = public
as $$
  update public.posts
  set moderation_status = 'removed',
      updated_at = now()
  where moderation_status = 'rejected'
    and reviewed_at is not null
    and reviewed_at < now() - interval '7 days';
$$;

do $$
begin
  create extension if not exists pg_cron with schema extensions;

  if not exists (
    select 1 from cron.job where jobname = 'delete-old-rejected-posts'
  ) then
    perform cron.schedule(
      'delete-old-rejected-posts',
      '17 3 * * *',
      'select public.delete_old_rejected_posts();'
    );
  end if;
exception
  when others then
    raise notice 'pg_cron is not available; schedule public.delete_old_rejected_posts() daily.';
end
$$;
