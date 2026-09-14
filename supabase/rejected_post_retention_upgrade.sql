-- CyanZone rejected-post retention upgrade.
-- Run after ai_moderation.sql and post_editing.sql on an existing project.
-- Storage objects are removed through the Storage API by the API cron worker;
-- this migration never writes to storage.objects directly.

do $$
begin
  if to_regclass('cron.job') is not null and exists (
    select 1 from cron.job where jobname = 'delete-old-rejected-posts'
  ) then
    perform cron.unschedule('delete-old-rejected-posts');
  end if;
exception when others then
  raise notice 'Legacy rejected-post cron was not installed.';
end
$$;

drop function if exists public.delete_old_rejected_posts();

create or replace function public.prepare_expired_rejected_post_cleanup(p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case public.content_moderation_cases%rowtype;
  v_post public.posts%rowtype;
  v_paths jsonb;
begin
  select * into v_case
  from public.content_moderation_cases
  where id = p_case_id
  for update;

  if not found
    or v_case.target_type <> 'post'
    or v_case.state <> 'rejected'
    or v_case.decision_source <> 'admin'
    or v_case.completed_at is null
    or v_case.completed_at > now() - interval '7 days'
  then
    return jsonb_build_object('action', 'skip', 'storage_paths', '[]'::jsonb);
  end if;

  select * into v_post
  from public.posts
  where id = v_case.target_id
  for update;

  if not found then
    update public.content_moderation_cases
    set target_snapshot = (target_snapshot - 'images')
          || jsonb_build_object('image_evidence_redacted', true),
        updated_at = now()
    where id = v_case.id;
    return jsonb_build_object('action', 'missing', 'storage_paths', '[]'::jsonb);
  end if;

  if v_post.moderation_revision is distinct from v_case.moderation_revision
    or v_post.moderation_status not in ('rejected'::public.moderation_status, 'removed'::public.moderation_status)
  then
    update public.content_moderation_cases
    set target_snapshot = (target_snapshot - 'images')
          || jsonb_build_object('image_evidence_redacted', true),
        updated_at = now()
    where id = v_case.id;
    return jsonb_build_object('action', 'superseded', 'storage_paths', '[]'::jsonb);
  end if;

  if v_post.moderation_status = 'rejected'::public.moderation_status then
    perform set_config('cyanzone.trusted_moderation_update', 'on', true);
    update public.posts
    set moderation_status = 'removed'::public.moderation_status, updated_at = now()
    where id = v_post.id;
  end if;

  select coalesce(jsonb_agg(image.storage_path order by image.position), '[]'::jsonb)
  into v_paths
  from public.post_images image
  where image.post_id = v_post.id;

  return jsonb_build_object('action', 'ready', 'storage_paths', v_paths);
end;
$$;

create or replace function public.finalize_expired_rejected_post_cleanup(p_case_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case public.content_moderation_cases%rowtype;
  v_post public.posts%rowtype;
begin
  select * into v_case
  from public.content_moderation_cases
  where id = p_case_id
    and target_type = 'post'
    and state = 'rejected'
    and decision_source = 'admin'
    and completed_at is not null
    and completed_at <= now() - interval '7 days'
  for update;

  if not found then
    return jsonb_build_object('action', 'skip');
  end if;

  select * into v_post
  from public.posts
  where id = v_case.target_id
  for update;

  if not found then
    update public.content_moderation_cases
    set target_snapshot = (target_snapshot - 'images')
          || jsonb_build_object('image_evidence_redacted', true),
        updated_at = now()
    where id = v_case.id;
    return jsonb_build_object('action', 'missing');
  end if;

  if v_post.moderation_revision is distinct from v_case.moderation_revision
    or v_post.moderation_status <> 'removed'::public.moderation_status
  then
    update public.content_moderation_cases
    set target_snapshot = (target_snapshot - 'images')
          || jsonb_build_object('image_evidence_redacted', true),
        updated_at = now()
    where id = v_case.id;
    return jsonb_build_object('action', 'skip');
  end if;

  delete from public.posts where id = v_post.id;
  update public.content_moderation_cases
  set target_snapshot = (target_snapshot - 'images')
        || jsonb_build_object('image_evidence_redacted', true),
      updated_at = now()
  where id = v_case.id;
  return jsonb_build_object('action', 'deleted');
end;
$$;

revoke all on function public.prepare_expired_rejected_post_cleanup(uuid) from public, anon, authenticated;
revoke all on function public.finalize_expired_rejected_post_cleanup(uuid) from public, anon, authenticated;
grant execute on function public.prepare_expired_rejected_post_cleanup(uuid) to service_role;
grant execute on function public.finalize_expired_rejected_post_cleanup(uuid) to service_role;
