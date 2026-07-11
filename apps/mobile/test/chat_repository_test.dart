import 'dart:io';

import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:cyanzone_mobile/src/features/chat/data/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatRepository', () {
    test('exposes stable RPC names', () {
      expect(
        ChatRepository.createDirectConversationRpc,
        'create_direct_conversation',
      );
      expect(
        ChatRepository.createGroupConversationRpc,
        'create_group_conversation',
      );
      expect(ChatRepository.sendChatMessageRpc, 'send_chat_message');
      expect(
        ChatRepository.acceptMessageRequestRpc,
        'accept_message_request',
      );
      expect(ChatRepository.clearChatRpc, 'clear_chat');
      expect(
        ChatRepository.renameGroupConversationRpc,
        'rename_group_conversation',
      );
      expect(ChatRepository.addGroupMembersRpc, 'add_group_members');
      expect(
        ChatRepository.exitGroupConversationRpc,
        'exit_group_conversation',
      );
      expect(ChatRepository.removeGroupMemberRpc, 'remove_group_member');
      expect(
        ChatRepository.deleteChatMessageForMeRpc,
        'delete_chat_message_for_me',
      );
      expect(
        ChatRepository.restoreChatMessageForMeRpc,
        'restore_chat_message_for_me',
      );
      expect(ChatRepository.unsendChatMessageRpc, 'unsend_chat_message');
      expect(
        ChatRepository.markConversationReadRpc,
        'mark_conversation_read',
      );
      expect(
        ChatRepository.markNotificationReadRpc,
        'mark_notification_read',
      );
      expect(
        ChatRepository.markNotificationSectionReadRpc,
        'mark_notification_section_read',
      );
    });

    test('exposes SQL function argument parameter keys', () {
      expect(
        ChatRepository.sendConversationIdParam,
        'p_conversation_id',
      );
      expect(ChatRepository.sendBodyParam, 'p_body');
      expect(
        ChatRepository.conversationIdParam,
        'p_conversation_id',
      );
      expect(
        ChatRepository.notificationIdParam,
        'p_notification_id',
      );
    });

    test(
        'normalizes search terms by trimming, lowercasing, and collapsing whitespace',
        () {
      expect(
          ChatRepository.normalizeSearchTerm('  Ming  Jiang '), 'ming jiang');
      expect(ChatRepository.normalizeSearchTerm(''), '');
    });

    test('removes chat image objects through Supabase Storage API', () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();

      expect(source, contains('deleteImageStoragePaths'));
      expect(source, contains(".storage.from('images').remove(paths)"));
      expect(source, isNot(contains(".storage.from('post-images')")));
    });

    test('last group exit removes chat image storage paths', () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      final start = source.indexOf('Future<void> exitGroupConversation');
      final end = source.indexOf('Future<void> removeGroupMember');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final exitSource = source.substring(start, end);
      expect(exitSource, contains('fetchMessages'));
      expect(exitSource, contains('imageStoragePaths'));
      expect(exitSource, contains('deleteImageStoragePaths'));
    });

    test('filters new followers to latest 30 days and one latest per actor',
        () {
      final now = DateTime(2026, 7, 5, 12);
      final notifications = [
        ChatNotification.fromMap({
          'id': 'old',
          'type': 'new_follower',
          'actor_id': 'u1',
          'title': 'New follower',
          'body': 'followed',
          'created_at': '2026-05-01T10:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'same-day-old',
          'type': 'new_follower',
          'actor_id': 'u2',
          'title': 'New follower',
          'body': 'followed',
          'created_at': '2026-07-05T09:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'same-day-new',
          'type': 'new_follower',
          'actor_id': 'u2',
          'title': 'New follower',
          'body': 'followed',
          'created_at': '2026-07-05T11:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'same-actor-previous-day',
          'type': 'new_follower',
          'actor_id': 'u2',
          'title': 'New follower',
          'body': 'followed',
          'created_at': '2026-07-04T11:00:00',
        }),
      ];

      final filtered = ChatRepository.visibleNewFollowerNotifications(
        notifications,
        now: now,
      );

      expect(filtered.map((item) => item.id), [
        'same-day-new',
      ]);
    });

    test('unread conversation count includes every unread message', () {
      final messages = [
        {
          'id': 'm1',
          'sender_id': 'other',
          'created_at': '2026-07-05T10:01:00',
        },
        {
          'id': 'm2',
          'sender_id': 'other',
          'created_at': '2026-07-05T10:02:00',
        },
        {
          'id': 'mine',
          'sender_id': 'me',
          'created_at': '2026-07-05T10:03:00',
        },
        {
          'id': 'old',
          'sender_id': 'other',
          'created_at': '2026-07-05T09:59:00',
        },
        {
          'id': 'deleted',
          'sender_id': 'other',
          'created_at': '2026-07-05T10:04:00',
          'deleted_at': '2026-07-05T10:05:00',
        },
      ];

      expect(
        ChatRepository.calculateUnreadConversationCount(
          messages: messages,
          currentUserId: 'me',
          lastReadAt: DateTime.parse('2026-07-05T10:00:00'),
        ),
        2,
      );
    });

    test('repository fetches unread message candidates beyond latest message',
        () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();

      expect(source, contains('_fetchUnreadMessagesByConversation'));
      expect(source, contains('unreadMessagesByConversation'));
      expect(source,
          isNot(contains('lastMessage == null ? const [] : [lastMessage]')));
    });

    test('conversation row time is hydrated from latest visible message', () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      final start = source
          .indexOf('Future<List<ChatConversation>> _hydrateConversations');
      final end = source.indexOf('static List<ChatNotification>', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final hydrateSource = source.substring(start, end);
      expect(
        hydrateSource,
        contains("..['last_message_at'] ="),
      );
      expect(
        hydrateSource,
        contains("lastMessagesByConversation[conversationId]?['created_at']"),
      );
    });

    test('repository fetches latest chat message page instead of full history',
        () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      final start = source.indexOf('Future<List<ChatMessage>> fetchMessages');
      final end = source.indexOf('Future<List<ChatNotification>>', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final fetchSource = source.substring(start, end);
      expect(fetchSource, contains(".order('created_at', ascending: false)"));
      expect(fetchSource, contains('.limit(50)'));
      expect(fetchSource, contains('a.createdAt.compareTo(b.createdAt)'));
    });

    test('filters activity notifications by category', () {
      final notifications = [
        ChatNotification.fromMap({
          'id': 'like',
          'type': 'like',
          'title': 'Like',
          'body': 'Like',
          'created_at': '2026-07-05T10:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'comment',
          'type': 'comment_reply',
          'title': 'Reply',
          'body': 'Reply',
          'created_at': '2026-07-05T10:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'mention',
          'type': 'mention',
          'title': 'Mention',
          'body': 'Mention',
          'created_at': '2026-07-05T10:00:00',
        }),
      ];

      expect(
        ChatRepository.filterActivityNotifications(
          notifications,
          NotificationActivityFilter.likesFavorites,
        ).map((item) => item.id),
        ['like'],
      );
      expect(
        ChatRepository.filterActivityNotifications(
          notifications,
          NotificationActivityFilter.comments,
        ).map((item) => item.id),
        ['comment'],
      );
      expect(
        ChatRepository.filterActivityNotifications(
          notifications,
          NotificationActivityFilter.mentions,
        ).map((item) => item.id),
        ['mention'],
      );
    });

    test('notification select includes post image and post author avatar data',
        () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();

      expect(source, contains('post_id'));
      expect(source, contains('comment_id'));
      expect(source, contains('posts!notifications_post_id_fkey'));
      expect(source, contains('post_images(public_url, position)'));
      expect(source, contains('profiles!posts_author_id_fkey(avatar_url)'));
    });

    test(
        'bottom badge counts notification sections as sources plus unread chats',
        () {
      final counts = {
        NotificationSection.activity: 5,
        NotificationSection.system: 2,
        NotificationSection.followers: 0,
        NotificationSection.chat: 9,
      };
      final conversations = [
        ChatConversation.fromMap({
          'id': 'c1',
          'type': 'direct',
          'request_status': 'accepted',
          'unread_count': 3,
        }),
        ChatConversation.fromMap({
          'id': 'c2',
          'type': 'group',
          'request_status': 'accepted',
          'unread_count': 0,
        }),
        ChatConversation.fromMap({
          'id': 'c3',
          'type': 'direct',
          'request_status': 'accepted',
          'unread_count': 1,
        }),
      ];

      expect(
        ChatRepository.bottomChatBadgeCount(
          notificationCounts: counts,
          conversations: conversations,
        ),
        4,
      );
    });

    test('unread notification counts dedupe visible new followers', () {
      final now = DateTime(2026, 7, 5, 12);
      final notifications = [
        ChatNotification.fromMap({
          'id': 'follower-latest',
          'type': 'new_follower',
          'actor_id': 'u1',
          'title': 'New follower',
          'body': 'followed',
          'created_at': '2026-07-05T11:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'follower-older',
          'type': 'new_follower',
          'actor_id': 'u1',
          'title': 'New follower',
          'body': 'followed',
          'created_at': '2026-07-04T11:00:00',
        }),
        ChatNotification.fromMap({
          'id': 'activity',
          'type': 'like',
          'title': 'Like',
          'body': 'liked',
          'created_at': '2026-07-05T11:00:00',
        }),
      ];

      final counts = ChatRepository.countUnreadNotificationSections(
        notifications,
        now: now,
      );

      expect(counts[NotificationSection.followers], 1);
      expect(counts[NotificationSection.activity], 1);
    });

    test('source contains section read marker and unread calculation', () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();

      expect(source, contains('markNotificationsReadForSection'));
      expect(source, contains('markNotificationSectionReadRpc'));
      expect(source, contains('section.name'));
      expect(source, contains('calculateUnreadConversationCount'));
      expect(source, contains('last_read_at'));
      expect(source, contains('cleared_at'));
    });

    test('follow back uses same insert pattern as profile follow', () {
      final source = File('lib/src/features/chat/data/chat_repository.dart')
          .readAsStringSync();
      final start = source.indexOf('Future<void> followUser');
      final end = source.indexOf('Future<List<ChatParticipant>>', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final followSource = source.substring(start, end);
      expect(followSource, contains('.insert({'));
      expect(followSource, isNot(contains('.upsert(')));
      expect(followSource,
          isNot(contains("onConflict: 'follower_id,following_id'")));
    });

    test('main shell uses total chat badge count instead of chat message only',
        () {
      final source = File('lib/src/features/shell/presentation/main_shell.dart')
          .readAsStringSync();

      expect(source, contains('fetchUnreadChatTabBadgeCount'));
      expect(source, isNot(contains('fetchUnreadChatCount();')));
    });
  });
}
