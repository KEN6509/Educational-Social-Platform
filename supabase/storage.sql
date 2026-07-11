insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('images', 'images', true, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

update storage.objects
set bucket_id = 'images'
where bucket_id = 'post-images';

update public.post_images
set public_url = replace(public_url, '/storage/v1/object/public/post-images/', '/storage/v1/object/public/images/')
where public_url like '%/storage/v1/object/public/post-images/%';

drop policy if exists "Authenticated users can upload avatars" on storage.objects;
create policy "Authenticated users can upload avatars"
on storage.objects for insert
to authenticated
with check (bucket_id = 'avatars');

drop policy if exists "Authenticated users can update avatars" on storage.objects;
create policy "Authenticated users can update avatars"
on storage.objects for update
to authenticated
using (bucket_id = 'avatars')
with check (bucket_id = 'avatars');

drop policy if exists "Authenticated users can upload post images" on storage.objects;
drop policy if exists "Authenticated users can upload images" on storage.objects;
create policy "Authenticated users can upload images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'images');

drop policy if exists "Authenticated users can update post images" on storage.objects;
drop policy if exists "Authenticated users can update images" on storage.objects;
create policy "Authenticated users can update images"
on storage.objects for update
to authenticated
using (bucket_id = 'images')
with check (bucket_id = 'images');

drop policy if exists "Authenticated users can delete post images" on storage.objects;
drop policy if exists "Authenticated users can delete images" on storage.objects;
create policy "Authenticated users can delete images"
on storage.objects for delete
to authenticated
using (bucket_id = 'images');
