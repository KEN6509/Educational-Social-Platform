import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import {
  getMessaging,
  type Message,
  type Messaging,
} from 'firebase-admin/messaging';

import type {
  PushFailure,
  PushGateway,
  PushMessage,
  PushSendResult,
} from './pushTypes.js';

type FirebaseResponse = {
  success: boolean;
  error?: { code?: string };
};

type FirebaseBatchResponse = {
  successCount: number;
  responses: readonly FirebaseResponse[];
};

type FirebaseMessagingPort = {
  sendEach(messages: readonly Message[]): Promise<FirebaseBatchResponse>;
};

export type FirebasePushGatewayOptions = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
  messaging?: FirebaseMessagingPort;
};

export class FirebasePushGateway implements PushGateway {
  private readonly messaging: FirebaseMessagingPort;

  constructor(options: FirebasePushGatewayOptions) {
    this.messaging = options.messaging ?? createMessaging(options);
  }

  async send(messages: readonly PushMessage[]): Promise<PushSendResult> {
    if (messages.length === 0) {
      return { successCount: 0, failures: [] };
    }

    const response = await this.messaging.sendEach(
      messages.map((message) => ({
        token: message.token,
        notification: {
          title: message.title,
          body: message.body,
        },
        data: message.data,
        android: {
          priority: 'high' as const,
          notification: {
            channelId: message.channelId,
          },
        },
      })),
    );

    return {
      successCount: response.successCount,
      failures: response.responses.flatMap((item, index) => {
        if (item.success) return [];
        const code = item.error?.code ?? 'messaging/unknown-error';
        return [{
          token: messages[index].token,
          code,
          invalidToken: isInvalidTokenError(code),
          retryable: isRetryableError(code),
        }];
      }),
    };
  }
}

function createMessaging(options: FirebasePushGatewayOptions): FirebaseMessagingPort {
  const app = getOrCreateApp(options);
  const messaging = getMessaging(app) as Messaging;
  return {
    sendEach: (messages) => messaging.sendEach(messages as Message[]),
  };
}

function getOrCreateApp(options: FirebasePushGatewayOptions): App {
  const existing = getApps().find((app) => app.name === 'cyanzone-push');
  if (existing) return existing;
  return initializeApp(
    {
      credential: cert({
        projectId: options.projectId,
        clientEmail: options.clientEmail,
        privateKey: options.privateKey,
      }),
    },
    'cyanzone-push',
  );
}

function isInvalidTokenError(code: string) {
  return code === 'messaging/invalid-registration-token' ||
    code === 'messaging/registration-token-not-registered';
}

function isRetryableError(code: string) {
  return code === 'messaging/internal-error' ||
    code === 'messaging/server-unavailable' ||
    code === 'messaging/unknown-error';
}
