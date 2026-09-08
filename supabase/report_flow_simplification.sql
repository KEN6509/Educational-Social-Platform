begin;

drop index if exists public.reports_one_unresolved_per_reporter_target;
drop function if exists public.decide_report_case(text, uuid, text, text);

alter table public.reports alter column status drop default;
alter table public.reports
  alter column status type text using status::text;

update public.reports
set status = 'pending_review'
where status in ('open', 'reviewing');

drop type if exists public.report_status;
create type public.report_status as enum (
  'pending_review',
  'resolved',
  'dismissed'
);

alter table public.reports
  alter column status type public.report_status
  using status::public.report_status;
alter table public.reports
  alter column status set default 'pending_review';
alter table public.reports
  drop column if exists description;

create unique index reports_one_unresolved_per_reporter_target
on public.reports (reporter_id, target_type, target_id)
where reporter_id is not null
  and status = 'pending_review';

create or replace function public.decide_report_case(
  p_target_type text,
  p_target_id uuid,
  p_decision text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := public.admin_portal_current_admin();
  v_reason text := public.admin_portal_reason(p_reason);
  v_reporter_count integer;
  v_post public.posts%rowtype;
  v_comment public.comments%rowtype;
  v_owner_id uuid;
  v_post_id uuid;
  v_previous_target jsonb;
  v_new_target jsonb;
  v_previous_reports jsonb;
  v_new_reports jsonb;
  v_new_report_status public.report_status;
begin
  if p_target_type not in ('post', 'comment') then
    raise exception using
      errcode = '22023',
      message = 'Report target must be post or comment';
  end if;

  if p_decision not in ('retain', 'remove') then
    raise exception using
      errcode = '22023',
      message = 'Report decision must be retain or remove';
  end if;

  if p_target_type = 'post' then
    select *
    into v_post
    from public.posts p
    where p.id = p_target_id
    for update;

    if not found then
      raise exception using
        errcode = 'P0002',
        message = 'Reported post not found';
    end if;

    if v_post.moderation_status = 'removed'::public.moderation_status then
      raise exception using
        errcode = 'P0001',
        message = 'Reported content has already been removed';
    end if;

    v_owner_id := v_post.author_id;
    v_post_id := v_post.id;
    v_previous_target := to_jsonb(v_post);
  else
    select *
    into v_comment
    from public.comments c
    where c.id = p_target_id
    for update;

    if not found then
      raise exception using
        errcode = 'P0002',
        message = 'Reported comment not found';
    end if;

    if v_comment.moderation_status = 'removed'::public.moderation_status then
      raise exception using
        errcode = 'P0001',
        message = 'Reported content has already been removed';
    end if;

    v_owner_id := v_comment.author_id;
    v_post_id := v_comment.post_id;
    v_previous_target := to_jsonb(v_comment);
  end if;

  perform 1
  from public.reports r
  where r.target_type = p_target_type
    and r.target_id = p_target_id
    and r.status = 'pending_review'
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'Report case has already been decided';
  end if;

  select
    count(distinct r.reporter_id),
    coalesce(
      jsonb_agg(to_jsonb(r) order by r.created_at),
      '[]'::jsonb
    )
  into v_reporter_count, v_previous_reports
  from public.reports r
  where r.target_type = p_target_type
    and r.target_id = p_target_id
    and r.status = 'pending_review';

  if v_reporter_count < 1 then
    raise exception using
      errcode = 'P0001',
      message = 'Report case has no unique reporters';
  end if;

  v_new_report_status := case
    when p_decision = 'retain'
      then 'dismissed'::public.report_status
    else 'resolved'::public.report_status
  end;

  if p_decision = 'remove' and p_target_type = 'post' then
    update public.posts
    set
      moderation_status = 'removed',
      moderation_reason = v_reason,
      reviewed_by = v_admin_id,
      reviewed_at = now(),
      updated_at = now()
    where id = p_target_id
    returning to_jsonb(public.posts.*) into v_new_target;
  elsif p_decision = 'remove' then
    update public.comments
    set
      moderation_status = 'removed',
      moderation_reason = v_reason,
      updated_at = now()
    where id = p_target_id
    returning to_jsonb(public.comments.*) into v_new_target;
  else
    v_new_target := v_previous_target;
  end if;

  update public.reports
  set
    status = v_new_report_status,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    resolution_note = v_reason,
    updated_at = now()
  where target_type = p_target_type
    and target_id = p_target_id
    and status = 'pending_review';

  select coalesce(
    jsonb_agg(to_jsonb(r) order by r.created_at),
    '[]'::jsonb
  )
  into v_new_reports
  from public.reports r
  where r.target_type = p_target_type
    and r.target_id = p_target_id
    and r.status = v_new_report_status;

  insert into public.admin_action_audit (
    admin_id,
    action_type,
    target_type,
    target_id,
    reason,
    previous_state,
    new_state
  )
  values (
    v_admin_id,
    case
      when p_decision = 'retain' then 'reported_content_retained'
      else 'reported_content_removed'
    end,
    p_target_type,
    p_target_id,
    v_reason,
    jsonb_build_object(
      'target',
      v_previous_target,
      'reports',
      v_previous_reports
    ),
    jsonb_build_object(
      'target',
      v_new_target,
      'reports',
      v_new_reports
    )
  );

  if p_decision = 'remove' then
    perform public.admin_portal_notify(
      v_owner_id,
      'Content removed after reports',
      'An administrator removed your content after reviewing community reports.',
      'post_detail',
      jsonb_build_object(
        'post_id',
        v_post_id,
        'comment_id',
        case when p_target_type = 'comment' then p_target_id else null end
      )
    );
  end if;

  return jsonb_build_object(
    'target_type',
    p_target_type,
    'target_id',
    p_target_id,
    'decision',
    p_decision,
    'report_status',
    v_new_report_status::text,
    'unique_reporters',
    v_reporter_count
  );
end;
$$;

revoke all on function public.decide_report_case(
  text,
  uuid,
  text,
  text
) from public, anon;
grant execute on function public.decide_report_case(
  text,
  uuid,
  text,
  text
) to authenticated;

commit;
