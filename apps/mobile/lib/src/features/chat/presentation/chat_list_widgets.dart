part of 'chat_widgets.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 46,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? 'C' : trimmed.characters.first.toUpperCase();

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: chatCyan.withValues(alpha: 0.14),
      foregroundImage: avatarUrl == null || avatarUrl!.isEmpty
          ? null
          : NetworkImage(avatarUrl!),
      child: Text(
        initial,
        style: const TextStyle(
          color: chatNavy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class NotificationEntryCard extends StatelessWidget {
  const NotificationEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 178,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chatBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: chatCyan),
                const Spacer(),
                UnreadBadge(count: count),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: chatNavy,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatNoSplash extends StatelessWidget {
  const ChatNoSplash({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.seed,
    this.size = 46,
  });

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _comfortableGroupColor(seed);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Icon(
        Icons.people_alt_rounded,
        color: color,
        size: size * 0.52,
      ),
    );
  }
}

Color _comfortableGroupColor(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return _groupColors[hash % _groupColors.length];
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: chatInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class ChatAvatarWithBadge extends StatelessWidget {
  const ChatAvatarWithBadge({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.count,
    this.size = 46,
  });

  final String name;
  final String? avatarUrl;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChatAvatar(name: name, avatarUrl: avatarUrl, size: size),
        if (count > 0)
          Positioned(
            right: -2,
            top: -4,
            child: UnreadBadge(count: count),
          ),
      ],
    );
  }
}

class ConversationTile extends StatefulWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final avatar = conversation.isGroup
        ? GroupAvatar(
            seed: conversation.id,
            size: 54,
          )
        : ChatAvatar(
            name: conversation.displayTitle,
            avatarUrl: conversation.otherUserAvatarUrl,
            size: 54,
          );
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: _pressed ? const Color(0xFFF8FAFC) : Colors.transparent,
        padding: const EdgeInsets.only(left: 18),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 13, 16, 13),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: chatNavy,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _formatChatTime(conversation.lastMessageAt),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _ConversationPreviewLine(
                      body: conversation.lastMessageBody,
                      fallback: conversation.isRequest
                          ? 'Message request'
                          : !conversation.isGroup &&
                                  !conversation.canSendMessages
                              ? 'Follow this user to continue chatting.'
                              : 'Start chatting',
                      unreadCount: conversation.unreadCount,
                      hasMention: conversation.hasUnvisitedMention,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationPreviewLine extends StatelessWidget {
  const _ConversationPreviewLine({
    required this.body,
    required this.fallback,
    required this.unreadCount,
    required this.hasMention,
  });

  final String? body;
  final String fallback;
  final int unreadCount;
  final bool hasMention;

  @override
  Widget build(BuildContext context) {
    final value = body?.trim();
    final hasImage = value != null && ChatMessage.bodyHasImage(value);
    final text = value == null || value.isEmpty
        ? fallback
        : ChatMessage.displayBodyFor(value);
    final textStyle = const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );

    if (!hasImage) {
      return Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          if (hasMention || unreadCount > 0) const SizedBox(width: 8),
          if (hasMention) ...[
            const _ConversationMentionIndicator(),
            if (unreadCount > 0) const SizedBox(width: 6),
          ],
          if (unreadCount > 0) UnreadBadge(count: unreadCount),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.image_outlined,
          size: 15,
          color: Color(0xFF64748B),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        if (hasMention || unreadCount > 0) const SizedBox(width: 8),
        if (hasMention) ...[
          const _ConversationMentionIndicator(),
          if (unreadCount > 0) const SizedBox(width: 6),
        ],
        if (unreadCount > 0) UnreadBadge(count: unreadCount),
      ],
    );
  }
}

class _ConversationMentionIndicator extends StatelessWidget {
  const _ConversationMentionIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('conversation-mention-indicator'),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: chatMentionAccent,
        shape: BoxShape.circle,
      ),
      child: Transform.translate(
        key: const ValueKey('conversation-mention-glyph'),
        offset: const Offset(0, -2),
        child: const Text(
          '@',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class ChatParticipantRow extends StatelessWidget {
  const ChatParticipantRow({
    super.key,
    required this.participant,
    this.onTap,
    this.trailing,
    this.showAdmin = false,
    this.contentPadding = EdgeInsets.zero,
  });

  final ChatParticipant participant;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showAdmin;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final action =
        showAdmin && participant.isAdmin ? const _AdminBadge() : trailing;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: contentPadding,
        child: Row(
          children: [
            ChatAvatar(
              name: participant.name,
              avatarUrl: participant.avatarUrl,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                participant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: chatNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              _ParticipantActionSlot(child: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParticipantActionSlot extends StatelessWidget {
  const _ParticipantActionSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Align(
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: chatCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Admin',
        style: TextStyle(
          color: chatCyan,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ChatNoResultsState extends StatelessWidget {
  const ChatNoResultsState({
    super.key,
    this.title = 'No results found',
    this.subtitle = 'Try another search',
    this.subtitleWidget,
    this.icon = Icons.search_off_rounded,
  });

  final String title;
  final String subtitle;
  final Widget? subtitleWidget;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Color(0xFF94A3B8), size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: chatNavy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            subtitleWidget ??
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: chatCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: chatCyan, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: chatNavy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
