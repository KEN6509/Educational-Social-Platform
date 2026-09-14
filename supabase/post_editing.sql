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
