-- CyanZone AI moderation upgrade.
-- Run after admin_portal.sql on an existing Supabase project.

create table if not exists public.content_moderation_cases (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('post', 'comment')),
  target_id uuid not null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  moderation_revision integer not null check (moderation_revision > 0),
  target_snapshot jsonb not null default '{}'::jsonb,
  state text not null check (
    state in ('processing', 'admin_review', 'approved', 'rejected', 'failed', 'superseded')
  ),
  overall_risk_score numeric(5,2)
    check (overall_risk_score between 0 and 100),
  category_scores jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  user_reason text,
  provider text,
  model text,
  prompt_version text,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  claim_token uuid,
  lease_expires_at timestamptz,
  failure_code text,
  failure_message text,
  decision_source text check (decision_source in ('gemini', 'admin')),
  decided_by uuid references public.profiles(id) on delete set null,
  decision_reason text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (target_type, target_id, moderation_revision)
);

alter table public.content_moderation_cases
  add column if not exists target_snapshot jsonb not null default '{}'::jsonb;

alter table public.posts
  add column if not exists moderation_revision integer not null default 1;
alter table public.comments
  add column if not exists moderation_revision integer not null default 1;
alter table public.post_images
  add column if not exists mime_type text
    check (mime_type is null or mime_type in (
      'image/png', 'image/jpeg', 'image/webp', 'image/heic', 'image/heif'
    ));

-- Existing projects may still have the original bucket-wide write policies.
-- Post objects use <member-id>/..., while chat objects use
-- chat/<member-id>/.... Objects are immutable because both features upload
-- unique names with upsert disabled.
drop policy if exists "Authenticated users can upload post images" on storage.objects;
drop policy if exists "Users can upload their own post images" on storage.objects;
drop policy if exists "Authenticated users can upload images" on storage.objects;
create policy "Authenticated users can upload images"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'images'
  and (
    (storage.foldername(name))[1] = (auth.uid())::text
    or (
      (storage.foldername(name))[1] = 'chat'
      and (storage.foldername(name))[2] = (auth.uid())::text
    )
  )
);

drop policy if exists "Authenticated users can update post images" on storage.objects;
drop policy if exists "Users can update their own post images" on storage.objects;
drop policy if exists "Authenticated users can update images" on storage.objects;

drop policy if exists "Authenticated users can delete post images" on storage.objects;
drop policy if exists "Users can delete their own post images" on storage.objects;
drop policy if exists "Authenticated users can delete images" on storage.objects;
create policy "Authenticated users can delete images"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'images'
  and (
    (storage.foldername(name))[1] = (auth.uid())::text
    or (
      (storage.foldername(name))[1] = 'chat'
      and (storage.foldername(name))[2] = (auth.uid())::text
    )
  )
);

create index if not exists content_moderation_cases_state_idx
on public.content_moderation_cases (state, updated_at desc);

create index if not exists content_moderation_cases_target_idx
on public.content_moderation_cases (target_type, target_id, moderation_revision desc);

alter table public.content_moderation_cases enable row level security;

drop policy if exists "Authors view own moderation cases"
on public.content_moderation_cases;
create policy "Authors view own moderation cases"
on public.content_moderation_cases for select
to authenticated
using (owner_id = auth.uid());

drop policy if exists "Admins view moderation cases"
on public.content_moderation_cases;
create policy "Admins view moderation cases"
on public.content_moderation_cases for select
to authenticated
using (public.is_current_user_admin());

revoke all on table public.content_moderation_cases from anon, authenticated;
grant select on table public.content_moderation_cases to authenticated;

create or replace function public.initialize_post_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trusted boolean := coalesce(
    current_setting('cyanzone.trusted_moderation_update', true),
    'off'
  ) = 'on';
begin
  if not v_trusted and auth.role() = 'authenticated' then
    new.moderation_status := 'pending';
    new.moderation_revision := 1;
    new.ai_toxicity_score := null;
    new.moderation_reason := null;
    new.reviewed_by := null;
    new.reviewed_at := null;
    new.published_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists initialize_post_moderation on public.posts;
create trigger initialize_post_moderation
before insert on public.posts
for each row execute function public.initialize_post_moderation_fields();

create or replace function public.initialize_comment_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trusted boolean := coalesce(
    current_setting('cyanzone.trusted_moderation_update', true),
    'off'
  ) = 'on';
