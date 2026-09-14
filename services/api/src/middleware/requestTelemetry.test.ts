import assert from 'node:assert/strict';
import test from 'node:test';
import express from 'express';
import request from 'supertest';

import { requestTelemetry } from './requestTelemetry.js';

test('returns a request ID and logs safe timing fields', async () => {
  const logs: string[] = [];
  const original = console.info;
  console.info = (message: string) => logs.push(message);
  try {
    const app = express();
    app.use(requestTelemetry());
    app.get('/test', (_req, res) => res.json({ ok: true }));
    const response = await request(app).get('/test');
    assert.match(response.headers['x-request-id'], /^[0-9a-f-]{36}$/i);
    const event = JSON.parse(logs[0]);
    assert.equal(event.method, 'GET');
    assert.equal(event.path, '/test');
    assert.equal(event.status, 200);
    assert.equal(typeof event.durationMs, 'number');
    assert.equal(Object.hasOwn(event, 'authorization'), false);
  } finally {
    console.info = original;
  }
});
