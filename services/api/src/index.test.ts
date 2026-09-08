import assert from 'node:assert/strict';
import test from 'node:test';
import request from 'supertest';
import app from './index.js';

test('default API export is a Vercel-compatible Express application', async () => {
  const response = await request(app).get('/health');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.service, 'cyanzone-api');
});
