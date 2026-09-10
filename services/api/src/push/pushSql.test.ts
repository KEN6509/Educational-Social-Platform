import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migration = readFileSync(
  new URL('../../../../supabase/fcm_push_notifications.sql', import.meta.url),
  'utf8',
);

test('push migration adds independent preferences and visibility', () => {
  assert.match(migration, /add column if not exists push_enabled boolean/i);
  assert.match(
    migration,
    /notifications\s+add column if not exists in_app_visible/i,
  );
  assert.match(
    migration,
    /supervision_notifications\s+add column if not exists in_app_visible/i,
  );
  assert.match(migration, /before insert on public\.notifications/i);
  assert.match(
    migration,
    /before insert on public\.supervision_notifications/i,
  );
  assert.match(migration, /v_push boolean := false/i);
  assert.match(migration, /not v_in_app and not v_push/i);
});

test('push migration defines device and delivery idempotency boundaries', () => {
  assert.match(migration, /create table if not exists public\.push_device_tokens/i);
  assert.match(migration, /platform text[\s\S]*?check[\s\S]*?android/i);
  assert.match(migration, /unique\s*\(user_id, device_id\)/i);
  assert.match(migration, /token text[^\n]*unique/i);
  assert.match(migration, /create table if not exists public\.push_deliveries/i);
  assert.match(migration, /unique\s*\(source_table, source_id\)/i);
  assert.match(migration, /processing.*delivered.*partial.*skipped.*failed/is);
  assert.match(
    migration,
    /delete from public\.push_device_tokens[\s\S]*?token <> p_token/i,
  );
  assert.match(migration, /p_is_active boolean default true/i);
  assert.match(migration, /is_active = excluded\.is_active/i);
  assert.match(
    migration,
    /create or replace function public\.register_push_device\s*\(/i,
  );
});

test('push migration protects service-only lifecycle RPCs and member visibility', () => {
  assert.match(migration, /register_push_device/i);
  assert.match(migration, /deactivate_push_device/i);
  assert.match(migration, /claim_push_delivery/i);
  assert.match(migration, /complete_push_delivery/i);
  assert.match(
    migration,
    /using\s*\(user_id = auth\.uid\(\)\s+and\s+in_app_visible\)/i,
  );
  assert.match(
    migration,
    /revoke execute on function public\.register_push_device[\s\S]*?from public/i,
  );
  assert.match(
    migration,
    /grant execute on function public\.register_push_device[\s\S]*?to service_role/i,
  );
  assert.match(
    migration,
    /revoke select, insert, update, delete on public\.push_device_tokens from anon, authenticated/i,
  );
});
