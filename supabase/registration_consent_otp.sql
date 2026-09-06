-- CyanZone registration consent and email OTP migration.
-- Safe to rerun after schema.sql and the existing auth trigger setup.

alter table public.profiles
  add column if not exists terms_version text,
  add column if not exists privacy_version text,
  add column if not exists consent_accepted_at timestamptz;

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
      or new.terms_version is distinct from old.terms_version
      or new.privacy_version is distinct from old.privacy_version
      or new.consent_accepted_at is distinct from old.consent_accepted_at
    )
  then
    raise exception 'Protected profile fields can only be changed by trusted server operations';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_profile_privilege_escalation on public.profiles;
create trigger prevent_profile_privilege_escalation
before update on public.profiles
for each row execute function public.prevent_profile_privilege_escalation();

create or replace function public.is_profile_email_confirmed(profile_id uuid)
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select exists (
    select 1
    from auth.users
    where id = profile_id
      and email_confirmed_at is not null
  );
$$;

revoke all on function public.is_profile_email_confirmed(uuid) from public;
grant execute on function public.is_profile_email_confirmed(uuid)
  to authenticated, service_role;

drop policy if exists "Profiles are visible to signed-in users"
  on public.profiles;
create policy "Profiles are visible to signed-in users"
on public.profiles for select
to authenticated
using (public.is_profile_email_confirmed(id));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  -- Normal email registrations are inserted unconfirmed and reach this
  -- function again when their email is confirmed. Requiring the current
  -- consent metadata on that update prevents clients from bypassing the
  -- mobile consent control. Trusted service users that are created already
  -- confirmed, such as the administrator bootstrap, keep their insert path.
  if tg_op = 'UPDATE'
    and (
      nullif(trim(new.raw_user_meta_data ->> 'terms_version'), '')
        is distinct from '1.0'
      or nullif(trim(new.raw_user_meta_data ->> 'privacy_version'), '')
        is distinct from '1.0'
      or nullif(
        trim(new.raw_user_meta_data ->> 'consent_accepted_at'),
        ''
      ) is null
    )
  then
    raise exception 'Registration consent metadata is required';
  end if;

  insert into public.profiles (
    id,
    email,
    name,
    terms_version,
    privacy_version,
    consent_accepted_at
  )
  values (
    new.id,
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(new.email, '@', 1)
    ),
    nullif(trim(new.raw_user_meta_data ->> 'terms_version'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'privacy_version'), ''),
    nullif(
      trim(new.raw_user_meta_data ->> 'consent_accepted_at'),
      ''
    )::timestamptz
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(nullif(public.profiles.name, ''), excluded.name),
    terms_version = coalesce(
      public.profiles.terms_version,
      excluded.terms_version
    ),
    privacy_version = coalesce(
      public.profiles.privacy_version,
      excluded.privacy_version
    ),
    consent_accepted_at = coalesce(
      public.profiles.consent_accepted_at,
      excluded.consent_accepted_at
    ),
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed
after update of email_confirmed_at on auth.users
for each row
when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
execute function public.handle_new_user();
