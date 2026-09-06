import assert from 'node:assert/strict';
import test from 'node:test';

import { parseEnv } from './env.js';

const requiredEnv = {
  SUPABASE_URL: 'https://project.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role',
  ADMIN_BOOTSTRAP_SECRET: 'a'.repeat(24),
};

test('report review threshold defaults to one for functional testing', () => {
  assert.equal(parseEnv(requiredEnv).REPORT_REVIEW_THRESHOLD, 1);
});

test('report review threshold accepts the deployment value', () => {
  assert.equal(
    parseEnv({ ...requiredEnv, REPORT_REVIEW_THRESHOLD: '1000' })
      .REPORT_REVIEW_THRESHOLD,
    1000,
  );
});

test('Gemini moderation configuration has bounded defaults', () => {
  const env = parseEnv(requiredEnv);
  assert.equal(env.GEMINI_MODEL, 'gemini-3.8-flash');
  assert.equal(env.GEMINI_TIMEOUT_MS, 8500);
});

test('Gemini moderation configuration accepts deployment overrides', () => {
  const env = parseEnv({
    ...requiredEnv,
    GEMINI_MODEL: 'gemini-3.7-flash',
    GEMINI_TIMEOUT_MS: '7000',
  });
  assert.equal(env.GEMINI_MODEL, 'gemini-3.7-flash');
  assert.equal(env.GEMINI_TIMEOUT_MS, 7000);
});

test('Gemini timeout cannot consume the complete 20 second budget', () => {
  assert.throws(() =>
    parseEnv({ ...requiredEnv, GEMINI_TIMEOUT_MS: '10000' }),
  );
});
