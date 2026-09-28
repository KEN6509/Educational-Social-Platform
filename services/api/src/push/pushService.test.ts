import assert from 'node:assert/strict';
import test from 'node:test';

import {
  categoryFor,
  createPushService,
  destinationFor,
  pushPresentationFor,
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
    createdAt: '2026-09-10T12:00:00.000Z',
    actorId: 'actor-1',
    postId: null,
    commentId: null,
    conversationId: 'conversation-1',
    messageId: 'message-1',
    actionType: null,
    actionPayload: {},
    actorName: null,
    conversationType: null,
    conversationTitle: null,
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

test('direct chat push uses the sender name and original message', () => {
  assert.deepEqual(
    pushPresentationFor(source({
      conversationType: 'direct',
      actorName: 'Ken',
      body: "How's it going?",
    })),
    {
      title: 'Ken',
      body: "How's it going?",
    },
  );
});

test('group chat push uses the group name and sender-prefixed message', () => {
  assert.deepEqual(
    pushPresentationFor(source({
      conversationType: 'group',
      conversationTitle: 'Classmates',
      actorName: 'Ken',
      body: "How's going guys?",
    })),
    {
      title: 'Classmates',
      body: "Ken: How's going guys?",
    },
  );
});

test('chat push safely falls back when related names are unavailable', () => {
  assert.deepEqual(
    pushPresentationFor(source({
      conversationType: 'group',
      conversationTitle: null,
      actorName: null,
    })),
    {
      title: 'New message',
      body: 'A friend sent a message.',
    },
  );
});

test('non-chat push keeps its stored presentation', () => {
  assert.deepEqual(
    pushPresentationFor(source({
      eventType: 'new_follower',
      title: 'New follower',
      body: 'Someone followed you.',
      actorName: 'Ken',
      conversationType: 'direct',
    })),
    {
      title: 'New follower',
      body: 'Someone followed you.',
    },
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

test('push service rejects an unsupported destination source at runtime', async () => {
  const repository = {
    registerDevice: async () => {},
    deactivateDevice: async () => {},
    loadSource: async () => source(),
    loadPreferences: async () => ({pushEnabled: true, categoryEnabled: true}),
    listActiveDevices: async () => [],
    claimDelivery: async () => ({deliveryId: 'delivery-1', claimed: true, reason: 'claimed'}),
    completeDelivery: async () => {},
    deactivateToken: async () => {},
  } satisfies PushRepository;
  const service = createPushService(repository, {
    send: async () => ({successCount: 0, failures: []}),
  });

  await assert.rejects(
    () => service.resolveDestination('user-1', 'profiles' as never, 'source-1'),
    /unsupported push source table/i,
  );
});

test('push service sends at most 500 devices in each Firebase batch', async () => {
  const batchSizes: number[] = [];
  const repository = {
    registerDevice: async () => {},
    deactivateDevice: async () => {},
    loadSource: async () => source(),
    loadPreferences: async () => ({pushEnabled: true, categoryEnabled: true}),
    listActiveDevices: async () => Array.from({length: 501}, (_, index) => ({
      id: `row-${index}`,
      userId: 'user-1',
      deviceId: `device-${index}`,
      token: `token-${index.toString().padStart(20, '0')}`,
    })),
    claimDelivery: async () => ({deliveryId: 'delivery-1', claimed: true, reason: 'claimed'}),
    completeDelivery: async () => {},
    deactivateToken: async () => {},
  } satisfies PushRepository;
  const service = createPushService(repository, {
    send: async (messages) => {
      batchSizes.push(messages.length);
      return {successCount: messages.length, failures: []};
    },
  });

  await service.processEvent({
    type: 'INSERT',
    table: 'notifications',
    record: {id: 'source-1', user_id: 'user-1'},
  });

  assert.deepEqual(batchSizes, [500, 1]);
});
