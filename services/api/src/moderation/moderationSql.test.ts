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
const storageMigration = readFileSync(
  new URL('../../../../supabase/storage.sql', import.meta.url),
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

test('moderation cases preserve the exact target revision submitted for review', () => {
  for (const sql of [migration, schema]) {
    assert.match(sql, /target_snapshot jsonb not null default '\{\}'::jsonb/i);
  }
  assert.match(
    migration,
    /jsonb_build_object\([\s\S]*?'title'[\s\S]*?'content'[\s\S]*?'tags'[\s\S]*?'images'[\s\S]*?into v_owner_id, v_revision, v_target_snapshot/i,
  );
  assert.match(
    migration,
    /insert into public\.content_moderation_cases[\s\S]*?target_snapshot[\s\S]*?v_target_snapshot/i,
  );
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

test('authenticated inserts cannot supply moderation authority fields', () => {
  assert.match(
    migration,
    /create trigger initialize_post_moderation[\s\S]*before insert on public\.posts/i,
  );
  assert.match(
    migration,
    /create trigger initialize_comment_moderation[\s\S]*before insert on public\.comments/i,
  );
  assert.match(
    migration,
    /new\.moderation_status := 'pending'[\s\S]*new\.moderation_revision := 1/i,
  );
  assert.match(
    schema,
    /create policy "Users can create own posts"[\s\S]*moderation_status = 'pending'[\s\S]*moderation_revision = 1[\s\S]*ai_toxicity_score is null[\s\S]*published_at is null/i,
  );
  assert.match(
    schema,
    /create policy "Users can create own comments"[\s\S]*moderation_status = 'pending'[\s\S]*moderation_revision = 1[\s\S]*ai_toxicity_score is null/i,
  );
});

test('internal moderation helpers are not executable by clients', () => {
  for (const signature of [
    'set_moderation_target_pending\\(text, uuid, integer\\)',
    'invalidate_moderation_cases\\(text, uuid, integer\\)',
    'initialize_post_moderation_fields\\(\\)',
    'initialize_comment_moderation_fields\\(\\)',
    'protect_post_moderation_fields\\(\\)',
    'protect_comment_moderation_fields\\(\\)',
    'invalidate_post_image_moderation\\(\\)',
  ]) {
    assert.match(
      migration,
      new RegExp(
        `revoke all on function public\\.${signature}[\\s\\S]*?from public, anon, authenticated`,
        'i',
      ),
    );
  }
});

test('shared image storage writes are owner-scoped and objects are immutable', () => {
  for (const sql of [storageMigration, migration, schema]) {
    assert.match(
      sql,
      /bucket_id = 'images'[\s\S]*storage\.foldername\(name\)\)\[1\][\s\S]*auth\.uid\(\)/i,
    );
    assert.match(
      sql,
      /storage\.foldername\(name\)\)\[1\][\s\S]*= 'chat'[\s\S]*storage\.foldername\(name\)\)\[2\][\s\S]*auth\.uid\(\)/i,
    );
    assert.match(
      sql,
      /drop policy if exists "Authenticated users can update images" on storage\.objects/i,
    );
    assert.doesNotMatch(
      sql,
      /create policy "Authenticated users can update images"/i,
    );
  }
});

test('avatar storage migration scopes writes to the first owner folder', () => {
  assert.match(
    storageMigration,
    /create policy "Authenticated users can upload avatars"[\s\S]*bucket_id = 'avatars'[\s\S]*storage\.foldername\(name\)\)\[1\][\s\S]*auth\.uid\(\)/i,
  );
  assert.match(
    storageMigration,
    /create policy "Authenticated users can update avatars"[\s\S]*using[\s\S]*storage\.foldername\(name\)\)\[1\][\s\S]*auth\.uid\(\)/i,
  );
});
