import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_group_pages.dart';
import 'chat_widgets.dart';

class ChatDetailsPage extends StatefulWidget {
  const ChatDetailsPage({
    super.key,
    required this.conversation,
    this.clearChat,
    this.renameGroup,
  });

  final ChatConversation conversation;
  final Future<void> Function(String conversationId)? clearChat;
  final Future<void> Function(String conversationId, String? title)?
      renameGroup;

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  bool _isClearing = false;
  late ChatConversation _conversation = widget.conversation;

  Future<void> _clear() async {
    final confirmed = await _confirmDangerAction(
      title: 'Clear this chat?',
      message:
          'Messages will disappear only from your account. Other members will still keep their copy.',
      actionLabel: 'Clear',
      icon: Icons.cleaning_services_rounded,
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      final action = widget.clearChat ??
          ChatRepository(Supabase.instance.client).clearChat;
      await action(widget.conversation.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _exitGroup() async {
    final confirmed = await _confirmDangerAction(
      title: 'Exit group?',
      message: 'You will stop receiving messages from this group.',
      actionLabel: 'Exit',
      icon: Icons.logout_rounded,
    );
    if (confirmed != true) return;
    try {
      await ChatRepository(Supabase.instance.client)
          .exitGroupConversation(widget.conversation.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    }
  }

  void _openContactProfile() {
    final userId = _conversation.otherUserId;
    if (_conversation.isGroup || userId == null || userId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: _conversation.otherUserId,
          initialName: _conversation.otherUserName,
          initialAvatarUrl: _conversation.otherUserAvatarUrl,
        ),
      ),
    );
  }

  Future<bool?> _confirmDangerAction({
    required String title,
    required String message,
    required String actionLabel,
    required IconData icon,
  }) {
    return showAppConfirmationDialog(
      context: context,
      icon: icon,
      iconColor: chatDanger,
      iconBackgroundColor: chatDanger.withValues(alpha: 0.1),
      title: title,
      message: message,
      primaryLabel: actionLabel,
      primaryColor: chatDanger,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: chatSoftGrey,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context, _conversation),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: Text(
            _conversation.isGroup ? 'Group Info' : 'Contact Info',
            style: chatAppBarTitleStyle,
          ),
          actions: [
            if (_conversation.isGroup)
              IconButton(
                tooltip: 'Edit group',
                onPressed: () async {
                  final title = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => EditGroupPage(
                        conversation: _conversation,
                        renameGroup: widget.renameGroup,
                      ),
                    ),
                  );
                  if (title != null && mounted) {
                    setState(() {
                      _conversation = _conversation.copyWith(title: title);
                    });
                  }
                },
                icon: const Icon(Icons.edit_rounded),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
          children: [
            _InfoHeader(
              conversation: _conversation,
              onTap: _conversation.isGroup ? null : _openContactProfile,
            ),
            const SizedBox(height: 20),
            if (_conversation.isGroup) ...[
              const _InfoSectionHeader('GROUP MEMBERS'),
              _InfoSection(
                children: [
                  GroupMembersPage(
                    conversation: _conversation,
                    showPreviewOnly: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            const _InfoSectionHeader('CHAT ACTIONS'),
            _InfoSection(
              children: [
                _InfoActionTile(
                  icon: Icons.cleaning_services_rounded,
                  title: 'Clear chat',
                  color: chatDanger,
                  trailing: _isClearing
                      ? const Icon(Icons.hourglass_empty_rounded)
                      : null,
                  onTap: _isClearing ? null : _clear,
                ),
                if (_conversation.isGroup) const Divider(height: 1, indent: 48),
                if (_conversation.isGroup)
                  _InfoActionTile(
                    icon: Icons.logout_rounded,
                    title: 'Exit Group',
                    color: chatDanger,
                    onTap: _exitGroup,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.conversation, this.onTap});

  final ChatConversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _InfoSection(
        children: [
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: [
                  conversation.isGroup
                      ? GroupAvatar(seed: conversation.id, size: 82)
                      : ChatAvatar(
                          name: conversation.displayTitle,
                          avatarUrl: conversation.otherUserAvatarUrl,
                          size: 82,
                        ),
                  const SizedBox(height: 12),
                  Text(
                    conversation.displayTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSectionHeader extends StatelessWidget {
  const _InfoSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoActionTile extends StatelessWidget {
  const _InfoActionTile({
    required this.icon,
    required this.title,
    required this.color,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
