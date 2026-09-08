import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import request from 'supertest';

import vercelApp from '../api/index.js';

test('Vercel entry exports the composed Express application', async () => {
  const response = await request(vercelApp).get('/health');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
});

test('only the composed server uses a Vercel Express entry-point filename', () => {
  assert.equal(
    existsSync(new URL('./app.ts', import.meta.url)),
    false,
    'src/app.ts is auto-detected by Vercel and must not contain only an app factory',
  );
  assert.equal(
    existsSync(new URL('./createApp.ts', import.meta.url)),
    true,
  );
});

test('Vercel rewrites every public route to the API function', () => {
  const config = JSON.parse(
    readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'),
  ) as { rewrites?: Array<{ source?: string; destination?: string }> };
  assert.deepEqual(config.rewrites, [
    { source: '/(.*)', destination: '/api' },
  ]);
});

test('Vercel Express compilation normalizes the Helmet module type', () => {
  const appSource = readFileSync(
    new URL('./createApp.ts', import.meta.url),
    'utf8',
  );

  assert.match(appSource, /^import helmetModule from 'helmet';$/m);
  assert.match(
    appSource,
    /const createHelmetMiddleware = helmetModule as unknown as \(\) => express\.RequestHandler;/,
  );
  assert.match(appSource, /app\.use\(createHelmetMiddleware\(\)\);/);
});
