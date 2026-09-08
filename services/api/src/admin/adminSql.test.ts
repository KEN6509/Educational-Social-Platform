import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const sql = readFileSync(
  new URL('../../../../supabase/admin_portal.sql', import.meta.url),
  'utf8',
).toLowerCase();
const schemaSql = readFileSync(
  new URL('../../../../supabase/schema.sql', import.meta.url),
  'utf8',
).toLowerCase();
const migrationSql = readFileSync(
  new URL(
    '../../../../supabase/report_flow_simplification.sql',
    import.meta.url,
  ),
  'utf8',
).toLowerCase();
const chatSql = readFileSync(
  new URL('../../../../supabase/chat.sql', import.meta.url),
  'utf8',
).toLowerCase();

test('admin portal SQL defines audit and decision boundaries', () => {
  assert.match(sql, /create table if not exists public\.admin_action_audit/);
  assert.match(sql, /previous_state jsonb/);
  assert.match(sql, /new_state jsonb/);
  assert.match(sql, /set_user_account_status/);
  assert.match(sql, /set_user_creator_status/);
  assert.match(sql, /review_creator_request/);
  assert.match(sql, /decide_report_case/);
  assert.match(sql, /decide_post_appeal/);
  assert.match(sql, /one unique reporter/);
});

test('admin portal SQL prevents duplicate unresolved reports', () => {
  assert.match(sql, /reports_one_unresolved_per_reporter_target/);
  assert.match(sql, /and status = 'pending_review'/);
  assert.doesNotMatch(sql, /status in \('open', 'reviewing'\)/);
});

test('report schema and migration use the simplified lifecycle', () => {
  assert.match(
    schemaSql,
    /create type public\.report_status as enum \('pending_review', 'resolved', 'dismissed'\)/,
  );
  assert.match(
    schemaSql,
    /status public\.report_status not null default 'pending_review'/,
  );
  const reportsTable = schemaSql.slice(
    schemaSql.indexOf('create table if not exists public.reports'),
    schemaSql.indexOf('create table if not exists public.parent_child_links'),
  );
  assert.doesNotMatch(reportsTable, /\bdescription text\b/);
  assert.match(
    migrationSql,
    /update public\.reports\s+set status = 'pending_review'\s+where status in \('open', 'reviewing'\)/s,
  );
  assert.match(migrationSql, /drop column if exists description/);
  assert.match(
    migrationSql,
    /where reporter_id is not null\s+and status = 'pending_review'/s,
  );
  assert.match(migrationSql, /create or replace function public\.decide_report_case/);
  assert.match(migrationSql, /'resolved'/);
  assert.match(migrationSql, /'dismissed'/);
  assert.doesNotMatch(migrationSql, /supabase db push/);
});

test('admin decisions enforce authorization, locking, audit, and notifications', () => {
  assert.match(sql, /security definer/);
  assert.match(sql, /set search_path = public/);
  assert.match(sql, /admin_portal_current_admin/);
  assert.match(sql, /for update/);
  assert.match(sql, /count\(distinct r\.reporter_id\)/);
  assert.match(sql, /insert into public\.admin_action_audit/);
  assert.match(sql, /insert into public\.notifications/);
  assert.match(sql, /revoke all on function public\.decide_report_case/);
  assert.match(sql, /grant execute on function public\.decide_report_case/);
});

test('creator, moderation, report, and appeal notification rules stay explicit', () => {
  assert.match(
    chatSql,
    /create or replace function public\.notify_content_creator_awarded/,
  );
  assert.match(
    chatSql,
    /create or replace function public\.notify_post_rejected/,
  );
  assert.match(
    chatSql,
    /create or replace function public\.notify_post_approved/,
  );
  assert.match(
    chatSql,
    /old\.moderation_status = 'pending'[\s\S]*new\.moderation_status = 'approved'/,
  );
  assert.match(chatSql, /'template_type', 'post_approved'/);
  const postApprovedFunction = chatSql.slice(
    chatSql.indexOf('create or replace function public.notify_post_approved'),
    chatSql.indexOf(
      'drop trigger if exists notify_new_follower_on_insert',
    ),
  );
  assert.match(
    postApprovedFunction,
    /'brief'[\s\S]*your post has completed moderation review/,
  );
  assert.match(
    postApprovedFunction,
    /'decision_message'[\s\S]*passed moderation/,
  );

  const accountStatusFunction = sql.slice(
    sql.indexOf('create or replace function public.set_user_account_status'),
    sql.indexOf('create or replace function public.set_user_creator_status'),
  );
  assert.match(accountStatusFunction, /'account_suspended'/);
  assert.match(accountStatusFunction, /'account_reactivated'/);
  assert.match(accountStatusFunction, /'decision_message'[\s\S]*v_reason/);

  const creatorStatusFunction = sql.slice(
    sql.indexOf('create or replace function public.set_user_creator_status'),
    sql.indexOf('create or replace function public.review_creator_request'),
  );
  assert.match(creatorStatusFunction, /'creator_status_removed'/);
  assert.match(creatorStatusFunction, /'decision_message'[\s\S]*v_reason/);

  const creatorRequestFunction = sql.slice(
    sql.indexOf('create or replace function public.review_creator_request'),
    sql.indexOf('create or replace function public.decide_report_case'),
  );
  assert.match(creatorRequestFunction, /'request rejected'/);
  assert.match(
    creatorRequestFunction,
    /reason from the administrator:[\s\S]*v_reason/,
  );
  assert.match(creatorRequestFunction, /'decision_message'[\s\S]*v_reason/);
  assert.match(creatorRequestFunction, /'verification application'/);

  const reportFunction = sql.slice(
    sql.indexOf('create or replace function public.decide_report_case'),
    sql.indexOf('create or replace function public.decide_post_appeal'),
  );
  assert.match(
    reportFunction,
    /if p_decision = 'remove' then[\s\S]*perform public\.admin_portal_notify/,
  );
  assert.match(reportFunction, /'reported_post_removed'/);
  assert.match(reportFunction, /'reported_comment_removed'/);
  assert.match(reportFunction, /'decision_message'[\s\S]*v_reason/);
  assert.match(
    sql,
    /p_action_payload->>'post_id'[\s\S]*p_action_payload->>'comment_id'/,
  );
  assert.doesNotMatch(
    reportFunction,
    /if p_decision = 'retain' then[\s\S]*perform public\.admin_portal_notify/,
  );
});

test('system notification reason resolver is owner checked and covers legacy decisions', () => {
  const resolver = sql.slice(
    sql.indexOf(
      'create or replace function public.fetch_system_notification_reason',
    ),
    sql.indexOf('create or replace function public.set_user_account_status'),
  );

  assert.match(resolver, /auth.uid()/);
  assert.match(resolver, /notification.user_id = v_current_user/);
  assert.match(resolver, /notification.type = 'system'/);
  assert.match(resolver, /content_creator_requests/);
  assert.match(resolver, /admin_action_audit/);
  assert.match(resolver, /post_appeals/);
  assert.match(
    sql,
    /grant execute on function public.fetch_system_notification_reason/,
  );
});

test('trusted RPCs cooperate with the profile privilege guard', () => {
  assert.match(sql, /cyanzone\.trusted_profile_update/);
  assert.match(sql, /prevent_profile_privilege_escalation/);
});

test('appeals and audit records are administrator-readable only', () => {
  assert.match(sql, /admins view audit records/);
  assert.match(sql, /admins view post appeals/);
  assert.match(sql, /revoke all on table public\.admin_action_audit/);
  assert.match(sql, /grant select on table public\.admin_action_audit/);
});