begin
  if not v_trusted and auth.role() = 'authenticated' then
    new.moderation_status := 'pending';
    new.moderation_revision := 1;
    new.ai_toxicity_score := null;
    new.moderation_reason := null;
  end if;
  return new;
end;
$$;

drop trigger if exists initialize_comment_moderation on public.comments;
create trigger initialize_comment_moderation
before insert on public.comments
for each row execute function public.initialize_comment_moderation_fields();

create or replace function public.set_moderation_target_pending(
  p_target_type text,
  p_target_id uuid,
  p_revision integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('cyanzone.trusted_moderation_update', 'on', true);

  if p_target_type = 'post' then
    update public.posts
    set moderation_revision = p_revision,
        moderation_status = 'pending',
        ai_toxicity_score = null,
        moderation_reason = null,
        reviewed_by = null,
        reviewed_at = null,
        published_at = null,
        updated_at = now()
    where id = p_target_id;
  elsif p_target_type = 'comment' then
    update public.comments
    set moderation_revision = p_revision,
        moderation_status = 'pending',
        ai_toxicity_score = null,
        moderation_reason = null,
        updated_at = now()
    where id = p_target_id;
  else
    raise exception using errcode = '22023', message = 'Unsupported moderation target';
  end if;
end;
$$;

create or replace function public.invalidate_moderation_cases(
  p_target_type text,
  p_target_id uuid,
  p_revision integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.content_moderation_cases
  set state = 'superseded',
      claim_token = null,
      lease_expires_at = null,
      updated_at = now()
  where target_type = p_target_type
    and target_id = p_target_id
    and moderation_revision < p_revision
    and state in ('processing', 'admin_review', 'failed');
end;
$$;

create or replace function public.protect_post_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trusted boolean := coalesce(
    current_setting('cyanzone.trusted_moderation_update', true),
    'off'
  ) = 'on';
  v_content_changed boolean := old.title is distinct from new.title
    or old.content is distinct from new.content
    or old.tags is distinct from new.tags;
begin
  if not v_trusted and auth.role() = 'authenticated' then
    if new.moderation_status is distinct from old.moderation_status
      and not (new.moderation_status = 'removed' and old.moderation_status <> 'removed')
    then
      raise exception using
        errcode = '42501',
        message = 'Post moderation status is controlled by the moderation service';
    end if;

    if new.ai_toxicity_score is distinct from old.ai_toxicity_score
      or new.moderation_reason is distinct from old.moderation_reason
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at
      or new.published_at is distinct from old.published_at
      or new.moderation_revision is distinct from old.moderation_revision
    then
      raise exception using
        errcode = '42501',
        message = 'Post moderation evidence is controlled by the moderation service';
    end if;
  end if;

  if v_content_changed and not v_trusted then
    new.moderation_revision := old.moderation_revision + 1;
    new.moderation_status := 'pending';
    new.ai_toxicity_score := null;
    new.moderation_reason := null;
    new.reviewed_by := null;
    new.reviewed_at := null;
    new.published_at := null;
    perform public.invalidate_moderation_cases('post', old.id, new.moderation_revision);
  end if;

  return new;
end;
$$;

drop trigger if exists protect_post_moderation on public.posts;
create trigger protect_post_moderation
before update on public.posts
for each row execute function public.protect_post_moderation_fields();

create or replace function public.protect_comment_moderation_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trusted boolean := coalesce(
    current_setting('cyanzone.trusted_moderation_update', true),
    'off'
  ) = 'on';
begin
  if not v_trusted and auth.role() = 'authenticated' then
    if new.moderation_status is distinct from old.moderation_status
      and not (new.moderation_status = 'removed' and old.moderation_status <> 'removed')
    then
      raise exception using
        errcode = '42501',
        message = 'Comment moderation status is controlled by the moderation service';
    end if;

    if new.ai_toxicity_score is distinct from old.ai_toxicity_score
      or new.moderation_reason is distinct from old.moderation_reason
      or new.moderation_revision is distinct from old.moderation_revision
    then
      raise exception using
        errcode = '42501',
        message = 'Comment moderation evidence is controlled by the moderation service';
    end if;
  end if;

  if old.content is distinct from new.content and not v_trusted then
    new.moderation_revision := old.moderation_revision + 1;
    new.moderation_status := 'pending';
    new.ai_toxicity_score := null;
    new.moderation_reason := null;
    perform public.invalidate_moderation_cases('comment', old.id, new.moderation_revision);
  end if;

  return new;
end;
$$;

drop trigger if exists protect_comment_moderation on public.comments;
create trigger protect_comment_moderation
before update on public.comments
for each row execute function public.protect_comment_moderation_fields();

create or replace function public.invalidate_post_image_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_id uuid := coalesce(new.post_id, old.post_id);
  v_revision integer;
begin
  perform set_config('cyanzone.trusted_moderation_update', 'on', true);

  update public.posts
  set moderation_revision = moderation_revision + 1,
      moderation_status = 'pending',
      ai_toxicity_score = null,
      moderation_reason = null,
      reviewed_by = null,
      reviewed_at = null,
      published_at = null,
      updated_at = now()
  where id = v_post_id
  returning moderation_revision into v_revision;

  if v_revision is not null then
    perform public.invalidate_moderation_cases('post', v_post_id, v_revision);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists invalidate_post_image_moderation_insert on public.post_images;
create trigger invalidate_post_image_moderation_insert
after insert on public.post_images
for each row execute function public.invalidate_post_image_moderation();

drop trigger if exists invalidate_post_image_moderation_update on public.post_images;
create trigger invalidate_post_image_moderation_update
after update on public.post_images
for each row execute function public.invalidate_post_image_moderation();

drop trigger if exists invalidate_post_image_moderation_delete on public.post_images;
create trigger invalidate_post_image_moderation_delete
after delete on public.post_images
for each row execute function public.invalidate_post_image_moderation();

create or replace function public.prepare_content_moderation(
  p_target_type text,
  p_target_id uuid,
  p_owner_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_revision integer;
  v_target_snapshot jsonb;
  v_case public.content_moderation_cases%rowtype;
  v_token uuid := gen_random_uuid();
begin
  if p_target_type = 'post' then
    select
      post.author_id,
      post.moderation_revision,
      jsonb_build_object(
        'title', post.title,
        'content', post.content,
        'tags', to_jsonb(post.tags),
        'images', coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'public_url', image.public_url,
                'storage_path', image.storage_path,
                'mime_type', image.mime_type,
                'position', image.position
              ) order by image.position
            )
            from public.post_images image
            where image.post_id = post.id
          ),
          '[]'::jsonb
        )
      )
    into v_owner_id, v_revision, v_target_snapshot
    from public.posts post
    where post.id = p_target_id
    for update;
  elsif p_target_type = 'comment' then
    select
      comment.author_id,
      comment.moderation_revision,
      jsonb_build_object('content', comment.content)
    into v_owner_id, v_revision, v_target_snapshot
    from public.comments comment
    where comment.id = p_target_id
    for update;
  else
    raise exception using errcode = '22023', message = 'Unsupported moderation target';
  end if;

  if v_owner_id is null then
    raise exception using errcode = 'P0002', message = 'Moderation target not found';
  end if;
  if v_owner_id <> p_owner_id then
    raise exception using errcode = '42501', message = 'Moderation target ownership mismatch';
  end if;

  select * into v_case
  from public.content_moderation_cases
  where target_type = p_target_type
    and target_id = p_target_id
    and moderation_revision = v_revision
  for update;

  if found then
    if v_case.state in ('approved', 'rejected', 'admin_review') then
      return to_jsonb(v_case) || jsonb_build_object('should_process', false);
    end if;

    if v_case.state = 'processing'
      and coalesce(v_case.lease_expires_at, now()) > now()
    then
      return to_jsonb(v_case) || jsonb_build_object('should_process', false);
    end if;

    if v_case.state = 'failed'
      and v_case.updated_at > now() - interval '15 seconds'
    then
      raise exception using
        errcode = '55P03',
        message = 'Moderation retry is temporarily rate limited';
    end if;

    update public.content_moderation_cases
    set state = 'processing',
        target_snapshot = case
          when target_snapshot = '{}'::jsonb then v_target_snapshot
          else target_snapshot
        end,
        claim_token = v_token,
        lease_expires_at = now() + interval '30 seconds',
        started_at = now(),
        updated_at = now()
    where id = v_case.id
    returning * into v_case;
  else
    insert into public.content_moderation_cases (
      target_type,
      target_id,
      owner_id,
      moderation_revision,
      target_snapshot,
      state,
      claim_token,
      lease_expires_at,
      started_at
    ) values (
      p_target_type,
      p_target_id,
      p_owner_id,
      v_revision,
      v_target_snapshot,
      'processing',
      v_token,
      now() + interval '30 seconds',
      now()
    )
    returning * into v_case;
  end if;

  return to_jsonb(v_case) || jsonb_build_object('should_process', true);
