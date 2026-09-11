part of 'post_detail_page.dart';

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.post,
    required this.onToggleDislike,
    required this.onShare,
    required this.onReport,
    this.showOwnerActions = false,
    this.onEdit,
    this.onDelete,
  });

  final FeedPost post;
  final VoidCallback onToggleDislike;
  final Future<void> Function() onShare;
  final VoidCallback onReport;
  final bool showOwnerActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  static List<ChatConversation> _recentShareContactsCache =
      const <ChatConversation>[];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final ChatRepository _chatRepository;
  List<ChatConversation> _allContacts = [];
  List<ChatConversation> _selectedContacts = [];
  final Set<String> _tickedConversationIds = {};
  List<ChatConversation> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingContacts = true;
  bool _isSending = false;
  bool _isSheetExpanded = false;
  double? _sheetDragHeight;
  late final ScrollController _scrollController;
  final ScrollController _searchScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatRepository = ChatRepository(Supabase.instance.client);
    _scrollController = ScrollController();
    _searchFocusNode.addListener(_onSearchFocusChange);
    if (_recentShareContactsCache.isNotEmpty) {
      _allContacts = List<ChatConversation>.from(_recentShareContactsCache);
      _selectedContacts = _allContacts.take(9).toList();
      _searchResults = List.from(_allContacts);
      _isLoadingContacts = false;
    }
    _loadRecentContacts();
  }

  Future<void> _loadRecentContacts() async {
    try {
      final conversations = await _chatRepository.fetchConversations();
      if (!mounted) return;
      setState(() {
        _allContacts = conversations
            .where((conversation) => !conversation.isRequest)
            .toList();
        _recentShareContactsCache = List<ChatConversation>.from(_allContacts);
        _selectedContacts = _allContacts.take(9).toList();
        _searchResults = List.from(_allContacts);
        _isLoadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (_recentShareContactsCache.isNotEmpty) {
        setState(() => _isLoadingContacts = false);
        return;
      }
      setState(() {
        _allContacts = const [];
        _selectedContacts = const [];
        _searchResults = const [];
        _isLoadingContacts = false;
      });
    }
  }

  void _onSearchFocusChange() {
    // Triggers height change when search bar is focused
    if (mounted) {
      setState(() {
        // When focusing, we are "searching" even if query is empty
        if (_searchFocusNode.hasFocus) {
          _isSearching = _searchController.text.isNotEmpty;
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchScrollController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = List.from(_allContacts);
      });
      return;
    }

    final normalized = query.toLowerCase().trim();
    setState(() {
      _isSearching = true;
      _searchResults = _allContacts
          .where(
            (conversation) =>
                conversation.displayTitle.toLowerCase().contains(normalized),
          )
          .toList();
    });
  }

  void _addContact(ChatConversation contact) {
    setState(() {
      if (!_selectedContacts.any((c) => c.id == contact.id)) {
        _selectedContacts.add(contact);
      }
      _tickedConversationIds.add(contact.id);
      _isSearching = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
    });
  }

  void _toggleSelection(String conversationId) {
    setState(() {
      if (_tickedConversationIds.contains(conversationId)) {
        _tickedConversationIds.remove(conversationId);
      } else {
        _tickedConversationIds.add(conversationId);
      }
    });
  }

  Future<void> _sendSharedPost() async {
    if (_tickedConversationIds.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    final body = ChatMessage.sharedPostBody(
      postId: widget.post.id,
      authorName: widget.post.authorName,
      authorAvatarUrl: widget.post.authorAvatarUrl,
      title: widget.post.title,
      content: widget.post.content,
      imageUrl: widget.post.imageUrls.firstOrNull,
    );

    try {
      for (final conversationId in _tickedConversationIds) {
        await _chatRepository.sendMessage(
          conversationId: conversationId,
          body: body,
        );
      }
      try {
        await widget.onShare();
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context);
      _showShareSnackBar('Post sent.', success: true);
    } catch (_) {
      if (!mounted) return;
      _showShareSnackBar('No internet connection');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showShareSnackBar(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white,
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
              color:
                  success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double statusBarHeight = view.padding.top / view.devicePixelRatio;
    final double defaultHeight = _defaultSheetHeight(context);
    final double expandedHeight = screenHeight - statusBarHeight - 8;
    final bool isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final bool isInputMode =
        _searchFocusNode.hasFocus || _isSearching || isKeyboardOpen;
    final double currentHeight = _sheetDragHeight ??
        (isInputMode || _isSheetExpanded ? expandedHeight : defaultHeight);

    return PopScope(
      canPop: !isInputMode && !_isSheetExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isInputMode) {
          setState(() {
            _searchFocusNode.unfocus();
            _isSearching = false;
            _searchController.clear();
          });
        } else if (!didPop && _isSheetExpanded) {
          setState(() => _isSheetExpanded = false);
        }
      },
      child: GestureDetector(
        onVerticalDragStart: (_) => _startSheetDrag(currentHeight),
        onVerticalDragUpdate: (details) => _updateSheetDrag(
          details,
          minHeight: defaultHeight,
          maxHeight: expandedHeight,
        ),
        onVerticalDragEnd: _handleSheetDragEnd,
        behavior: HitTestBehavior.translucent,
        child: AnimatedContainer(
          duration: _sheetDragHeight == null
              ? const Duration(milliseconds: 300)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          height: currentHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Redesigned Search Bar (matching main_shell.dart style)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearch,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                            fontSize: 15, color: Color(0xFF1E293B)),
                        decoration: appSearchInputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 20, color: Color(0xFF94A3B8)),
                          suffixIcon: _isSearching
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                    _onSearch('');
                                  },
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 20,
                                    color: Color(0xFF94A3B8),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  // Scrollable Content
                  Expanded(
                    child: Stack(
                      children: [
                        // Friends Grid (Hidden when in input mode)
                        if (!isInputMode)
                          Scrollbar(
                            controller: _scrollController,
                            thickness: 4,
                            radius: const Radius.circular(2),
                            child: ListView(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              children: [
                                if (_isLoadingContacts)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 30),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF4490AD),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (_selectedContacts.isEmpty)
                                  _buildEmptyState()
                                else
                                  _buildContactGrid(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        // Search Results Overlay
                        if (isInputMode)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white,
                              child: Scrollbar(
                                controller: _searchScrollController,
                                child: ListView.builder(
                                  controller: _searchScrollController,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final contact = _searchResults[index];
                                    return ListTile(
                                      leading: _ShareContactAvatar(
                                        conversation: contact,
                                        radius: 22,
                                      ),
                                      title: Text(
                                        contact.displayTitle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      trailing: _tickedConversationIds
                                              .contains(contact.id)
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF4490AD))
                                          : null,
                                      onTap: () => _addContact(contact),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Fixed Quick Actions Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                        0, 12, 0, 24), // Added bottom padding
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: _buildActionRow(),
                  ),
                ],
              ),
              // Send Button Overlay with Background
              if (_tickedConversationIds.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                        16, 12, 16, 32), // Increased bottom padding
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4490AD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSending ? null : _sendSharedPost,
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _tickedConversationIds.length == 1
                                        ? 'Send'
                                        : 'Send separately',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSheetDrag(double currentHeight) {
    setState(() => _sheetDragHeight = currentHeight);
  }

  void _updateSheetDrag(
    DragUpdateDetails details, {
    required double minHeight,
    required double maxHeight,
  }) {
    final currentHeight = _sheetDragHeight ?? minHeight;
    final nextHeight = (currentHeight - details.delta.dy).clamp(
      minHeight,
      maxHeight,
    );
    setState(() => _sheetDragHeight = nextHeight.toDouble());
  }

  void _handleSheetDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final mediaQuery = MediaQuery.of(context);
    final view = View.of(context);
    final statusBarHeight = view.padding.top / view.devicePixelRatio;
    final minHeight = _defaultSheetHeight(context);
    final maxHeight = mediaQuery.size.height - statusBarHeight - 8;
    final currentHeight =
        _sheetDragHeight ?? (_isSheetExpanded ? maxHeight : minHeight);
    final midpoint = minHeight + ((maxHeight - minHeight) * 0.5);
    final shouldExpand =
        velocity < -180 || (velocity.abs() <= 180 && currentHeight > midpoint);

    setState(() {
      _sheetDragHeight = null;
      _isSheetExpanded = shouldExpand;
      if (!shouldExpand) {
        _searchFocusNode.unfocus();
        _isSearching = false;
        _searchController.clear();
      }
    });
  }

  double _defaultSheetHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    const handleHeight = 24.0;
    const searchHeight = 56.0;
    const actionBarHeight = 127.0;
    final contentHeight = _recentContactsContentHeight;
    final targetHeight =
        handleHeight + searchHeight + contentHeight + actionBarHeight;
    return targetHeight.clamp(screenHeight * 0.34, screenHeight * 0.5);
  }

  double get _recentContactsContentHeight {
    if (_isLoadingContacts || _selectedContacts.isEmpty) {
      return 124;
    }
    return _recentContactRows * 108.0 + 12;
  }

  int get _recentContactRows {
    if (_selectedContacts.isEmpty) return 1;
    return ((_selectedContacts.length + 2) ~/ 3).clamp(1, 3);
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 40, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          const Text(
            'No recent chats',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Open Messages'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactGrid() {
    final gridHeight = _recentContactRows * 108.0;
    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedContacts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 0,
          crossAxisSpacing: 0,
          childAspectRatio: 1.12,
        ),
        itemBuilder: (context, index) {
          final contact = _selectedContacts[index];
          final isSelected = _tickedConversationIds.contains(contact.id);
          return GestureDetector(
            onTap: () => _toggleSelection(contact.id),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Stack(
                  children: [
                    _ShareContactAvatar(
                      conversation: contact,
                      radius: 38,
                    ),
                    if (isSelected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 24,
                            color: Color(0xFF4490AD),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    contact.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: widget.showOwnerActions
              ? [
                  _ActionGridItem(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onEdit?.call();
                    },
                  ),
                  const SizedBox(width: 20),
                  _ActionGridItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: const Color(0xFFDC2626),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDelete?.call();
                    },
                  ),
                ]
              : [
                  _ActionGridItem(
                    icon: Icons.sentiment_dissatisfied_rounded,
                    label: 'Dislike',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onToggleDislike();
                    },
                  ),
                  const SizedBox(width: 20),
                  _ActionGridItem(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onReport();
                    },
                  ),
                ],
        ),
      ),
    );
  }
}

class _ShareContactAvatar extends StatelessWidget {
  const _ShareContactAvatar({
    required this.conversation,
    required this.radius,
  });

  final ChatConversation conversation;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (conversation.isGroup) {
      return GroupAvatar(
        seed: conversation.id,
        size: radius * 2,
      );
    }

    return ChatAvatar(
      name: conversation.displayTitle,
      avatarUrl: conversation.otherUserAvatarUrl,
      size: radius * 2,
    );
  }
}

class _ActionGridItem extends StatelessWidget {
  const _ActionGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF475569),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72, // Reduced to 72px as requested
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: Colors.white,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
