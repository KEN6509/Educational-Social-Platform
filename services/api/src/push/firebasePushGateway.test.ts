import assert from 'node:assert/strict';
import test from 'node:test';

import { FirebasePushGateway } from './firebasePushGateway.js';

test('Firebase gateway builds a high-priority Android notification with string data', async () => {
  const sent: unknown[] = [];
  const gateway = new FirebasePushGateway({
    projectId: 'cyanzone-test',
    clientEmail: 'firebase@example.com',
    privateKey: 'not-used-by-injected-port',
    messaging: {
      sendEach: async (messages) => {
        sent.push(...messages);
        return {
          successCount: 1,
          responses: [{success: true}],
        };
      },
    },
  });

  const result = await gateway.send([{
    token: 'token-12345678901234567890',
    title: 'New message',
    body: 'A friend sent a message.',
    data: {version: '1', sourceId: 'event-1'},
    channelId: 'cyanzone_default',
  }]);

  assert.deepEqual(result, {successCount: 1, failures: []});
  assert.deepEqual(sent, [{
    token: 'token-12345678901234567890',
    notification: {
      title: 'New message',
      body: 'A friend sent a message.',
    },
    data: {version: '1', sourceId: 'event-1'},
    android: {
      priority: 'high',
      notification: {channelId: 'cyanzone_default'},
    },
  }]);
});

test('Firebase gateway classifies invalid and retryable token failures', async () => {
  const gateway = new FirebasePushGateway({
    projectId: 'cyanzone-test',
    clientEmail: 'firebase@example.com',
    privateKey: 'not-used-by-injected-port',
    messaging: {
      sendEach: async () => ({
        successCount: 0,
        responses: [
          {success: false, error: {code: 'messaging/registration-token-not-registered'}},
          {success: false, error: {code: 'messaging/server-unavailable'}},
        ],
      }),
    },
  });

  const result = await gateway.send([
    {
      token: 'token-invalid-12345678901234567890',
      title: 'A',
      body: 'B',
      data: {},
      channelId: 'cyanzone_default',
    },
    {
      token: 'token-retry-12345678901234567890',
      title: 'A',
      body: 'B',
      data: {},
      channelId: 'cyanzone_default',
    },
  ]);

  assert.equal(result.failures[0].invalidToken, true);
  assert.equal(result.failures[0].retryable, false);
  assert.equal(result.failures[1].invalidToken, false);
  assert.equal(result.failures[1].retryable, true);
});
