import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_room_page.dart';
import '../../chat/presentation/system_notification_detail_page.dart';
import '../../parent_child/data/parent_child_repository.dart';
import '../../parent_child/data/parent_supervision_models.dart';
import '../../parent_child/presentation/supervision_notification_router.dart';
import '../../posts/data/post_interaction_sync.dart';
import '../../posts/presentation/post_detail_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/http_push_repository.dart';
import '../domain/push_destination.dart';

typedef PushDestinationResolver = Future<ResolvedPushDestination?> Function(
  PushDestination destination,
);

/// Opens only typed, server-resolved destinations from an FCM tap.
class PushDestinationNavigator {
  const PushDestinationNavigator({required this.resolve});

  final PushDestinationResolver resolve;

  Future<void> open(BuildContext context, PushDestination destination) async {
    try {
      final resolved = await resolve(destination);
      if (!context.mounted) return;
      if (resolved == null) {
        throw StateError('Push destination could not be verified');
      }
      final target = resolved.destination;
      switch (target.route) {
        case PushRoute.conversation:
          await _openConversation(context, target);
        case PushRoute.post:
          await _openPost(context, target);
        case PushRoute.profile:
          await _openProfile(context, target);
        case PushRoute.systemNotification:
          await _openSystemNotification(context, target, resolved.source);
        case PushRoute.familyLink:
        case PushRoute.checkIn:
        case PushRoute.sos:
        case PushRoute.screenTime:
          await _openSupervisionNotification(context, target, resolved.source);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This notification is no longer available.')),
      );
    }
  }

  Future<void> _openConversation(
    BuildContext context,
    PushDestination destination,
  ) async {
    final id = destination.conversationId;
    if (id == null) throw StateError('Missing conversation destination');
    final conversations = await ChatRepository(
      Supabase.instance.client,
    ).fetchConversations();
    final conversation =
        conversations.where((item) => item.id == id).firstOrNull;
    if (conversation == null || !context.mounted) {
      throw StateError('Conversation is unavailable');
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
          builder: (_) => ChatRoomPage(conversation: conversation)),
    );
  }

  Future<void> _openPost(
    BuildContext context,
    PushDestination destination,
  ) async {
    final id = destination.postId;
    if (id == null) throw StateError('Missing post destination');
    final post = await ChatRepository(
      Supabase.instance.client,
    ).fetchPostForNotification(id);
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          post: post,
          initialCommentId: destination.commentId,
        ),
      ),
    );
    if (result != null) {
      PostInteractionSync.publish(
        postId: post.id,
        post: post,
        result: result,
      );
    }
  }

  Future<void> _openProfile(
    BuildContext context,
    PushDestination destination,
  ) async {
    final id = destination.profileId;
    if (id == null) throw StateError('Missing profile destination');
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ProfilePage(userId: id)),
    );
  }

  Future<void> _openSystemNotification(
    BuildContext context,
    PushDestination destination,
    Map<String, dynamic> source,
  ) async {
    final id = destination.notificationId;
    if (id == null) throw StateError('Missing system notification');
    final notification = _chatNotificationFromSource(source);
    if (notification.id != id || !context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SystemNotificationDetailPage(
          notification: notification,
        ),
      ),
    );
  }

  Future<void> _openSupervisionNotification(
    BuildContext context,
    PushDestination destination,
    Map<String, dynamic> source,
  ) async {
    final repository = ParentChildRepository(Supabase.instance.client);
    final notification = _supervisionNotificationFromSource(source);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (notification.id != destination.sourceId || currentUserId == null) {
      throw StateError('Supervision notification is unavailable');
    }
    final links = await repository.fetchLinks();
    if (!context.mounted) return;
    await SupervisionNotificationRouter(
      repository: repository,
      currentUserId: currentUserId,
      canManageSos: links.any(
        (link) =>
            link.status == FamilyLinkStatus.active &&
            link.parentId == currentUserId,
      ),
    ).open(context, notification);
  }
}

ChatNotification _chatNotificationFromSource(Map<String, dynamic> source) {
  return ChatNotification(
    id: _requiredSourceString(source, 'id'),
    type: _requiredSourceString(source, 'eventType'),
    title: _requiredSourceString(source, 'title'),
    body: _requiredSourceString(source, 'body'),
    createdAt: DateTime.parse(_requiredSourceString(source, 'createdAt')),
    actorId: _optionalSourceString(source, 'actorId'),
    postId: _optionalSourceString(source, 'postId'),
    commentId: _optionalSourceString(source, 'commentId'),
    actionType: _optionalSourceString(source, 'actionType'),
    actionPayload: source['actionPayload'] is Map
        ? Map<String, dynamic>.from(source['actionPayload'] as Map)
        : const {},
  );
}

SupervisionNotification _supervisionNotificationFromSource(
  Map<String, dynamic> source,
) {
  return SupervisionNotification.fromMap({
    'id': _requiredSourceString(source, 'id'),
    'event_type': _requiredSourceString(source, 'eventType'),
    'title': _requiredSourceString(source, 'title'),
    'body': _requiredSourceString(source, 'body'),
    'created_at': _requiredSourceString(source, 'createdAt'),
    'link_id': _optionalSourceString(source, 'linkId'),
    'check_in_id': _optionalSourceString(source, 'checkInId'),
    'sos_id': _optionalSourceString(source, 'sosId'),
    'child_id': _optionalSourceString(source, 'childId'),
  });
}

String _requiredSourceString(Map<String, dynamic> source, String key) {
  final value = _optionalSourceString(source, key);
  if (value == null) throw FormatException('Missing push source $key');
  return value;
}

String? _optionalSourceString(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

PushDestinationResolver httpPushDestinationResolver() {
  final repository = HttpPushRepository(
    accessToken: () async =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );
  return repository.resolveDestination;
}
