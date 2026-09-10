import type {
  PushCategory,
  PushDestination,
  PushGateway,
  PushMessage,
  PushSendResult,
} from './pushTypes.js';
import {
  type PushRepository,
  type PushSourceRecord,
  type PushSourceTable,
} from './pushRepository.js';

export type PushWebhookEvent = {
  type?: string;
  table?: string;
  record?: Record<string, unknown>;
};

export type PushProcessResult = {
  status: 'delivered' | 'partial' | 'skipped' | 'failed';
  deliveryId?: string;
  successCount: number;
  failureCount: number;
};

export class PushServiceError extends Error {
  constructor(public readonly status: 400 | 404 | 500, message: string) {
    super(message);
    this.name = 'PushServiceError';
  }
}

export type PushService = {
  registerDevice(
    userId: string,
    deviceId: string,
    token: string,
    enabled: boolean,
  ): Promise<void>;
  deactivateDevice(userId: string, deviceId: string): Promise<void>;
  processEvent(event: PushWebhookEvent): Promise<PushProcessResult>;
  resolveDestination(
    userId: string,
    sourceTable: PushSourceTable,
    sourceId: string,
  ): Promise<{source: PushSourceRecord; destination: PushDestination}>;
};

export function createPushService(
  repository: PushRepository,
  gateway: PushGateway,
): PushService {
  return {
    registerDevice: (userId, deviceId, token, enabled) =>
      repository.registerDevice({userId, deviceId, token, enabled}),
    deactivateDevice: (userId, deviceId) =>
      repository.deactivateDevice(userId, deviceId),
    async processEvent(event) {
      const sourceTable = parseSourceTable(event.table);
      if (event.type != null && event.type !== 'INSERT') {
        throw new PushServiceError(400, 'Only INSERT push events are supported.');
      }
      const sourceId = stringValue(event.record?.id);
      const recordUserId = stringValue(event.record?.user_id);
      if (!sourceId || !recordUserId) {
        throw new PushServiceError(400, 'Push event is missing its source identity.');
      }

      const source = await repository.loadSource(sourceTable, sourceId);
      if (!source || source.userId !== recordUserId) {
        throw new PushServiceError(404, 'Push source is no longer available.');
      }
      const category = categoryFor(source);
      const claim = await repository.claimDelivery({
        sourceTable,
        sourceId,
        userId: source.userId,
        category,
      });
      if (!claim.claimed) {
        return {
          status: claim.reason === 'skipped'
              ? 'skipped'
              : claim.reason === 'delivered' || claim.reason === 'partial'
                  ? claim.reason
                  : 'skipped',
          deliveryId: claim.deliveryId,
          successCount: 0,
          failureCount: 0,
        };
      }

      const preferences = await repository.loadPreferences(source.userId, category);
      if (!preferences.pushEnabled || !preferences.categoryEnabled) {
        await repository.completeDelivery({
          deliveryId: claim.deliveryId,
          status: 'skipped',
          successCount: 0,
          failureCount: 0,
        });
        return {status: 'skipped', deliveryId: claim.deliveryId, successCount: 0, failureCount: 0};
      }

      const devices = await repository.listActiveDevices(source.userId);
      if (devices.length === 0) {
        await repository.completeDelivery({
          deliveryId: claim.deliveryId,
          status: 'skipped',
          successCount: 0,
          failureCount: 0,
        });
        return {status: 'skipped', deliveryId: claim.deliveryId, successCount: 0, failureCount: 0};
      }

      const destination = destinationFor(source);
      const messages = devices.map((device) => createMessage(source, destination, device.token));
      const first = await sendInBatches(gateway, messages);
      for (const failure of first.failures) {
        if (failure.invalidToken) await repository.deactivateToken(failure.token);
      }

      const status = first.failures.length === 0
        ? 'delivered'
        : first.successCount > 0
            ? 'partial'
            : 'failed';
      const lastErrorCode = first.failures[0]?.code;
      await repository.completeDelivery({
        deliveryId: claim.deliveryId,
        status,
        successCount: first.successCount,
        failureCount: first.failures.length,
        lastErrorCode,
      });
      return {
        status,
        deliveryId: claim.deliveryId,
        successCount: first.successCount,
        failureCount: first.failures.length,
      };
    },

    async resolveDestination(userId, sourceTable, sourceId) {
      const validatedSourceTable = parseSourceTable(sourceTable);
      const source = await repository.loadSource(validatedSourceTable, sourceId);
      if (!source || source.userId !== userId) {
        throw new PushServiceError(404, 'Push source is no longer available.');
      }
      return {source, destination: destinationFor(source)};
    },
  };
}

