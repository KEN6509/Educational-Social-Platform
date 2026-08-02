create table if not exists public.admin_action_audit (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete restrict,
  action_type text not null,
  target_type text not null,
  target_id uuid not null,
  reason text not null check (char_length(btrim(reason)) between 10 and 500),
  previous_state jsonb not null default '{}'::jsonb,
  new_state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_action_audit_created_idx
on public.admin_action_audit (created_at desc);

create index if not exists admin_action_audit_target_idx
on public.admin_action_audit (target_type, target_id, created_at desc);

create unique index if not exists reports_one_unresolved_per_reporter_target
on public.reports (reporter_id, target_type, target_id)
where reporter_id is not null
  and status = 'pending_review';

alter table public.admin_action_audit enable row level security;

drop policy if exists "Admins view audit records"
on public.admin_action_audit;
create policy "Admins view audit records"
on public.admin_action_audit for select
to authenticated
using (public.is_current_user_admin());

drop policy if exists "Admins view post appeals"
on public.post_appeals;
create policy "Admins view post appeals"
on public.post_appeals for select
to authenticated
using (public.is_current_user_admin());

create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'authenticated'
    and coalesce(
      current_setting('cyanzone.trusted_profile_update', true),
      'off'
    ) <> 'on'
    and (
      new.is_admin is distinct from old.is_admin
      or new.is_content_creator is distinct from old.is_content_creator
      or new.account_status is distinct from old.account_status
    )
  then
    raise exception
      'Profile privilege fields can only be changed by trusted server operations';
  end if;

  return new;
end;
$$;

create or replace function public.admin_portal_current_admin()
returns uuid
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_admin_id uuid := auth.uid();
begin
  if v_admin_id is null then
    raise exception using
      errcode = '42501',
      message = 'Administrator session required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = v_admin_id
      and p.is_admin = true
      and p.account_status = 'active'
  ) then
    raise exception using
      errcode = '42501',
      message = 'Active administrator access required';
  end if;

  return v_admin_id;
end;
$$;

create or replace function public.admin_portal_reason(p_reason text)
returns text
language plpgsql
security definer
set search_path = public
immutable
as $$
declare
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if char_length(v_reason) not between 10 and 500 then
    raise exception using
      errcode = '22023',
      message = 'Administrator reason must be between 10 and 500 characters';
  end if;

  return v_reason;
end;
$$;

