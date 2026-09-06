import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migration = readFileSync(
  new URL('../../../../supabase/ai_moderation.sql', import.meta.url),
  'utf8',
);
const schema = readFileSync(
  new URL('../../../../supabase/schema.sql', import.meta.url),
  'utf8',
);

test('upgrade SQL defines the complete moderation authority', () => {
  assert.match(
    migration,
    /create table if not exists public\.content_moderation_cases/i,
  );
  assert.match(
    migration,
    /unique\s*\(target_type, target_id, moderation_revision\)/i,
  );
  assert.match(migration, /prepare_content_moderation/i);
  assert.match(migration, /apply_ai_moderation_result/i);
  assert.match(migration, /mark_content_moderation_failed/i);
  assert.match(migration, /grant execute[\s\S]*to service_role/i);
  assert.match(migration, /moderation_revision/i);
  assert.match(migration, /invalidate_post_image_moderation/i);
});

test('fresh schema contains the moderation base tables and revision fields', () => {
  assert.match(schema, /create table if not exists public\.content_moderation_cases/i);
  assert.match(schema, /moderation_revision integer not null default 1/i);
  assert.match(schema, /mime_type text/i);
});

test('upgrade SQL adds the audited administrator decision boundary', () => {
  assert.match(migration, /decide_content_moderation_case/i);
  assert.match(migration, /admin_action_audit/i);
  assert.match(migration, /grant execute[\s\S]*to authenticated/i);
});

test('new content is no longer auto-approved', () => {
  assert.doesNotMatch(schema, /default 'approved'.*auto-approve/i);
  assert.doesNotMatch(
    schema,
    /update public\.(posts|comments) set moderation_status = 'approved'/i,
  );
  assert.match(schema, /moderation_status[^\n]+default 'pending'/i);
});
