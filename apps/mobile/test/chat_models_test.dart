import 'package:cyanzone_mobile/src/features/chat/data/chat_models.dart';
import 'package:cyanzone_mobile/src/features/chat/data/chat_mention.dart';
import 'package:cyanzone_mobile/src/features/chat/presentation/chat_mention_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMention', () {
    test('allows repeated occurrences but deduplicates recipients', () {
      const mentions = [
        ChatMention(userId: 'u1', displayText: '@Ava', start: 0, end: 4),
        ChatMention(userId: 'u1', displayText: '@Ava', start: 9, end: 13),
      ];

      expect(ChatMention.uniqueRecipientIds(mentions), ['u1']);
    });

    test('controller detects active query and inserts repeated mentions', () {
      final controller = ChatMentionController();

      expect(controller.queryFor('Hi @av', 6), 'av');
      final first = controller.insertMention(
        text: 'Hi @av',
        selectionOffset: 6,
        userId: 'u1',
        displayName: 'Ava',
      );
      final secondText = '${first.text}@a';
      final second = controller.insertMention(
        text: secondText,
        selectionOffset: secondText.length,
        userId: 'u1',
        displayName: 'Ava',
      );

      expect(second.text, 'Hi @Ava @Ava ');
      expect(second.mentions, hasLength(2));
      expect(ChatMention.uniqueRecipientIds(second.mentions), ['u1']);
    });

    test('controller removes a selected mention after its token is edited', () {
      final controller = ChatMentionController();
      final inserted = controller.insertMention(
        text: '@av',
        selectionOffset: 3,
        userId: 'u1',
        displayName: 'Ava',
      );

      final reconciled = controller.reconcile(
        previousText: inserted.text,
        text: inserted.text.replaceFirst('@Ava', '@Eva'),
      );

      expect(reconciled, isEmpty);
    });

    test('RPC offsets count Unicode code points instead of UTF-16 units', () {
      const body = '😀 hi @Ava';
      const mention = ChatMention(
        userId: 'u1',
        displayText: '@Ava',
        start: 6,
        end: 10,
      );

      expect(mention.toRpcMap(body)['start_offset'], 5);
      expect(mention.toRpcMap(body)['end_offset'], 9);
    });

    test('controller shifts intact mentions after an earlier text edit', () {
      final controller = ChatMentionController();
      final inserted = controller.insertMention(
        text: 'Hi @av',
        selectionOffset: 6,
        userId: 'u1',
        displayName: 'Ava',
      );

      final reconciled = controller.reconcile(
        previousText: inserted.text,
        text: 'Hello ${inserted.text}',
      );

      expect(reconciled.single.start, inserted.mentions.single.start + 6);
      expect(reconciled.single.matches('Hello ${inserted.text}'), isTrue);
    });
  });

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

  test('ChatMessage parses structured mention entities', () {
    final message = ChatMessage.fromMap({
      'id': 'm1',
      'conversation_id': 'c1',
      'sender_id': 'u2',
      'body': 'Hi @Ava',
      'created_at': '2026-07-12T00:00:00Z',
      'chat_message_mentions': [
        {
          'mentioned_user_id': 'u1',
          'display_text': '@Ava',
          'start_offset': 3,
          'end_offset': 7,
        }
      ],
    }, currentUserId: 'u1');

    expect(message.mentions.single.userId, 'u1');
    expect(message.mentions.single.matches(message.body), isTrue);
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

    test(
        'encodes shared post messages without exposing raw payload in previews',
        () {
      final body = ChatMessage.sharedPostBody(
        postId: 'post-1',
        authorName: 'Chan',
        authorAvatarUrl: 'https://example.com/avatar.jpg',
        title: 'Weekend hiking',
        content: 'A short trail guide.',
        imageUrl: 'https://example.com/post.jpg',
      );

      final sharedPost = ChatMessage.sharedPostFor(body);

      expect(sharedPost, isNotNull);
      expect(sharedPost!.postId, 'post-1');
      expect(sharedPost.title, 'Weekend hiking');
      expect(sharedPost.content, 'A short trail guide.');
      expect(sharedPost.imageUrl, 'https://example.com/post.jpg');
      expect(ChatMessage.displayBodyFor(body), 'Post');
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

    test('parses rejected post system notification metadata', () {
      final notification = ChatNotification.fromMap({
        'id': 'system-rejected-1',
        'type': 'system',
        'post_id': 'post-1',
        'title': 'Your post was not approved',
        'body': 'Full rejection message',
        'action_type': 'open_rejected_post',
        'action_payload': {
          'template_type': 'post_rejected',
          'post_title': 'My first post',
          'moderation_evidence': 'Image safety score exceeded',
          'scheduled_deletion_at': '2026-07-20T00:00:00Z',
        },
        'created_at': '2026-07-13T00:00:00Z',
      });

      expect(notification.actionType, 'open_rejected_post');
      expect(notification.systemTemplateType, 'post_rejected');
      expect(notification.systemDisplayTitle, 'Post has been rejected');
      expect(notification.systemPostTitle, 'My first post');
      expect(
        notification.moderationEvidence,
        'Image safety score exceeded',
      );
      expect(
        notification.scheduledDeletionAt,
        DateTime.parse('2026-07-20T00:00:00Z').toLocal(),
      );
      expect(notification.isPostRejection, isTrue);
      expect(notification.isCreatorAward, isFalse);
    });

    test('parses informational creator award system notification', () {
      final notification = ChatNotification.fromMap({
        'id': 'system-creator-1',
        'type': 'system',
        'title': 'You are now a verified content creator',
        'body': 'Congratulations',
        'action_type': 'none',
        'action_payload': {
          'template_type': 'creator_badge_awarded',
        },
        'created_at': '2026-07-13T00:00:00Z',
      });

      expect(notification.isCreatorAward, isTrue);
      expect(notification.isPostRejection, isFalse);
      expect(notification.systemDisplayTitle, 'Verification Application');
      expect(
        notification.systemBrief,
        'Your account verification application has been reviewed.',
      );
      expect(notification.systemDecisionLabel, 'Congratulations');
      expect(
        notification.systemDecisionMessage,
        'Your account is now verified as a CyanZone content creator.',
      );
      expect(notification.moderationEvidence,
          'No additional moderation evidence was provided.');
    });

    test('separates a published-post greeting from its decision message', () {
      final notification = ChatNotification.fromMap({
        'id': 'system-post-approved-1',
        'type': 'system',
        'post_id': 'post-1',
        'title': 'Your post was published successfully',
        'body':
            'Hi Ava,\n\nYour post “Morning walk” passed moderation and was published successfully.',
        'created_at': '2026-08-02T00:00:00Z',
        'action_payload': {
          'template_type': 'post_approved',
          'post_title': 'Morning walk',
          'brief': 'Hi Ava,',
        },
      });

      expect(
        notification.systemBrief,
        'Your post has completed moderation review.',
      );
      expect(
        notification.systemDecisionMessage,
        'Your post “Morning walk” passed moderation and was published successfully.',
      );
    });

    test('maps structured reported-post removal and appeal eligibility', () {
      final postRemoval = ChatNotification.fromMap({
        'id': 'system-report-post-1',
        'type': 'system',
        'post_id': 'post-1',
        'title': 'Content removed after reports',
        'body': 'Your post was removed.',
        'created_at': '2026-08-02T00:00:00Z',
        'action_payload': {
          'template_type': 'reported_post_removed',
          'brief': 'We reviewed reports about your post.',
          'decision_label': 'Decision',
          'decision_message': 'The post breaks the safety guideline.',
        },
      });
      final commentRemoval = ChatNotification.fromMap({
        'id': 'system-report-comment-1',
        'type': 'system',
        'post_id': 'post-1',
        'comment_id': 'comment-1',
        'title': 'Content removed after reports',
        'body': 'Your comment was removed.',
        'created_at': '2026-08-02T00:00:00Z',
        'action_payload': {
          'template_type': 'reported_comment_removed',
        },
      });

      expect(postRemoval.systemBrief, 'We reviewed reports about your post.');
      expect(postRemoval.systemDecisionLabel, 'Decision');
      expect(
        postRemoval.systemDecisionMessage,
        'The post breaks the safety guideline.',
      );
      expect(postRemoval.isAppealableModerationNotification, isTrue);
      expect(commentRemoval.isAppealableModerationNotification, isFalse);
    });

    test('keeps legacy reported-post removal notices appealable', () {
      final notification = ChatNotification.fromMap({
        'id': 'legacy-system-report-post-1',
        'type': 'system',
        'post_id': 'post-1',
        'title': 'Content removed after reports',
        'body': 'Your post was removed after reviewing community reports.',
        'created_at': '2026-08-01T00:00:00Z',
        'action_payload': {'post_id': 'post-1'},
      });

      expect(notification.systemTemplateType, 'reported_post_removed');
      expect(notification.postId, 'post-1');
      expect(notification.isAppealableModerationNotification, isTrue);
    });

    test('only original rejected or report-removed post notices are appealable',
        () {
      ChatNotification notification(String templateType) =>
          ChatNotification.fromMap({
            'id': templateType,
            'type': 'system',
            'post_id': 'post-1',
            'title': 'Update',
            'body': 'Update body',
            'created_at': '2026-08-02T00:00:00Z',
            'action_payload': {'template_type': templateType},
          });

      expect(notification('post_rejected').isAppealableModerationNotification,
          isTrue);
      expect(
        notification('reported_post_removed')
            .isAppealableModerationNotification,
        isTrue,
      );
      expect(
          notification('post_appeal_rejected')
              .isAppealableModerationNotification,
          isFalse);
      expect(
          notification('creator_request_rejected')
              .isAppealableModerationNotification,
          isFalse);
    });
  });
}
