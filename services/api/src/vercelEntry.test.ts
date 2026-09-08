import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import request from 'supertest';

import vercelApp from '../api/index.js';

test('Vercel entry exports the composed Express application', async () => {
  const response = await request(vercelApp).get('/health');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
});

test('Vercel rewrites every public route to the API function', () => {
  const config = JSON.parse(
    readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'),
  ) as { rewrites?: Array<{ source?: string; destination?: string }> };
  assert.deepEqual(config.rewrites, [
    { source: '/(.*)', destination: '/api' },
  ]);
});
