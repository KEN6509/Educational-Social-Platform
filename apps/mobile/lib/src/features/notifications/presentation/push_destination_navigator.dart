import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chat/data/chat_repository.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_room_page.dart';
import '../../chat/presentation/notification_sections_page.dart';
import '../../parent_child/presentation/parent_child_page.dart';
import '../../posts/presentation/post_detail_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/http_push_repository.dart';
import '../domain/push_destination.dart';

typedef PushDestinationResolver = Future<PushDestination?> Function(
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
      final target = resolved ?? destination;
      switch (target.route) {
        case PushRoute.conversation:
          await _openConversation(context, target);
        case PushRoute.post:
          await _openPost(context, target);
        case PushRoute.profile:
          await _openProfile(context, target);
        case PushRoute.systemNotification:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const NotificationSectionsPage(
                initialSection: NotificationSection.system,
              ),
            ),
          );
        case PushRoute.familyLink:
        case PushRoute.checkIn:
        case PushRoute.sos:
        case PushRoute.screenTime:
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const ParentChildPage()),
          );
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
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
    );
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
}

PushDestinationResolver httpPushDestinationResolver() {
  final repository = HttpPushRepository(
    accessToken: () async =>
        Supabase.instance.client.auth.currentSession?.accessToken,
  );
  return repository.resolveDestination;
}
