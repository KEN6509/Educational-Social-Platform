-- Phase 4 follow/profile interaction support.
-- Safe to run after supabase/schema.sql.

create index if not exists follows_follower_created_idx
on public.follows (follower_id, created_at desc);

create index if not exists follows_following_created_idx
on public.follows (following_id, created_at desc);

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
with check (follower_id = auth.uid() and following_id <> auth.uid());
