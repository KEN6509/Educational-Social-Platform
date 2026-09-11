import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../data/chat_models.dart';
import '../data/chat_mention.dart';
import '../../../core/widgets/unread_badge.dart';

part 'chat_message_bubbles.dart';
part 'chat_message_media.dart';

const chatNavy = Color(0xFF0B1F3E);
const chatCyan = Color(0xFF4490AD);
const chatBackground = Color(0xFFFAFCFC);
const chatInput = Colors.white;
const chatBorder = Color(0xFFE2E8F0);
const chatDanger = Color(0xFFE11D48);
const chatWhatsappBackground = Color(0xFFECE5DD);
const chatMineBubble = Color(0xFFD9FDD3);
const chatOtherBubble = Colors.white;
const chatSoftGrey = Color(0xFFF8FAFC);
const chatPreviewBackground = Color(0xFFF1F3F5);
const chatMentionAccent = Color(0xFF128C7E);

const chatAppBarTitleStyle = TextStyle(
  color: chatNavy,
  fontSize: 18,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.2,
);

const chatSectionTitleStyle = TextStyle(
  color: chatNavy,
  fontSize: 15,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.1,
);

const _groupColors = [
  Color(0xFF2563EB),
  Color(0xFF0F766E),
  Color(0xFFF97316),
  Color(0xFF7C3AED),
  Color(0xFF059669),
  Color(0xFFDB2777),
];

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

String _formatBubbleTime(DateTime value) {
  final local = value.toLocal();
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final hourValue = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final hour = hourValue.toString();
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

String _formatPreviewDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year} ${_formatBubbleTime(local)}';
}

String _formatChatTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  final difference = today.difference(date).inDays;
  if (difference == 0) {
    return _formatBubbleTime(local);
  }
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) return _weekdayLabel(local.weekday);
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    default:
      return 'Sun';
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
