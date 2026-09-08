import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../profile/presentation/profile_page.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

class EditGroupPage extends StatefulWidget {
  const EditGroupPage({
    super.key,
    required this.conversation,
    this.renameGroup,
  });

  final ChatConversation conversation;
  final Future<void> Function(String conversationId, String? title)?
      renameGroup;

  @override
  State<EditGroupPage> createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.conversation.title);
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final title = _controller.text.trim();
      final action = widget.renameGroup ??
          (String conversationId, String? value) =>
              ChatRepository(Supabase.instance.client).renameGroupConversation(
                conversationId: conversationId,
                title: value,
              );
      await action(widget.conversation.id, title.isEmpty ? null : title);
      if (mounted) Navigator.pop(context, title.isEmpty ? 'Group chat' : title);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: const Text('Edit group', style: chatAppBarTitleStyle),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text(
                'Done',
                style: TextStyle(
                  color: chatCyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('Group Name', style: chatSectionTitleStyle),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: 'Group chat',
                counterText: '',
                filled: true,
                fillColor: chatInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final count = value.text.characters.length.clamp(0, 100);
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$count/100',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({
    super.key,
    required this.conversation,
    this.showPreviewOnly = false,
  });

  final ChatConversation conversation;
  final bool showPreviewOnly;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  ChatRepository? _repository;
  final _searchController = TextEditingController();
  String _query = '';
  late Future<List<ChatParticipant>> _future = _loadMembers();

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _loadMembers();
    });
  }

  Future<List<ChatParticipant>> _loadMembers() async {
    try {
      return await _repo.fetchConversationParticipants(widget.conversation.id);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openAddMembers() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddGroupMembersPage(conversation: widget.conversation),
      ),
    );
    if (added == true) _refresh();
  }

  void _openProfile(ChatParticipant member) {
    if (member.id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: member.id,
          initialName: member.name,
          initialAvatarUrl: member.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChatParticipant>>(
      future: _future,
      builder: (context, snapshot) {
        final members = snapshot.data ?? const <ChatParticipant>[];
        final normalized = ChatRepository.normalizeSearchTerm(_query);
        final filteredMembers = normalized.isEmpty
            ? members
            : members
                .where(
                    (member) => member.name.toLowerCase().contains(normalized))
                .toList();
        final orderedMembers = [...filteredMembers]..sort((a, b) {
            if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        final visible =
            widget.showPreviewOnly ? orderedMembers.take(10) : orderedMembers;
        final currentUserId = _currentUserId;
        final isAdmin = members.any(
          (member) => member.id == currentUserId && member.isAdmin,
        );

        if (widget.showPreviewOnly) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _openAddMembers,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: const [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Add members',
                            style: TextStyle(
                              color: chatNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...visible.map(
                  (member) => ChatParticipantRow(
                    participant: member,
                    showAdmin: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    onTap: () => _openProfile(member),
                  ),
                ),
                if (members.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            GroupMembersPage(conversation: widget.conversation),
                      ),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 23,
                            backgroundColor: Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.format_list_bulleted_rounded,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              members.length > 10
                                  ? 'See all ${members.length} members'
                                  : 'See all members',
                              style: const TextStyle(
                                color: chatNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return ChatNoSplash(
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('Group members', style: chatAppBarTitleStyle),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ChatSearchField(
                  controller: _searchController,
                  hintText: 'Search members',
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                if (filteredMembers.isEmpty)
                  const ChatNoResultsState()
                else
                  ...orderedMembers.map(
                    (member) => _memberTile(
                      member,
                      canRemove: isAdmin &&
                          !member.isAdmin &&
                          member.id != currentUserId,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _memberTile(ChatParticipant member, {required bool canRemove}) {
    return ChatParticipantRow(
      participant: member,
      showAdmin: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      onTap: () => _openProfile(member),
      trailing: canRemove
          ? SizedBox.square(
              dimension: 24,
              child: IconButton(
                onPressed: () => _confirmRemoveMember(member),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: chatDanger.withValues(alpha: 0.08),
                  foregroundColor: chatDanger,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close_rounded, size: 13),
              ),
            )
          : null,
    );
  }

  Future<void> _confirmRemoveMember(ChatParticipant member) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.person_remove_rounded,
      iconColor: chatDanger,
      iconBackgroundColor: chatDanger.withValues(alpha: 0.1),
      title: 'Remove member?',
      message:
          "Remove ${member.name} from this group? They won't be able to send or receive new messages here.",
      primaryLabel: 'Remove',
      primaryColor: chatDanger,
    );
    if (confirmed != true) return;
    try {
      await _repo.removeGroupMember(
        conversationId: widget.conversation.id,
        memberId: member.id,
      );
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    }
  }
}

class AddGroupMembersPage extends StatefulWidget {
  const AddGroupMembersPage({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<AddGroupMembersPage> createState() => _AddGroupMembersPageState();
}

class _AddGroupMembersPageState extends State<AddGroupMembersPage> {
  late final ChatRepository _repo = ChatRepository(Supabase.instance.client);
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  late Future<List<ChatParticipant>> _future = _loadSuggestedMembers();
  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _future = value.trim().isEmpty
          ? _loadSuggestedMembers()
          : _searchEligibleMembers(value);
    });
  }

  Future<List<ChatParticipant>> _loadSuggestedMembers() async {
    final existing = await _repo.fetchConversationParticipants(
      widget.conversation.id,
    );
    final existingIds = existing.map((member) => member.id).toSet();
    final people = await _repo.fetchSuggestedGroupMembers();
    return people.where((person) => !existingIds.contains(person.id)).toList();
  }

  Future<List<ChatParticipant>> _searchEligibleMembers(String value) async {
    final existing = await _repo.fetchConversationParticipants(
      widget.conversation.id,
    );
    final existingIds = existing.map((member) => member.id).toSet();
    final people = await _repo.searchEligibleChatPeople(value);
    return people.where((person) => !existingIds.contains(person.id)).toList();
  }

  Future<void> _add() async {
    if (_selectedIds.isEmpty || _isAdding) return;
    setState(() => _isAdding = true);
    try {
      await _repo.addGroupMembers(
        conversationId: widget.conversation.id,
        memberIds: _selectedIds.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatNoSplash(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Add members', style: chatAppBarTitleStyle),
          actions: [
            TextButton(
              onPressed: _selectedIds.isEmpty || _isAdding ? null : _add,
              child: Text(_isAdding ? 'Adding...' : 'Done'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ChatSearchField(
                controller: _searchController,
                hintText: 'Search members',
                onChanged: _search,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ChatParticipant>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ChatNoResultsState(
                      title: 'No internet connection',
                      subtitle: 'Connect to the internet to search members.',
                      icon: Icons.wifi_off_rounded,
                    );
                  }
                  final people = snapshot.data ?? const <ChatParticipant>[];
                  if (people.isEmpty) return const ChatNoResultsState();
                  return ListView(
                    children: people.map((person) {
                      final selected = _selectedIds.contains(person.id);
                      return ChatParticipantRow(
                        participant: person,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        trailing: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected ? chatCyan : chatBorder,
                        ),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(person.id);
                            } else {
                              _selectedIds.add(person.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
