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
  assert.equal(env.GEMINI_MODEL, 'gemini-3.5-flash-lite');
  assert.equal(env.GEMINI_FALLBACK_MODEL, 'gemini-3.8-flash');
  assert.equal(env.GEMINI_TIMEOUT_MS, 15000);
});

test('Gemini moderation configuration accepts deployment overrides', () => {
  const env = parseEnv({
    ...requiredEnv,
    GEMINI_MODEL: 'gemini-3.6-flash',
    GEMINI_FALLBACK_MODEL: 'gemini-3.8-flash',
    GEMINI_TIMEOUT_MS: '7000',
  });
  assert.equal(env.GEMINI_MODEL, 'gemini-3.6-flash');
  assert.equal(env.GEMINI_FALLBACK_MODEL, 'gemini-3.8-flash');
  assert.equal(env.GEMINI_TIMEOUT_MS, 7000);
});

test('Gemini primary and fallback models must differ', () => {
  assert.throws(
    () =>
      parseEnv({
        ...requiredEnv,
        GEMINI_MODEL: 'gemini-3.8-flash',
        GEMINI_FALLBACK_MODEL: 'gemini-3.8-flash',
      }),
    /fallback/i,
  );
});

test('Gemini timeout stays below the mobile request budget', () => {
  assert.throws(() =>
    parseEnv({ ...requiredEnv, GEMINI_TIMEOUT_MS: '20000' }),
  );
});

test('CORS origins default to local admin development origins', () => {
  assert.deepEqual(parseEnv(requiredEnv).CORS_ALLOWED_ORIGINS, [
    'http://localhost:5173',
    'http://127.0.0.1:5173',
  ]);
});

test('CORS origins are trimmed, deduplicated, and parsed for deployment', () => {
  const env = parseEnv({
    ...requiredEnv,
    CORS_ALLOWED_ORIGINS:
      ' https://admin.cyanzone.com, http://localhost:5173,https://admin.cyanzone.com ',
  });
  assert.deepEqual(env.CORS_ALLOWED_ORIGINS, [
    'https://admin.cyanzone.com',
    'http://localhost:5173',
  ]);
});

test('push configuration is optional for local development', () => {
  const env = parseEnv(requiredEnv);
  assert.equal(env.PUSH_WEBHOOK_SECRET, undefined);
  assert.equal(env.FIREBASE_PROJECT_ID, undefined);
});

test('push configuration requires every Firebase credential together', () => {
  assert.throws(
    () =>
      parseEnv({
        ...requiredEnv,
        PUSH_WEBHOOK_SECRET: 'p'.repeat(32),
        FIREBASE_PROJECT_ID: 'cyanzone-test',
      }),
    /Firebase push configuration/i,
  );
});

test('push configuration normalizes Vercel escaped private-key newlines', () => {
  const env = parseEnv({
    ...requiredEnv,
    PUSH_WEBHOOK_SECRET: 'p'.repeat(32),
    FIREBASE_PROJECT_ID: 'cyanzone-test',
    FIREBASE_CLIENT_EMAIL: 'firebase-adminsdk@example.iam.gserviceaccount.com',
    FIREBASE_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\\nkey\\n-----END PRIVATE KEY-----\\n',
  });

  assert.equal(
    env.FIREBASE_PRIVATE_KEY,
    '-----BEGIN PRIVATE KEY-----\nkey\n-----END PRIVATE KEY-----\n',
  );
});