end;
$$;

create or replace function public.apply_ai_moderation_result(
  p_case_id uuid,
  p_expected_revision integer,
  p_claim_token uuid,
  p_case_state text,
  p_overall_risk_score numeric,
  p_category_scores jsonb,
  p_evidence jsonb,
  p_user_reason text,
  p_model text,
  p_prompt_version text,
  p_attempt_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case public.content_moderation_cases%rowtype;
  v_target_revision integer;
begin
  select * into v_case
  from public.content_moderation_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Moderation case not found';
  end if;
  if v_case.claim_token is distinct from p_claim_token then
    raise exception using errcode = '40001', message = 'Moderation claim is stale';
  end if;

  if v_case.target_type = 'post' then
    select moderation_revision into v_target_revision
    from public.posts where id = v_case.target_id for update;
  else
    select moderation_revision into v_target_revision
    from public.comments where id = v_case.target_id for update;
  end if;

  if v_target_revision is distinct from p_expected_revision then
    update public.content_moderation_cases
    set state = 'superseded', claim_token = null, lease_expires_at = null, updated_at = now()
    where id = v_case.id;
    raise exception using errcode = '40001', message = 'Moderation revision is stale';
  end if;

  if p_case_state not in ('approved', 'admin_review', 'rejected') then
    raise exception using errcode = '22023', message = 'Invalid AI moderation decision';
  end if;

  perform set_config('cyanzone.trusted_moderation_update', 'on', true);

  if v_case.target_type = 'post' then
    update public.posts
    set moderation_status = case when p_case_state = 'approved' then 'approved' else case when p_case_state = 'rejected' then 'rejected' else 'pending' end end,
        ai_toxicity_score = p_overall_risk_score / 100,
        moderation_reason = p_user_reason,
        reviewed_at = case when p_case_state = 'admin_review' then null else now() end,
        published_at = case when p_case_state = 'approved' then coalesce(published_at, now()) else null end,
        updated_at = now()
    where id = v_case.target_id;
  else
    update public.comments
    set moderation_status = case when p_case_state = 'approved' then 'approved' else case when p_case_state = 'rejected' then 'rejected' else 'pending' end end,
        ai_toxicity_score = p_overall_risk_score / 100,
        moderation_reason = p_user_reason,
        updated_at = now()
    where id = v_case.target_id;
  end if;

  update public.content_moderation_cases
  set state = p_case_state,
      overall_risk_score = p_overall_risk_score,
      category_scores = coalesce(p_category_scores, '{}'::jsonb),
      evidence = coalesce(p_evidence, '[]'::jsonb),
      user_reason = p_user_reason,
      provider = 'gemini',
      model = p_model,
      prompt_version = p_prompt_version,
      attempt_count = p_attempt_count,
      decision_source = 'gemini',
      claim_token = null,
      lease_expires_at = null,
      completed_at = now(),
      updated_at = now()
  where id = v_case.id
  returning * into v_case;

  return to_jsonb(v_case);
end;
$$;

create or replace function public.mark_content_moderation_failed(
  p_case_id uuid,
  p_expected_revision integer,
  p_claim_token uuid,
  p_failure_code text,
  p_failure_message text,
  p_attempt_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case public.content_moderation_cases%rowtype;
begin
  select * into v_case
  from public.content_moderation_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Moderation case not found';
  end if;
  if v_case.claim_token is distinct from p_claim_token then
    raise exception using errcode = '40001', message = 'Moderation claim is stale';
  end if;

  update public.content_moderation_cases
  set state = 'failed',
      failure_code = left(p_failure_code, 80),
      failure_message = left(p_failure_message, 500),
      attempt_count = p_attempt_count,
      claim_token = null,
      lease_expires_at = null,
      updated_at = now()
  where id = p_case_id
    and moderation_revision = p_expected_revision
  returning * into v_case;

  if not found then
    raise exception using errcode = '40001', message = 'Moderation revision is stale';
  end if;

  return to_jsonb(v_case);
end;
$$;

create or replace function public.decide_content_moderation_case(
  p_case_id uuid,
  p_decision text,
  p_reason text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := public.admin_portal_current_admin();
  v_case public.content_moderation_cases%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_revision integer;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception using errcode = '22023', message = 'Invalid moderation decision';
  end if;
  if p_decision = 'rejected' and char_length(v_reason) not between 10 and 500 then
    raise exception using errcode = '22023', message = 'Administrator reason must be between 10 and 500 characters';
  end if;
  if p_decision = 'approved' and char_length(v_reason) > 500 then
    raise exception using errcode = '22023', message = 'Administrator reason is too long';
  end if;

  select * into v_case
  from public.content_moderation_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Moderation case not found';
  end if;
  if v_case.state <> 'admin_review' then
    raise exception using errcode = '55000', message = 'Moderation case is no longer awaiting review';
  end if;

  if v_case.target_type = 'post' then
    select moderation_revision into v_revision
    from public.posts where id = v_case.target_id for update;
  else
    select moderation_revision into v_revision
    from public.comments where id = v_case.target_id for update;
  end if;
  if v_revision is distinct from v_case.moderation_revision then
    update public.content_moderation_cases
    set state = 'superseded', updated_at = now()
    where id = v_case.id;
    raise exception using errcode = '40001', message = 'Moderation case revision is stale';
  end if;

  perform set_config('cyanzone.trusted_moderation_update', 'on', true);

  if v_case.target_type = 'post' then
    update public.posts
    set moderation_status = p_decision,
        moderation_reason = case when char_length(v_reason) > 0 then v_reason else moderation_reason end,
        reviewed_by = v_admin_id,
        reviewed_at = now(),
        published_at = case when p_decision = 'approved' then coalesce(published_at, now()) else null end,
        updated_at = now()
    where id = v_case.target_id;
  else
    update public.comments
    set moderation_status = p_decision,
        moderation_reason = case when char_length(v_reason) > 0 then v_reason else moderation_reason end,
        updated_at = now()
    where id = v_case.target_id;
  end if;

  update public.content_moderation_cases
  set state = p_decision,
      decision_source = 'admin',
      decided_by = v_admin_id,
      decision_reason = nullif(v_reason, ''),
      completed_at = now(),
      claim_token = null,
      lease_expires_at = null,
      updated_at = now()
  where id = v_case.id
  returning * into v_case;

  insert into public.admin_action_audit (
    admin_id,
    action_type,
    target_type,
    target_id,
    reason,
    previous_state,
    new_state
  ) values (
    v_admin_id,
    case when p_decision = 'approved' then 'ai_content_approved' else 'ai_content_rejected' end,
    v_case.target_type,
    v_case.target_id,
    case when char_length(v_reason) >= 10 then v_reason else 'Administrator approved AI moderation case.' end,
    jsonb_build_object('moderation_status', 'pending', 'moderation_case_id', v_case.id),
    jsonb_build_object('moderation_status', p_decision, 'moderation_case_id', v_case.id)
  );

  return to_jsonb(v_case);
end;
$$;

revoke all on function public.prepare_content_moderation(text, uuid, uuid)
from public, anon, authenticated;
grant execute on function public.prepare_content_moderation(text, uuid, uuid)
to service_role;

revoke all on function public.apply_ai_moderation_result(
  uuid, integer, uuid, text, numeric, jsonb, jsonb, text, text, text, integer
) from public, anon, authenticated;
grant execute on function public.apply_ai_moderation_result(
  uuid, integer, uuid, text, numeric, jsonb, jsonb, text, text, text, integer
) to service_role;

revoke all on function public.mark_content_moderation_failed(
  uuid, integer, uuid, text, text, integer
) from public, anon, authenticated;
grant execute on function public.mark_content_moderation_failed(
  uuid, integer, uuid, text, text, integer
) to service_role;

revoke all on function public.decide_content_moderation_case(uuid, text, text)
from public, anon;
grant execute on function public.decide_content_moderation_case(uuid, text, text)
to authenticated;

revoke all on function public.set_moderation_target_pending(text, uuid, integer)
from public, anon, authenticated;
revoke all on function public.invalidate_moderation_cases(text, uuid, integer)
from public, anon, authenticated;
revoke all on function public.initialize_post_moderation_fields()
from public, anon, authenticated;
revoke all on function public.initialize_comment_moderation_fields()
from public, anon, authenticated;
revoke all on function public.protect_post_moderation_fields()
from public, anon, authenticated;
revoke all on function public.protect_comment_moderation_fields()
from public, anon, authenticated;
revoke all on function public.invalidate_post_image_moderation()
from public, anon, authenticated;
