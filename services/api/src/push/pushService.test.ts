import assert from 'node:assert/strict';
import test from 'node:test';

import {
  categoryFor,
  createPushService,
  destinationFor,
} from './pushService.js';
import type {
  PushRepository,
  PushSourceRecord,
} from './pushRepository.js';
import type { PushGateway, PushMessage } from './pushTypes.js';

function source(overrides: Partial<PushSourceRecord> = {}): PushSourceRecord {
  return {
    id: 'source-1',
    userId: 'user-1',
    sourceTable: 'notifications',
    eventType: 'chat_message',
    title: 'New message',
    body: 'A friend sent a message.',
    actorId: 'actor-1',
    postId: null,
    commentId: null,
    conversationId: 'conversation-1',
    messageId: 'message-1',
    actionType: null,
    actionPayload: {},
    linkId: null,
    checkInId: null,
    sosId: null,
    childId: null,
    ...overrides,
  };
}

test('push event categories and destinations cover notification sources', () => {
  assert.equal(categoryFor(source({eventType: 'chat_message'})), 'chat');
  assert.equal(categoryFor(source({eventType: 'comment'})), 'activity');
  assert.equal(categoryFor(source({eventType: 'new_follower'})), 'followers');
  assert.equal(categoryFor(source({eventType: 'system'})), 'system');
  assert.deepEqual(
    destinationFor(source({eventType: 'chat_message'})),
    {
      version: '1',
      sourceTable: 'notifications',
      sourceId: 'source-1',
      notificationId: 'source-1',
      route: 'conversation',
      conversationId: 'conversation-1',
    },
  );
  assert.equal(
    destinationFor(source({
      sourceTable: 'supervision_notifications',
      eventType: 'sos_opened',
      sosId: 'sos-1',
    })).route,
    'sos',
  );
});

test('push service reloads the source, claims once, and sends a typed message', async () => {
  const sent: PushMessage[] = [];
  const completed: unknown[] = [];
  const gateway: PushGateway = {
    send: async (messages) => {
      sent.push(...messages);
      return {successCount: messages.length, failures: []};
    },
  };
  const repository: PushRepository = {
    registerDevice: async () => {},
    deactivateDevice: async () => {},
    loadSource: async () => source(),
    loadPreferences: async () => ({pushEnabled: true, categoryEnabled: true}),
    listActiveDevices: async () => [{
      id: 'device-row-1',
      userId: 'user-1',
      deviceId: 'installation-1',
      token: 'token-12345678901234567890',
    }],
    claimDelivery: async () => ({
      deliveryId: 'delivery-1',
      claimed: true,
      reason: 'claimed',
    }),
    completeDelivery: async (value) => {
      completed.push(value);
    },
    deactivateToken: async () => {},
  };

  const result = await createPushService(repository, gateway).processEvent({
    type: 'INSERT',
    table: 'notifications',
    record: {id: 'source-1', user_id: 'user-1', type: 'chat_message'},
  });

  assert.deepEqual(result, {
    status: 'delivered',
    deliveryId: 'delivery-1',
    successCount: 1,
    failureCount: 0,
  });
  assert.equal(sent[0].data.route, 'conversation');
  assert.equal(sent[0].data.conversationId, 'conversation-1');
  assert.deepEqual(completed, [{
    deliveryId: 'delivery-1',
    status: 'delivered',
    successCount: 1,
    failureCount: 0,
    lastErrorCode: undefined,
  }]);
});

test('push service skips disabled preferences and rejects mismatched webhook records', async () => {
  const repository: PushRepository = {
    registerDevice: async () => {},
    deactivateDevice: async () => {},
    loadSource: async () => source(),
    loadPreferences: async () => ({pushEnabled: false, categoryEnabled: true}),
    listActiveDevices: async () => [],
    claimDelivery: async () => ({deliveryId: 'delivery-1', claimed: true, reason: 'claimed'}),
    completeDelivery: async () => {},
    deactivateToken: async () => {},
  };
  const completed: unknown[] = [];
  repository.completeDelivery = async (value) => {
    completed.push(value);
  };
  const service = createPushService(repository, {
    send: async () => ({successCount: 0, failures: []}),
  });

  const skipped = await service.processEvent({
    table: 'notifications',
    record: {id: 'source-1', user_id: 'user-1'},
  });
  assert.equal(skipped.status, 'skipped');
  assert.equal((completed[0] as {status: string}).status, 'skipped');
  await assert.rejects(
    () => service.processEvent({
      table: 'notifications',
      record: {id: 'source-1', user_id: 'another-user'},
    }),
    /no longer available/i,
  );
});