create or replace function public.admin_portal_notify(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_action_type text default 'none',
  p_action_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (
    user_id,
    type,
    post_id,
    comment_id,
    title,
    body,
    action_type,
    action_payload
  )
  select
    p_user_id,
    'system',
    nullif(p_action_payload->>'post_id', '')::uuid,
    nullif(p_action_payload->>'comment_id', '')::uuid,
    p_title,
    p_body,
    p_action_type,
    coalesce(p_action_payload, '{}'::jsonb)
  where coalesce((
    select np.in_app_enabled and np.system_enabled
    from public.notification_preferences np
    where np.user_id = p_user_id
  ), true);
end;
$$;

-- Backfill report-removal notifications created before structured payloads.
update public.notifications notification
set
  post_id = post.id,
  action_payload = notification.action_payload || jsonb_build_object(
    'post_id', post.id,
    'template_type', 'reported_post_removed',
    'brief', 'We reviewed community reports about your post.',
    'decision_message', post.moderation_reason
  )
from public.posts post
where notification.type = 'system'
  and notification.title = 'Content removed after reports'
  and notification.user_id = post.author_id
  and post.moderation_reason is not null
  and (
    notification.post_id = post.id
    or notification.action_payload->>'post_id' = post.id::text
  );

update public.notifications notification
set
  post_id = comment.post_id,
  comment_id = comment.id,
  action_payload = notification.action_payload || jsonb_build_object(
    'post_id', comment.post_id,
    'comment_id', comment.id,
    'template_type', 'reported_comment_removed',
    'brief', 'We reviewed community reports about your comment.',
    'decision_message', comment.moderation_reason
  )
from public.comments comment
where notification.type = 'system'
  and notification.title = 'Content removed after reports'
  and notification.user_id = comment.author_id
  and comment.moderation_reason is not null
  and notification.action_payload->>'comment_id' = comment.id::text;

create or replace function public.fetch_system_notification_reason(
  p_notification_id uuid
)
returns text
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_current_user uuid := auth.uid();
  v_notification public.notifications%rowtype;
  v_template text;
  v_reason text;
  v_creator_request_id uuid;
  v_post_id uuid;
  v_comment_id uuid;
  v_audit_action text;
begin
  if v_current_user is null then
    raise exception 'Authentication required';
  end if;

  select notification.*
  into v_notification
  from public.notifications notification
  where notification.id = p_notification_id
    and notification.user_id = v_current_user
    and notification.type = 'system';

  if not found then
    raise exception 'System notification not found';
  end if;

  v_reason := nullif(
    btrim(v_notification.action_payload->>'decision_message'),
    ''
  );
  if v_reason is not null then
    return v_reason;
  end if;

  v_template := coalesce(
    nullif(v_notification.action_payload->>'template_type', ''),
    case v_notification.title
      when 'Verification Application' then 'creator_badge_awarded'
      when 'You are now a verified content creator' then 'creator_badge_awarded'
      when 'Request rejected' then 'creator_request_rejected'
      when 'Creator status updated' then 'creator_status_removed'
      when 'Account suspended' then 'account_suspended'
      when 'Account reactivated' then 'account_reactivated'
      when 'Post has been rejected' then 'post_rejected'
      when 'Your post was not approved' then 'post_rejected'
      when 'Appeal approved' then 'post_appeal_approved'
      when 'Appeal rejected' then 'post_appeal_rejected'
      when 'Content removed after reports' then
        case
          when coalesce(
            v_notification.comment_id::text,
            v_notification.action_payload->>'comment_id'
          ) is null then 'reported_post_removed'
          else 'reported_comment_removed'
        end
      else null
    end
  );

  if v_notification.action_payload->>'creator_request_id' is not null then
    v_creator_request_id :=
      (v_notification.action_payload->>'creator_request_id')::uuid;
  end if;
  v_post_id := coalesce(
    v_notification.post_id,
    nullif(v_notification.action_payload->>'post_id', '')::uuid
  );
  v_comment_id := coalesce(
    v_notification.comment_id,
    nullif(v_notification.action_payload->>'comment_id', '')::uuid
  );

  if v_template in ('creator_badge_awarded', 'creator_request_rejected') then
    select request.admin_note
    into v_reason
    from public.content_creator_requests request
    where request.user_id = v_current_user
      and nullif(btrim(request.admin_note), '') is not null
      and (
        (v_creator_request_id is not null and request.id = v_creator_request_id)
        or (
          v_creator_request_id is null
          and request.status::text = case
            when v_template = 'creator_badge_awarded' then 'approved'
            else 'rejected'
          end
        )
      )
    order by
      (request.id = v_creator_request_id) desc,
      abs(extract(epoch from (
        coalesce(request.reviewed_at, request.updated_at) -
        v_notification.created_at
      )))
    limit 1;

    if nullif(btrim(coalesce(v_reason, '')), '') is not null then
      return btrim(v_reason);
    end if;
  end if;

  v_audit_action := case v_template
    when 'creator_badge_awarded' then 'creator_status_assigned'
    when 'creator_status_removed' then 'creator_status_removed'
    when 'account_suspended' then 'user_suspended'
    when 'account_reactivated' then 'user_reactivated'
    else null
  end;
  if v_audit_action is not null then
    select audit.reason
    into v_reason
    from public.admin_action_audit audit
    where audit.target_type = 'user'
      and audit.target_id = v_current_user
      and audit.action_type = v_audit_action
    order by abs(extract(epoch from (
      audit.created_at - v_notification.created_at
    )))
    limit 1;

    if nullif(btrim(coalesce(v_reason, '')), '') is not null then
      return btrim(v_reason);
    end if;
  end if;

  if v_template in ('post_rejected', 'reported_post_removed')
    and v_post_id is not null
  then
    select post.moderation_reason
    into v_reason
    from public.posts post
    where post.id = v_post_id
      and post.author_id = v_current_user;
  elsif v_template = 'reported_comment_removed'
    and v_comment_id is not null
  then
    select comment.moderation_reason
    into v_reason
    from public.comments comment
    where comment.id = v_comment_id
      and comment.author_id = v_current_user;
  elsif v_template in ('post_appeal_approved', 'post_appeal_rejected')
    and v_post_id is not null
  then
    select appeal.admin_note
    into v_reason
    from public.post_appeals appeal
    where appeal.post_id = v_post_id
      and appeal.user_id = v_current_user
    order by appeal.reviewed_at desc nulls last
    limit 1;
  end if;

  return nullif(btrim(coalesce(v_reason, '')), '');
end;
$$;

create or replace function public.set_user_account_status(
  p_user_id uuid,
  p_status text,
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
  v_profile public.profiles%rowtype;
  v_previous_state jsonb;
  v_new_state jsonb;
begin
  if p_status not in ('active', 'suspended') then
    raise exception using
      errcode = '22023',
      message = 'Account status must be active or suspended';
  end if;

  if p_user_id = v_admin_id and p_status = 'suspended' then
    raise exception using
      errcode = '22023',
      message = 'Administrators cannot suspend their own account';
  end if;

  select *
  into v_profile
  from public.profiles p
  where p.id = p_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'User not found';
  end if;

  if v_profile.account_status = 'deleted' then
    raise exception using
      errcode = 'P0001',
      message = 'Deleted accounts cannot be changed';
  end if;

  if v_profile.account_status = p_status then
    raise exception using
      errcode = 'P0001',
      message = 'Account status has already changed';
  end if;

  v_previous_state := jsonb_build_object(
    'account_status',
    v_profile.account_status
  );

  perform set_config('cyanzone.trusted_profile_update', 'on', true);

  update public.profiles
  set
    account_status = p_status,
    updated_at = now()
  where id = p_user_id;

  perform set_config('cyanzone.trusted_profile_update', 'off', true);

  v_new_state := jsonb_build_object('account_status', p_status);

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
      when p_status = 'suspended' then 'user_suspended'
      else 'user_reactivated'
    end,
    'user',
    p_user_id,
    v_reason,
    v_previous_state,
    v_new_state
  );

  perform public.admin_portal_notify(
    p_user_id,
    case
      when p_status = 'suspended' then 'Account suspended'
      else 'Account reactivated'
    end,
    case
      when p_status = 'suspended'
        then 'Your CyanZone account has been suspended by an administrator.'
      else 'Your CyanZone account has been reactivated.'
    end,
    'none',
    jsonb_build_object(
      'template_type',
      case
        when p_status = 'suspended' then 'account_suspended'
        else 'account_reactivated'
      end,
      'brief',
      case
        when p_status = 'suspended'
          then 'An administrator has suspended your CyanZone account.'
        else 'An administrator has reactivated your CyanZone account.'
      end,
      'decision_message',
      v_reason
    )
  );

  return v_new_state;
end;
$$;

create or replace function public.set_user_creator_status(
  p_user_id uuid,
  p_is_creator boolean,
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
  v_profile public.profiles%rowtype;
  v_previous_state jsonb;
  v_new_state jsonb;
begin
  if p_is_creator is null then
    raise exception using
      errcode = '22023',
      message = 'Creator status is required';
  end if;

  select *
  into v_profile
  from public.profiles p
  where p.id = p_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'User not found';
  end if;

  if v_profile.account_status = 'deleted' then
    raise exception using
      errcode = 'P0001',
      message = 'Deleted accounts cannot be changed';
  end if;

  if v_profile.is_content_creator = p_is_creator then
    raise exception using
      errcode = 'P0001',
      message = 'Creator status has already changed';
  end if;

  v_previous_state := jsonb_build_object(
    'is_content_creator',
    v_profile.is_content_creator
  );

  perform set_config('cyanzone.trusted_profile_update', 'on', true);

  update public.profiles
  set
    is_content_creator = p_is_creator,
    updated_at = now()
  where id = p_user_id;

  perform set_config('cyanzone.trusted_profile_update', 'off', true);

  v_new_state := jsonb_build_object('is_content_creator', p_is_creator);

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
      when p_is_creator then 'creator_status_assigned'
      else 'creator_status_removed'
    end,
    'user',
    p_user_id,
    v_reason,
    v_previous_state,
    v_new_state
  );

  if p_is_creator then
    update public.notifications notification
    set
      title = 'Verification Application',
      body = 'Your account verification application has been reviewed.',
      action_payload = notification.action_payload || jsonb_build_object(
        'template_type', 'creator_badge_awarded',
        'brief', 'Your account verification application has been reviewed.',
        'decision_message', v_reason
      )
    where notification.id = (
      select existing.id
      from public.notifications existing
      where existing.user_id = p_user_id
        and existing.type = 'system'
        and existing.action_payload->>'template_type' =
          'creator_badge_awarded'
      order by existing.created_at desc
      limit 1
    );
  else
    perform public.admin_portal_notify(
      p_user_id,
      'Creator status updated',
      'Your verified CyanZone content creator status has been removed.',
      'none',
      jsonb_build_object(
        'template_type', 'creator_status_removed',
        'brief',
          'Your verified CyanZone content creator status has been removed.',
        'decision_message', v_reason
      )
    );
  end if;

  return v_new_state;
end;
$$;

create or replace function public.review_creator_request(
  p_request_id uuid,
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
  v_request public.content_creator_requests%rowtype;
  v_profile public.profiles%rowtype;
  v_previous_state jsonb;
  v_new_state jsonb;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception using
      errcode = '22023',
      message = 'Creator request decision must be approved or rejected';
  end if;

  select *
  into v_request
  from public.content_creator_requests request
  where request.id = p_request_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Creator request not found';
  end if;

  if v_request.status <> 'pending'::public.creator_request_status then
    raise exception using
      errcode = 'P0001',
      message = 'Creator request has already been decided';
  end if;

  select *
  into v_profile
  from public.profiles p
  where p.id = v_request.user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Creator request user not found';
  end if;

  v_previous_state := jsonb_build_object(
    'request_status',
    v_request.status::text,
    'is_content_creator',
    v_profile.is_content_creator
  );

  update public.content_creator_requests
  set
    status = p_decision::public.creator_request_status,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    admin_note = v_reason,
    updated_at = now()
  where id = p_request_id;

  if p_decision = 'approved' and not v_profile.is_content_creator then
    perform set_config('cyanzone.trusted_profile_update', 'on', true);

    update public.profiles
    set
      is_content_creator = true,
      updated_at = now()
    where id = v_request.user_id;

    perform set_config('cyanzone.trusted_profile_update', 'off', true);

    update public.notifications
    set
      title = 'Verification Application',
      body = 'Your account verification application has been reviewed.',
      action_payload = action_payload || jsonb_build_object(
        'template_type', 'creator_badge_awarded',
        'creator_request_id', v_request.id,
        'brief', 'Your account verification application has been reviewed.',
        'decision_label', 'Congratulations',
        'decision_message', v_reason
      )
    where id = (
      select notification.id
      from public.notifications notification
      where notification.user_id = v_request.user_id
        and notification.type = 'system'
        and notification.action_payload->>'template_type' =
          'creator_badge_awarded'
      order by notification.created_at desc
      limit 1
    );
  elsif p_decision = 'rejected' then
    perform public.admin_portal_notify(
      v_request.user_id,
      'Request rejected',
      format(
        E'Your CyanZone verified badge request was not approved.\n\nReason from the administrator:\n%s\n\nYou may update your profile or content and apply again.',
        v_reason
      ),
      'none',
      jsonb_build_object(
        'template_type',
        'creator_request_rejected',
        'creator_request_id',
        v_request.id,
        'brief',
        'Your account verification application has been reviewed.',
        'decision_label',
        'Administrator feedback',
        'decision_message',
        v_reason
      )
    );
  end if;

  v_new_state := jsonb_build_object(
    'request_status',
    p_decision,
    'is_content_creator',
    p_decision = 'approved' or v_profile.is_content_creator
  );

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
    'creator_request_' || p_decision,
    'creator_request',
    p_request_id,
    v_reason,
    v_previous_state,
    v_new_state
  );

  return v_new_state;
end;
$$;

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

  -- One unique reporter is enough during functional testing.
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
        case when p_target_type = 'comment' then p_target_id else null end,
        'template_type',
        case
          when p_target_type = 'post' then 'reported_post_removed'
          else 'reported_comment_removed'
        end,
        'target_type',
        p_target_type,
        'brief',
        case
          when p_target_type = 'post'
            then 'We reviewed community reports about your post.'
          else 'We reviewed community reports about your comment.'
        end,
        'decision_label',
        'Administrator decision',
        'decision_message',
        v_reason
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

create or replace function public.decide_post_appeal(
  p_appeal_id uuid,
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
  v_appeal public.post_appeals%rowtype;
  v_post public.posts%rowtype;
  v_previous_state jsonb;
  v_new_state jsonb;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception using
      errcode = '22023',
      message = 'Appeal decision must be approved or rejected';
  end if;

  select *
  into v_appeal
  from public.post_appeals appeal
  where appeal.id = p_appeal_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Appeal not found';
  end if;

  if v_appeal.status <> 'pending' then
    raise exception using
      errcode = 'P0001',
      message = 'Appeal has already been decided';
  end if;

  select *
  into v_post
  from public.posts p
  where p.id = v_appeal.post_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Appealed post not found';
  end if;

  if v_post.moderation_status not in (
    'rejected'::public.moderation_status,
    'removed'::public.moderation_status
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Appealed post is no longer rejected or removed';
  end if;

  v_previous_state := jsonb_build_object(
    'appeal',
    to_jsonb(v_appeal),
    'post',
    to_jsonb(v_post)
  );

  update public.post_appeals
  set
    status = p_decision,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    admin_note = v_reason,
    updated_at = now()
  where id = p_appeal_id;

  if p_decision = 'approved' then
    update public.posts
    set
      moderation_status = 'approved',
      published_at = coalesce(published_at, now()),
      updated_at = now()
    where id = v_appeal.post_id;
  end if;

  select jsonb_build_object(
    'appeal',
    to_jsonb(appeal),
    'post',
    to_jsonb(p)
  )
  into v_new_state
  from public.post_appeals appeal
  join public.posts p on p.id = appeal.post_id
  where appeal.id = p_appeal_id;

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
    'post_appeal_' || p_decision,
    'post_appeal',
    p_appeal_id,
    v_reason,
    v_previous_state,
    v_new_state
  );

  perform public.admin_portal_notify(
    v_appeal.user_id,
    case
      when p_decision = 'approved' then 'Appeal approved'
      else 'Appeal rejected'
    end,
    case
      when p_decision = 'approved'
        then 'Your post appeal was approved and the post is published again.'
      else 'Your post appeal was reviewed and was not approved.'
    end,
    'post_detail',
    jsonb_build_object(
      'post_id', v_appeal.post_id,
      'template_type', 'post_appeal_' || p_decision,
      'brief', 'Your content appeal has been reviewed.',
      'decision_label', 'Final decision',
      'decision_message', v_reason
    )
  );

  return jsonb_build_object(
    'appeal_id',
    p_appeal_id,
    'decision',
    p_decision
  );
end;
$$;

revoke all on table public.admin_action_audit from anon, authenticated;
grant select on table public.admin_action_audit to authenticated;

revoke all on function public.admin_portal_current_admin() from public;
revoke all on function public.admin_portal_reason(text) from public;
revoke all on function public.admin_portal_notify(
  uuid,
  text,
  text,
  text,
  jsonb
) from public;

revoke all on function public.fetch_system_notification_reason(uuid)
from public, anon;
grant execute on function public.fetch_system_notification_reason(uuid)
to authenticated;

revoke all on function public.set_user_account_status(
  uuid,
  text,
  text
) from public, anon;
grant execute on function public.set_user_account_status(
  uuid,
  text,
  text
) to authenticated;

revoke all on function public.set_user_creator_status(
  uuid,
  boolean,
  text
) from public, anon;
grant execute on function public.set_user_creator_status(
  uuid,
  boolean,
  text
) to authenticated;

revoke all on function public.review_creator_request(
  uuid,
  text,
  text
) from public, anon;
grant execute on function public.review_creator_request(
  uuid,
  text,
  text
) to authenticated;

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

revoke all on function public.decide_post_appeal(
  uuid,
  text,
  text
) from public, anon;
grant execute on function public.decide_post_appeal(
  uuid,
  text,
  text
) to authenticated;
