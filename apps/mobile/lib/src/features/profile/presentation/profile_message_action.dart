import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/friendly_error.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_room_page.dart';
import '../data/user_profile.dart';

typedef ProfileConversationOpener = Future<String> Function(String userId);
typedef ProfileConversationNavigator = Future<void> Function(
  BuildContext context,
  ChatConversation conversation,
);

Future<void> openProfileMessage({
  required BuildContext context,
  required UserProfile profile,
  ProfileConversationOpener? openConversation,
  ProfileConversationNavigator? navigate,
}) async {
  try {
    final action = openConversation ??
        ChatRepository(Supabase.instance.client).openDirectConversation;
    final conversationId = await action(profile.id);
    if (!context.mounted) return;

    final conversation = ChatConversation.fromMap({
      'id': conversationId,
      'type': 'direct',
      'request_status': 'accepted',
      'unread_count': 0,
      'other_user_id': profile.id,
      'other_user_name': profile.name,
      'other_user_avatar_url': profile.avatarUrl,
    });

    if (navigate != null) {
      await navigate(context, conversation);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomPage(conversation: conversation),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    final text = error.toString().contains('Follow relationship required')
        ? 'Follow this user before sending a message.'
        : friendlyErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
