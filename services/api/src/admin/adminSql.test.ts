import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const sql = readFileSync(
  new URL('../../../../supabase/admin_portal.sql', import.meta.url),
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
  assert.match(sql, /three unique reporters/);
});

test('admin portal SQL prevents duplicate unresolved reports', () => {
  assert.match(sql, /reports_one_unresolved_per_reporter_target/);
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
