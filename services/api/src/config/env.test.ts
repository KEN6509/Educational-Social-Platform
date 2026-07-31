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
