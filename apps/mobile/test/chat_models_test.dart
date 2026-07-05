import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatConversation', () {
    test('parses direct pending state with display title and unread count', () {
      final conversation = ChatConversation.fromMap({
        'id': 'conversation-1',
        'type': 'direct',
        'request_status': 'pending',
        'unread_count': 3,
        'other_user_id': 'user-2',
        'other_user_name': 'Taylor',
        'other_user_avatar_url': 'https://example.com/taylor.png',
      });

      expect(conversation.id, 'conversation-1');
      expect(conversation.type, ChatConversationType.direct);
      expect(conversation.requestStatus, ChatRequestStatus.pending);
      expect(conversation.unreadCount, 3);
      expect(conversation.displayTitle, 'Taylor');
      expect(conversation.isGroup, isFalse);
      expect(conversation.isRequest, isTrue);
    });
  });

  group('ChatMessage', () {
    test('trims body and detects current user ownership', () {
      final message = ChatMessage.fromMap(
        {
          'id': 'message-1',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-1',
          'body': '  Hello CyanZone  ',
          'created_at': '2026-06-26T10:30:00',
        },
        currentUserId: 'user-1',
      );

      expect(message.body, 'Hello CyanZone');
      expect(message.isMine, isTrue);
      expect(message.createdAt, DateTime(2026, 6, 26, 10, 30));
    });

    test('summarizes single and multiple image messages as photo', () {
      final single = ChatMessage.fromMap(
        {
          'id': 'message-2',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body': '${ChatMessage.imagePrefix}https://example.com/a.jpg',
          'created_at': '2026-06-26T10:31:00',
        },
        currentUserId: 'user-1',
      );
      final multi = ChatMessage.fromMap(
        {
          'id': 'message-3',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body':
              '${ChatMessage.multiImagePrefix}["https://example.com/a.jpg","https://example.com/b.jpg"]',
          'created_at': '2026-06-26T10:32:00',
        },
        currentUserId: 'user-1',
      );

      expect(single.imageUrls, ['https://example.com/a.jpg']);
      expect(single.displayBody, 'Photo');
      expect(multi.imageUrls, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
      expect(multi.displayBody, 'Photo');
    });

    test('parses image payload storage paths for cleanup', () {
      final single = ChatMessage.fromMap(
        {
          'id': 'message-5',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body':
              '${ChatMessage.imagePrefix}{"url":"https://example.com/a.jpg","path":"chat/u/c/a.jpg"}',
          'created_at': '2026-06-26T10:35:00',
        },
        currentUserId: 'user-1',
      );
      final multi = ChatMessage.fromMap(
        {
          'id': 'message-6',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body':
              '${ChatMessage.multiImagePrefix}[{"url":"https://example.com/a.jpg","path":"chat/u/c/a.jpg"},{"url":"https://example.com/b.jpg","path":"chat/u/c/b.jpg"}]',
          'created_at': '2026-06-26T10:36:00',
        },
        currentUserId: 'user-1',
      );

      expect(single.imageUrls, ['https://example.com/a.jpg']);
      expect(single.imageStoragePaths, ['chat/u/c/a.jpg']);
      expect(multi.imageUrls, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
      expect(multi.imageStoragePaths, ['chat/u/c/a.jpg', 'chat/u/c/b.jpg']);
    });

    test('parses chat image aspect ratios for collage layout', () {
      final message = ChatMessage.fromMap(
        {
          'id': 'message-7',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body':
              '${ChatMessage.multiImagePrefix}[{"url":"https://example.com/a.jpg","path":"chat/u/c/a.jpg","aspectRatio":0.7},{"url":"https://example.com/b.jpg","path":"chat/u/c/b.jpg","aspectRatio":1.2}]',
          'created_at': '2026-06-26T10:37:00',
        },
        currentUserId: 'user-1',
      );

      expect(message.imageAspectRatios, [0.7, 1.2]);
    });

    test('deleted image messages are not treated as active media', () {
      final message = ChatMessage.fromMap(
        {
          'id': 'message-4',
          'conversation_id': 'conversation-1',
          'sender_id': 'user-2',
          'body': '${ChatMessage.imagePrefix}https://example.com/a.jpg',
          'created_at': '2026-06-26T10:33:00',
          'deleted_at': '2026-06-26T10:34:00',
        },
        currentUserId: 'user-1',
      );

      expect(message.isDeleted, isTrue);
      expect(message.hasImage, isFalse);
    });
  });

  group('ChatNotification', () {
    test(
        'groups favorite as activity and system as system with unread/read states',
        () {
      final favorite = ChatNotification.fromMap({
        'id': 'notification-1',
        'type': 'favorite',
        'title': 'New favorite',
        'body': 'A user favorited your post.',
        'created_at': '2026-06-26T11:00:00',
      });
      final system = ChatNotification.fromMap({
        'id': 'notification-2',
        'type': 'system',
        'title': 'System notice',
        'body': 'Maintenance complete.',
        'created_at': '2026-06-26T12:00:00',
        'read_at': '2026-06-26T12:30:00',
      });

      expect(favorite.section, NotificationSection.activity);
      expect(favorite.isUnread, isTrue);
      expect(system.section, NotificationSection.system);
      expect(system.isUnread, isFalse);
    });

    test('groups follower and chat message notifications', () {
      final follower = ChatNotification.fromMap({
        'id': 'notification-3',
        'type': 'new_follower',
        'title': 'New follower',
        'body': 'A user followed you.',
        'created_at': '2026-06-26T13:00:00',
      });
      final chatMessage = ChatNotification.fromMap({
        'id': 'notification-4',
        'type': 'chat_message',
        'title': 'New message',
        'body': 'You have a new chat message.',
        'created_at': '2026-06-26T14:00:00',
      });

      expect(follower.section, NotificationSection.followers);
      expect(chatMessage.section, NotificationSection.chat);
    });

    test('parses post and comment metadata for activity notifications', () {
      final notification = ChatNotification.fromMap({
        'id': 'notification-activity-1',
        'type': 'comment_reply',
        'actor_id': 'actor-1',
        'post_id': 'post-1',
        'comment_id': 'comment-1',
        'title': 'Reply',
        'body': 'Someone replied',
        'created_at': '2026-07-05T10:15:00Z',
        'profiles': {'name': 'Ming', 'avatar_url': 'https://cdn/actor.png'},
        'posts': {
          'author_id': 'author-1',
          'profiles': {'avatar_url': 'https://cdn/post-author.png'},
          'post_images': [
            {
              'public_url': 'https://cdn/second.png',
              'position': 1,
            },
            {
              'public_url': 'https://cdn/first.png',
              'position': 0,
            },
          ],
        },
      });

      expect(notification.postId, 'post-1');
      expect(notification.commentId, 'comment-1');
      expect(notification.actorName, 'Ming');
      expect(notification.actorAvatarUrl, 'https://cdn/actor.png');
      expect(notification.postFirstImageUrl, 'https://cdn/first.png');
      expect(notification.postAuthorAvatarUrl, 'https://cdn/post-author.png');
      expect(notification.activityLabel, 'replied to your comment');
      expect(notification.activityGroup, NotificationActivityGroup.comments);
    });

    test('maps mention notifications to green mention activity group', () {
      final notification = ChatNotification.fromMap({
        'id': 'notification-mention-1',
        'type': 'mention',
        'title': 'Mention',
        'body': 'Someone mentioned you',
        'created_at': '2026-07-05T10:15:00Z',
      });

      expect(notification.activityLabel, 'mentioned you');
      expect(notification.activityGroup, NotificationActivityGroup.mentions);
    });
  });
}
