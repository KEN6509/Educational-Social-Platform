import assert from 'node:assert/strict';
import express, { Router } from 'express';
import request from 'supertest';
import test from 'node:test';

import { createApp, type AppDependencies } from '../createApp.js';
import { createPushRouter } from './pushRouter.js';
import type { PushService } from './pushService.js';

function app(service: PushService) {
  const dependencies: AppDependencies = {
    bootstrapSecret: 'a'.repeat(24),
    countAdministrators: async () => 0,
    createAdministrator: async () => ({id: 'admin-1'}),
    upsertAdministratorProfile: async () => {},
    protectedAdminRouter: Router(),
    moderationRouter: Router(),
    pushRouter: createPushRouter({
      verifyMember: async () => ({id: 'member-1', email: 'member@example.com'}),
      service,
      webhookSecret: 'w'.repeat(32),
    }),
    verifyAdmin: async () => ({id: 'admin-1', email: 'admin@example.com'}),
  };
  return createApp(dependencies, express());
}

const service: PushService = {
  registerDevice: async () => {},
  deactivateDevice: async () => {},
  processEvent: async () => ({
    status: 'delivered',
    deliveryId: 'delivery-1',
    successCount: 1,
    failureCount: 0,
  }),
  resolveDestination: async () => ({
    source: {} as never,
    destination: {
      version: '1',
      sourceTable: 'notifications',
      sourceId: 'source-1',
      route: 'conversation',
      conversationId: 'conversation-1',
    },
  }),
};

test('push device endpoints require member authentication', async () => {
  const result = await request(app(service)).put('/push/devices').send({
    deviceId: 'device-123456',
    token: 'token-12345678901234567890',
  });
  assert.equal(result.status, 401);
});

test('authenticated device registration forwards the requested active state', async () => {
  let registration: unknown;
  const recordingService: PushService = {
    ...service,
    registerDevice: async (userId, deviceId, token, enabled) => {
      registration = {userId, deviceId, token, enabled};
    },
  };
  const result = await request(app(recordingService))
    .put('/push/devices')
    .set('Authorization', 'Bearer member-token')
    .send({
      deviceId: 'device-123456',
      token: 'token-12345678901234567890',
      enabled: false,
    });

  assert.equal(result.status, 204);
  assert.deepEqual(registration, {
    userId: 'member-1',
    deviceId: 'device-123456',
    token: 'token-12345678901234567890',
    enabled: false,
  });
});

test('push event endpoint validates its webhook secret', async () => {
  const result = await request(app(service))
    .post('/push/events')
    .send({type: 'INSERT', table: 'notifications', record: {}});
  assert.equal(result.status, 401);
});

test('push event endpoint returns the delivery result with the private secret', async () => {
  const result = await request(app(service))
    .post('/push/events')
    .set('x-cyanzone-webhook-secret', 'w'.repeat(32))
    .send({type: 'INSERT', table: 'notifications', record: {id: 'source-1'}});
  assert.equal(result.status, 200);
  assert.equal(result.body.status, 'delivered');
  assert.doesNotMatch(JSON.stringify(result.body), /wwwwww/);
});

test('authenticated members can resolve a push destination', async () => {
  const result = await request(app(service))
    .get('/push/events/notifications/source-1')
    .set('Authorization', 'Bearer member-token');
  assert.equal(result.status, 200);
  assert.equal(result.body.destination.route, 'conversation');
});
