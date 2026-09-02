import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

typedef ParticipantLoader = Future<List<ChatParticipant>> Function();
typedef ParticipantSearch = Future<List<ChatParticipant>> Function(String term);
typedef GroupCreator = Future<String> Function(
    String? title, List<String> memberIds);

class CreateGroupChatPage extends StatefulWidget {
  const CreateGroupChatPage({
    super.key,
    this.loadSuggested,
    this.searchPeople,
    this.createGroup,
  });

  final ParticipantLoader? loadSuggested;
  final ParticipantSearch? searchPeople;
  final GroupCreator? createGroup;

  @override
  State<CreateGroupChatPage> createState() => _CreateGroupChatPageState();
}

class _CreateGroupChatPageState extends State<CreateGroupChatPage> {
  ChatRepository? _repository;
  late Future<List<ChatParticipant>> _peopleFuture;
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isCreating = false;

  ChatRepository get _repo =>
      _repository ??= ChatRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _peopleFuture = _loadSuggested();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ChatParticipant>> _loadSuggested() {
    return widget.loadSuggested?.call() ?? _repo.fetchSuggestedGroupMembers();
  }

  void _search(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _peopleFuture = _loadSuggested();
      } else {
        _peopleFuture = widget.searchPeople?.call(value) ??
            _repo.searchEligibleChatPeople(value);
      }
    });
  }

  void _toggle(ChatParticipant person) {
    setState(() {
      if (_selectedIds.contains(person.id)) {
        _selectedIds.remove(person.id);
      } else {
        _selectedIds.add(person.id);
      }
    });
  }

  Future<void> _create() async {
    if (_selectedIds.isEmpty || _isCreating) return;
    setState(() => _isCreating = true);
    try {
      final action = widget.createGroup ??
          (String? title, List<String> memberIds) {
            return _repo.createGroupConversation(
              title: title,
              memberIds: memberIds,
            );
          };
      final id = await action('Group chat', _selectedIds.toList());
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      assert(() {
        debugPrint('Create group chat failed: $error');
        return true;
      }());
      if (mounted) {
        final message = error.toString();
        final text = message.contains('Only followers') ||
                message.contains('follow relationship') ||
                message.contains('Cannot add group member')
            ? 'Only followers or people you follow can be added.'
            : message.contains('Group title')
                ? 'Could not create group because the group name is invalid.'
                : 'No internet connection';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
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
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: const Text('Create group chat', style: chatAppBarTitleStyle),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ChatSearchField(
                controller: _searchController,
                hintText: 'Search user',
                onChanged: _search,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ChatParticipant>>(
                future: _peopleFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ChatNoResultsState(
                      title: 'No internet connection',
                      subtitle: 'Connect to the internet to search people.',
                      icon: Icons.wifi_off_rounded,
                    );
                  }
                  final people = snapshot.data ?? const [];
                  if (people.isEmpty) {
                    return const ChatNoResultsState();
                  }

                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'Suggested'
                              : 'Search results',
                          style: const TextStyle(
                            color: chatNavy,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ...people.map((person) {
                        final selected = _selectedIds.contains(person.id);
                        return GestureDetector(
                          onTap: () => _toggle(person),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                ChatAvatar(
                                  name: person.name,
                                  avatarUrl: person.avatarUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(person.name)),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  color: selected ? chatCyan : chatBorder,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed:
                      _selectedIds.isEmpty || _isCreating ? null : _create,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(_isCreating ? 'Creating...' : 'Create'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
