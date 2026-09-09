import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createPushRepository,
  type PushSupabaseClient,
} from './pushRepository.js';

test('push repository calls service-role device registration and delivery RPCs', async () => {
  const calls: Array<{name: string; args: Record<string, unknown>}> = [];
  const client: PushSupabaseClient = {
    from: () => {
      throw new Error('from should not be called');
    },
    rpc: async (name, args) => {
      calls.push({name, args});
      if (name === 'claim_push_delivery') {
        return {
          data: [{delivery_id: 'delivery-1', claimed: true, reason: 'claimed'}],
          error: null,
        };
      }
      return {data: null, error: null};
    },
  };
  const repository = createPushRepository(client);

  await repository.registerDevice({
    userId: 'user-1',
    deviceId: 'device-1',
    token: 'token-12345678901234567890',
  });
  const claim = await repository.claimDelivery({
    sourceTable: 'notifications',
    sourceId: 'source-1',
    userId: 'user-1',
    category: 'chat',
  });

  assert.deepEqual(calls, [
    {
      name: 'register_push_device',
      args: {
        p_user_id: 'user-1',
        p_device_id: 'device-1',
        p_token: 'token-12345678901234567890',
        p_platform: 'android',
      },
    },
    {
      name: 'claim_push_delivery',
      args: {
        p_source_table: 'notifications',
        p_source_id: 'source-1',
        p_user_id: 'user-1',
        p_category: 'chat',
      },
    },
  ]);
  assert.deepEqual(claim, {
    deliveryId: 'delivery-1',
    claimed: true,
    reason: 'claimed',
  });
});

test('push repository reloads the authoritative notification and recipient preferences', async () => {
  const tables: Record<string, Record<string, unknown>> = {
    notifications: {
      id: 'notification-1',
      user_id: 'user-1',
      type: 'chat_message',
      title: 'New message',
      body: 'A friend sent a message.',
      conversation_id: 'conversation-1',
      action_payload: {route: 'conversation'},
    },
    notification_preferences: {
      push_enabled: true,
      chat_enabled: true,
      activity_enabled: false,
      system_enabled: true,
      followers_enabled: true,
    },
  };
  const client: PushSupabaseClient = {
    from: (table) => {
      const value = tables[table];
      return {
        select: () => ({
          eq: () => ({
            eq: () => Promise.resolve({data: value ? [value] : [], error: null}),
            maybeSingle: () => Promise.resolve({data: value ?? null, error: null}),
          }),
        }),
      };
    },
    rpc: async () => ({data: null, error: null}),
  };
  const repository = createPushRepository(client);

  const source = await repository.loadSource('notifications', 'notification-1');
  const preferences = await repository.loadPreferences('user-1', 'chat');

  assert.equal(source?.userId, 'user-1');
  assert.equal(source?.conversationId, 'conversation-1');
  assert.deepEqual(preferences, {pushEnabled: true, categoryEnabled: true});
});
