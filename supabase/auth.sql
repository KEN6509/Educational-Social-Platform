create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(nullif(public.profiles.name, ''), excluded.name),
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_admin = true
      and account_status = 'active'
  );
$$;

drop policy if exists "Admins can view creator requests" on public.content_creator_requests;
create policy "Admins can view creator requests"
on public.content_creator_requests for select
to authenticated
using (public.is_current_user_admin());

drop policy if exists "Admins can review creator requests" on public.content_creator_requests;
create policy "Admins can review creator requests"
on public.content_creator_requests for update
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

drop policy if exists "Admins can manage profiles" on public.profiles;
create policy "Admins can manage profiles"
on public.profiles for update
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

drop policy if exists "Admins can view reports" on public.reports;
create policy "Admins can view reports"
on public.reports for select
to authenticated
using (public.is_current_user_admin());

drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports"
on public.reports for update
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

drop policy if exists "Admins can review posts" on public.posts;
create policy "Admins can review posts"
on public.posts for update
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());

drop policy if exists "Admins can review comments" on public.comments;
create policy "Admins can review comments"
on public.comments for update
to authenticated
using (public.is_current_user_admin())
with check (public.is_current_user_admin());
