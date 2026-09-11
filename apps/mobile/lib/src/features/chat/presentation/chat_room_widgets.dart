part of 'chat_room_page.dart';

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.conversation,
    required this.currentUserId,
    required this.scrollController,
    required this.selectedMessageIds,
    required this.messageKeys,
    required this.unreadDividerKey,
    required this.onMessageTap,
    required this.onMessageLongPress,
    required this.onSharedPostTap,
    required this.onMentionTap,
  });

  final List<ChatMessage> messages;
  final ChatConversation conversation;
  final String? currentUserId;
  final ScrollController scrollController;
  final Set<String> selectedMessageIds;
  final Map<String, GlobalKey> messageKeys;
  final GlobalKey unreadDividerKey;
  final ValueChanged<ChatMessage> onMessageTap;
  final ValueChanged<ChatMessage> onMessageLongPress;
  final ValueChanged<ChatSharedPost> onSharedPostTap;
  final ValueChanged<String> onMentionTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (conversation.isGroup) {
      final createdAt = conversation.createdAt ??
          (messages.isEmpty ? DateTime.now() : messages.first.createdAt);
      children
        ..add(_DateSeparator(date: createdAt))
        ..add(
          _GroupCreationNotice(
            conversation: conversation,
            currentUserId: currentUserId,
          ),
        );
    }
    final unreadCount = conversation.unreadCount;
    final rawFirstUnreadIndex = messages.length - unreadCount;
    final firstUnreadIndex = unreadCount <= 0
        ? -1
        : rawFirstUnreadIndex < 0
            ? 0
            : rawFirstUnreadIndex > messages.length
                ? messages.length
                : rawFirstUnreadIndex;
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      final previous = index == 0 ? null : messages[index - 1];
      final alreadyShowedCreationDate =
          conversation.isGroup && previous == null;
      if (!alreadyShowedCreationDate &&
          (previous == null ||
              !_isSameDate(previous.createdAt, message.createdAt))) {
        children.add(_DateSeparator(date: message.createdAt));
      }
      if (index == firstUnreadIndex) {
        children.add(
          _UnreadMessagesDivider(
            key: unreadDividerKey,
            count: unreadCount,
          ),
        );
      }
      children.add(
        ChatMessageBubble(
          key: messageKeys.putIfAbsent(message.id, GlobalKey.new),
          body: message.body,
          isMine: message.isMine,
          isDeleted: message.isDeleted,
          isSelected: selectedMessageIds.contains(message.id),
          isSelectionMode: selectedMessageIds.isNotEmpty,
          createdAt: message.createdAt,
          showSenderName: conversation.isGroup,
          senderName: message.senderName ?? 'Member',
          previewSenderName: message.isMine
              ? 'You'
              : (message.senderName ?? conversation.displayTitle),
          onTap: () => onMessageTap(message),
          onLongPress: () => onMessageLongPress(message),
          onSharedPostTap: onSharedPostTap,
          mentions: message.mentions,
          onMentionTap: onMentionTap,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF128C7E),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _MentionNavigationButton extends StatelessWidget {
  const _MentionNavigationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 42,
          child: Center(
            child: Transform.translate(
              key: const ValueKey('mention-navigation-glyph'),
              offset: const Offset(0, -2),
              child: const Text(
                '@',
                style: TextStyle(
                  color: chatMentionAccent,
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionSuggestionsPanel extends StatelessWidget {
  const _MentionSuggestionsPanel({
    required this.participants,
    required this.showAll,
    required this.onMemberTap,
    required this.onAllTap,
  });

  final List<ChatParticipant> participants;
  final bool showAll;
  final ValueChanged<ChatParticipant> onMemberTap;
  final VoidCallback onAllTap;

  @override
  Widget build(BuildContext context) {
    if (!showAll && participants.isEmpty) return const SizedBox.shrink();
    final rowCount = participants.length + (showAll ? 1 : 0);
    final panelHeight = (rowCount > 4 ? 4 : rowCount) * 60.0;
    return Container(
      key: const ValueKey('mention-suggestions-panel'),
      height: panelHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chatBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        key: const ValueKey('mention-suggestions-list'),
        padding: EdgeInsets.zero,
        itemCount: rowCount,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(left: 64),
          child: Divider(
            key: ValueKey('mention-suggestion-divider-$index'),
            height: 1,
            thickness: 1,
            color: const Color(0xFFF1F5F9),
          ),
        ),
        itemBuilder: (context, index) {
          if (showAll && index == 0) {
            return _MentionSuggestionRow(
              key: const ValueKey('mention-all-suggestion'),
              avatar: const CircleAvatar(
                radius: 20,
                backgroundColor: chatMentionAccent,
                child: Text(
                  '@',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: '@all',
              subtitle: 'Notify every group member',
              onTap: onAllTap,
            );
          }
          final person = participants[index - (showAll ? 1 : 0)];
          return _MentionSuggestionRow(
            key: ValueKey('mention-suggestion-${person.id}'),
            avatar: ChatAvatar(
              name: person.name,
              avatarUrl: person.avatarUrl,
              size: 40,
            ),
            title: person.name,
            onTap: () => onMemberTap(person),
          );
        },
      ),
    );
  }
}

class _MentionSuggestionRow extends StatelessWidget {
  const _MentionSuggestionRow({
    super.key,
    required this.avatar,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Widget avatar;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 59,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox.square(dimension: 40, child: avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: chatNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCreationNotice extends StatelessWidget {
  const _GroupCreationNotice({
    required this.conversation,
    required this.currentUserId,
  });

  final ChatConversation conversation;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final isMine = conversation.createdBy != null &&
        currentUserId != null &&
        conversation.createdBy == currentUserId;
    final creator = isMine ? 'You' : (conversation.createdByName ?? 'Someone');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: creator,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' created the group chat'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _formatDateSeparator(date),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadMessagesDivider extends StatelessWidget {
  const _UnreadMessagesDivider({
    super.key,
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 unread message' : '$count unread messages';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  final first = a.toLocal();
  final second = b.toLocal();
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatDateSeparator(DateTime value) {
  final now = DateTime.now();
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${local.day}/${local.month}/${local.year}';
}

class _WhatsAppRoomBackground extends StatelessWidget {
  const _WhatsAppRoomBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: chatWhatsappBackground,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ChatWallpaperPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 72.0;
    for (var y = 24.0; y < size.height; y += spacing) {
      for (var x = 18.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 10, paint);
        canvas.drawLine(Offset(x + 22, y - 8), Offset(x + 34, y + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
