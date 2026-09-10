import type { PushCategory } from './pushTypes.js';

export type PushSourceTable = 'notifications' | 'supervision_notifications';

export type PushSourceRecord = {
  id: string;
  userId: string;
  sourceTable: PushSourceTable;
  eventType: string;
  title: string;
  body: string;
  createdAt: string;
  actorId: string | null;
  postId: string | null;
  commentId: string | null;
  conversationId: string | null;
  messageId: string | null;
  actionType: string | null;
  actionPayload: Record<string, unknown>;
  linkId: string | null;
  checkInId: string | null;
  sosId: string | null;
  childId: string | null;
};

export type PushPreferences = {
  pushEnabled: boolean;
  categoryEnabled: boolean;
};

export type PushDevice = {
  id: string;
  userId: string;
  deviceId: string;
  token: string;
};

export type PushDeliveryClaim = {
  deliveryId: string;
  claimed: boolean;
  reason: string;
};

export type PushRepository = {
  registerDevice(input: {
    userId: string;
    deviceId: string;
    token: string;
    enabled: boolean;
  }): Promise<void>;
  deactivateDevice(userId: string, deviceId: string): Promise<void>;
  loadSource(
    sourceTable: PushSourceTable,
    sourceId: string,
  ): Promise<PushSourceRecord | null>;
  loadPreferences(userId: string, category: PushCategory): Promise<PushPreferences>;
  listActiveDevices(userId: string): Promise<PushDevice[]>;
  claimDelivery(input: {
    sourceTable: PushSourceTable;
    sourceId: string;
    userId: string;
    category: PushCategory;
  }): Promise<PushDeliveryClaim>;
  completeDelivery(input: {
    deliveryId: string;
    status: 'delivered' | 'partial' | 'skipped' | 'failed';
    successCount: number;
    failureCount: number;
    lastErrorCode?: string;
  }): Promise<void>;
  deactivateToken(token: string): Promise<void>;
};

export type PushSupabaseClient = {
  from: (table: string) => any;
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: { message: string } | null }>;
};

export function createPushRepository(client: PushSupabaseClient): PushRepository {
  return {
    async registerDevice({userId, deviceId, token, enabled}) {
      const result = await client.rpc('register_push_device', {
        p_user_id: userId,
        p_device_id: deviceId,
        p_token: token,
        p_platform: 'android',
        p_is_active: enabled,
      });
      assertSuccess(result, 'Unable to register push device.');
    },

    async deactivateDevice(userId, deviceId) {
      const result = await client.rpc('deactivate_push_device', {
        p_user_id: userId,
        p_device_id: deviceId,
      });
      assertSuccess(result, 'Unable to deactivate push device.');
    },

    async loadSource(sourceTable, sourceId) {
      const columns = sourceTable === 'notifications'
        ? 'id,user_id,type,title,body,created_at,actor_id,post_id,comment_id,conversation_id,message_id,action_type,action_payload'
        : 'id,user_id,event_type,title,body,created_at,link_id,check_in_id,sos_id,child_id';
      const result = await client
        .from(sourceTable)
        .select(columns)
        .eq('id', sourceId)
        .maybeSingle();
      assertSuccess(result, 'Unable to read push source.');
      if (!result.data) return null;
      return mapSource(sourceTable, result.data as Record<string, unknown>);
    },

    async loadPreferences(userId, category) {
      const result = await client
        .from('notification_preferences')
        .select('push_enabled,chat_enabled,activity_enabled,system_enabled,followers_enabled')
        .eq('user_id', userId)
        .maybeSingle();
      assertSuccess(result, 'Unable to read notification preferences.');
      const row = (result.data ?? {}) as Record<string, unknown>;
      const categoryKey = `${category}_enabled`;
      return {
        pushEnabled: row.push_enabled === true,
        categoryEnabled: row[categoryKey] !== false,
      };
    },

    async listActiveDevices(userId) {
      const result = await client
        .from('push_device_tokens')
        .select('id,user_id,device_id,token')
        .eq('user_id', userId)
        .eq('is_active', true);
      assertSuccess(result, 'Unable to read push devices.');
      return (Array.isArray(result.data) ? result.data : []).map(mapDevice);
    },

    async claimDelivery(input) {
      const result = await client.rpc('claim_push_delivery', {
        p_source_table: input.sourceTable,
        p_source_id: input.sourceId,
        p_user_id: input.userId,
        p_category: input.category,
      });
      assertSuccess(result, 'Unable to claim push delivery.');
      const row = Array.isArray(result.data) ? result.data[0] : result.data;
      if (!row || typeof row !== 'object') {
        throw new Error('Unable to claim push delivery.');
      }
      const mapped = row as Record<string, unknown>;
      return {
        deliveryId: String(mapped.delivery_id),
        claimed: mapped.claimed === true,
        reason: String(mapped.reason ?? 'unknown'),
      };
    },

    async completeDelivery(input) {
      const result = await client.rpc('complete_push_delivery', {
        p_delivery_id: input.deliveryId,
        p_status: input.status,
        p_success_count: input.successCount,
        p_failure_count: input.failureCount,
        p_last_error_code: input.lastErrorCode ?? null,
      });
      assertSuccess(result, 'Unable to complete push delivery.');
    },

    async deactivateToken(token) {
      const result = await client
        .from('push_device_tokens')
        .update({is_active: false, updated_at: new Date().toISOString()})
        .eq('token', token);
      assertSuccess(result, 'Unable to deactivate invalid push token.');
    },
  };
}

function mapSource(
  sourceTable: PushSourceTable,
  row: Record<string, unknown>,
): PushSourceRecord {
  return {
    id: String(row.id),
    userId: String(row.user_id),
    sourceTable,
    eventType: String(row.type ?? row.event_type),
    title: String(row.title ?? ''),
    body: String(row.body ?? ''),
    createdAt: String(row.created_at ?? ''),
    actorId: nullableString(row.actor_id),
    postId: nullableString(row.post_id),
    commentId: nullableString(row.comment_id),
    conversationId: nullableString(row.conversation_id),
    messageId: nullableString(row.message_id),
    actionType: nullableString(row.action_type),
    actionPayload: isRecord(row.action_payload) ? row.action_payload : {},
    linkId: nullableString(row.link_id),
    checkInId: nullableString(row.check_in_id),
    sosId: nullableString(row.sos_id),
    childId: nullableString(row.child_id),
  };
}

function mapDevice(row: Record<string, unknown>): PushDevice {
  return {
    id: String(row.id),
    userId: String(row.user_id),
    deviceId: String(row.device_id),
    token: String(row.token),
  };
}

function nullableString(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function assertSuccess(
  result: {error: {message: string} | null},
  fallback: string,
): asserts result is {data: unknown; error: null} {
  if (result.error) throw new Error(`${fallback} ${result.error.message}`);
}
