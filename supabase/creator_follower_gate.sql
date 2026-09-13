-- Temporary MVP/UAT creator-application gate for an existing CyanZone project.
-- Safe to run after schema.sql and follow.sql. Existing requests are preserved.

create or replace function public.submit_creator_verification_request(
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_follower_count bigint;
  v_is_content_creator boolean;
  v_account_status text;
  v_request_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if char_length(v_reason) not between 1 and 500 then
    raise exception 'Application statement must be between 1 and 500 characters';
  end if;

  select profile.is_content_creator, profile.account_status
  into v_is_content_creator, v_account_status
  from public.profiles profile
  where profile.id = v_user_id
  for update;

  if not found or v_account_status <> 'active' then
    raise exception 'An active profile is required' using errcode = '42501';
  end if;

  if v_is_content_creator then
    raise exception 'This account is already a verified creator';
  end if;

  select count(*)
  into v_follower_count
  from public.follows
  where following_id = v_user_id;

  if v_follower_count < 2 then
    raise exception 'At least 2 followers are required';
  end if;

  if exists (
    select 1
    from public.content_creator_requests request
    where request.user_id = v_user_id
      and request.status = 'pending'
  ) then
    raise exception 'A creator application is already pending';
  end if;

  insert into public.content_creator_requests (user_id, reason)
  values (v_user_id, v_reason)
  returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_creator_verification_request(text) from public;
grant execute on function public.submit_creator_verification_request(text) to authenticated;

drop policy if exists "Users can request creator status"
on public.content_creator_requests;
create policy "Users can request creator status"
on public.content_creator_requests for insert
to authenticated
with check (
  user_id = auth.uid()
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and admin_note is null
  and exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.account_status = 'active'
      and not profile.is_content_creator
  )
  and 2 <= (
    select count(*)
    from public.follows follow_row
    where follow_row.following_id = auth.uid()
  )
);

-- Verification only: these queries do not change data.
select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name = 'submit_creator_verification_request';

select policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename = 'content_creator_requests'
  and policyname = 'Users can request creator status';