export function categoryFor(source: Pick<PushSourceRecord, 'sourceTable' | 'eventType'>): PushCategory {
  if (source.sourceTable === 'supervision_notifications') return 'system';
  switch (source.eventType) {
    case 'chat_message': return 'chat';
    case 'like':
    case 'favorite':
    case 'comment':
    case 'comment_reply':
    case 'comment_like':
    case 'mention': return 'activity';
    case 'new_follower': return 'followers';
    case 'system': return 'system';
    default: throw new PushServiceError(400, 'Unsupported push notification type.');
  }
}

export function destinationFor(source: PushSourceRecord): PushDestination {
  const base = {
    version: '1' as const,
    sourceTable: source.sourceTable,
    sourceId: source.id,
    notificationId: source.sourceTable === 'notifications' ? source.id : undefined,
  };
  if (source.sourceTable === 'supervision_notifications') {
    switch (source.eventType) {
      case 'link_request':
      case 'link_accepted':
      case 'link_rejected':
      case 'link_cancelled':
        return {...base, route: 'family_link', linkId: source.linkId ?? undefined};
      case 'check_in_sent':
      case 'check_in_received':
        return {...base, route: 'check_in', checkInId: source.checkInId ?? undefined};
      case 'sos_opened':
      case 'sos_acknowledged':
      case 'sos_resolved':
        return {...base, route: 'sos', sosId: source.sosId ?? undefined};
      case 'screen_time_threshold':
        return {...base, route: 'screen_time', childId: source.childId ?? undefined};
      default: throw new PushServiceError(400, 'Unsupported supervision push event.');
    }
  }
  switch (source.eventType) {
    case 'chat_message':
      return {...base, route: 'conversation', conversationId: source.conversationId ?? undefined};
    case 'new_follower':
      return {...base, route: 'profile', profileId: source.actorId ?? undefined};
    case 'system':
      return {...base, route: 'system_notification'};
    default:
      return {
        ...base,
        route: 'post',
        postId: source.postId ?? undefined,
        commentId: source.commentId ?? undefined,
      };
  }
}

function createMessage(
  source: PushSourceRecord,
  destination: PushDestination,
  token: string,
): PushMessage {
  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(destination)) {
    if (value != null) data[key] = String(value);
  }
  return {
    token,
    title: source.title || 'CyanZone',
    body: source.body || 'You have a new CyanZone notification.',
    data,
    channelId: destination.route === 'sos' ? 'cyanzone_safety' : 'cyanzone_default',
  };
}

async function sendInBatches(
  gateway: PushGateway,
  messages: PushMessage[],
): Promise<PushSendResult> {
  let successCount = 0;
  const failures = [] as PushSendResult['failures'];
  for (let start = 0; start < messages.length; start += 500) {
    const result = await sendWithOneRetry(
      gateway,
      messages.slice(start, start + 500),
    );
    successCount += result.successCount;
    failures.push(...result.failures);
  }
  return {successCount, failures};
}

async function sendWithOneRetry(
  gateway: PushGateway,
  messages: PushMessage[],
): Promise<PushSendResult> {
  let first: PushSendResult;
  try {
    first = await gateway.send(messages);
  } catch (_) {
    try {
      return await gateway.send(messages);
    } catch (_) {
      return {
        successCount: 0,
        failures: messages.map((message) => ({
          token: message.token,
          code: 'transport_unavailable',
          invalidToken: false,
          retryable: true,
        })),
      };
    }
  }
  const retryable = first.failures.filter((failure) => failure.retryable);
  if (retryable.length === 0) return first;
  let retry: PushSendResult;
  try {
    retry = await gateway.send(messages.filter((message) => retryable.some((failure) => failure.token === message.token)));
  } catch (_) {
    retry = {successCount: 0, failures: retryable};
  }
  const permanentFailures = first.failures.filter((failure) => !failure.retryable);
  return {
    successCount: first.successCount + retry.successCount,
    failures: [...permanentFailures, ...retry.failures],
  };
}

function parseSourceTable(value: string | undefined): PushSourceTable {
  if (value === 'notifications' || value === 'supervision_notifications') return value;
  throw new PushServiceError(400, 'Unsupported push source table.');
}

function stringValue(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}
