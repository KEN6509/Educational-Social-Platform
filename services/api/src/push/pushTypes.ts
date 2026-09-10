export type PushCategory = 'chat' | 'activity' | 'system' | 'followers';

export type PushDestination = {
  version: '1';
  sourceTable: 'notifications' | 'supervision_notifications';
  sourceId: string;
  route:
    | 'conversation'
    | 'post'
    | 'profile'
    | 'system_notification'
    | 'family_link'
    | 'check_in'
    | 'sos'
    | 'screen_time';
  notificationId?: string;
  conversationId?: string;
  postId?: string;
  commentId?: string;
  profileId?: string;
  linkId?: string;
  checkInId?: string;
  sosId?: string;
  childId?: string;
};

export type PushMessage = {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  channelId: 'cyanzone_default' | 'cyanzone_safety';
};

export type PushFailure = {
  token: string;
  code: string;
  invalidToken: boolean;
  retryable: boolean;
};

export type PushSendResult = {
  successCount: number;
  failures: PushFailure[];
};

export interface PushGateway {
  send(messages: readonly PushMessage[]): Promise<PushSendResult>;
}
