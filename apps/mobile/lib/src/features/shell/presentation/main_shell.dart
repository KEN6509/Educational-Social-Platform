import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_page.dart';
import '../../chat/presentation/chat_widgets.dart';
import '../../posts/data/aspect_ratio_cache.dart';
import '../../posts/application/moderation_submission_coordinator.dart';
import '../../posts/data/feed_mode.dart';
import '../../posts/data/feed_post.dart';
import '../../posts/data/post_interaction_sync.dart';
import '../../posts/data/tag_catalog.dart';
import '../../posts/data/tags_repository.dart';
import '../../posts/presentation/create_post_page.dart';
import '../../posts/presentation/feed_card.dart';
import '../../posts/presentation/home_feed_page.dart';
import '../../posts/presentation/feed_message.dart';
import '../../posts/presentation/filter_page.dart';
import '../../posts/presentation/post_card_ratio_preloader.dart';
import '../../posts/presentation/post_card_skeleton.dart';
import '../../posts/presentation/post_waterfall_layout.dart';
import '../../posts/presentation/content_moderation_scope.dart';
import '../../posts/presentation/pending_moderation_retry_banner.dart';
import '../../profile/data/user_profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/content_creator_badge.dart';
import '../../profile/presentation/profile_page.dart';
import '../../parent_child/data/parent_child_repository.dart';
import '../../parent_child/services/screen_time_tracker.dart';
import '../../parent_child/presentation/parent_child_page.dart';
import '../../search/data/search_repository.dart';
import '../../notifications/presentation/push_notification_scope.dart';
import '../../notifications/presentation/push_permission_prompt.dart';
import '../../notifications/presentation/push_destination_navigator.dart';
import '../../notifications/domain/push_destination.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final _homeKey = GlobalKey<HomeFeedPageState>();
  int _index = 0;
  int _profileRefreshSignal = 0;
  FeedMode _feedMode = FeedMode.feeds;
  Set<String> _selectedFilterTags = {};
  late final TagsRepository _tagsRepository;
  late final ChatRepository _chatRepository;
  late final SearchRepository _searchRepository;
  late Future<List<TagCategory>> _tagsFuture;
  bool _isInitialized = false;
  int _chatBadgeCount = 0;
  RealtimeChannel? _notificationBadgeChannel;
  ForegroundScreenTimeTracker? _screenTimeTracker;
  StreamSubscription<PushDestination>? _pushDestinationSubscription;

  // Fixed tags for the horizontal bar
  static const _fixedTags = [
    TagOption(name: 'English', slug: 'english'),
    TagOption(name: 'Basketball', slug: 'basketball'),
    TagOption(name: 'Photography', slug: 'photography'),
    TagOption(name: 'Guitar', slug: 'guitar'),
    TagOption(name: 'Singing', slug: 'singing'),
    TagOption(name: 'History', slug: 'history'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tagsRepository = TagsRepository(Supabase.instance.client);
    _chatRepository = ChatRepository(Supabase.instance.client);
    _tagsFuture = _tagsRepository.fetchCatalog();
    // Pre-initialize cache for smoother layout
    AspectRatioCache.init();
    _refreshChatBadge();
    _notificationBadgeChannel = _chatRepository.subscribeToNotificationChanges(
      channelName: 'main-shell-notification-badge',
      onChange: (_) => _refreshChatBadge(),
    );
    _initAsync();
    final pushCoordinator = PushNotificationScope.maybeOf(context);
    if (pushCoordinator != null) {
      _pushDestinationSubscription = pushCoordinator.destinations.listen(
        (destination) => unawaited(_openPushDestination(destination)),
      );
    }
    unawaited(_initPushNotifications());
  }

  Future<void> _openPushDestination(PushDestination destination) async {
    if (!mounted) return;
    await PushDestinationNavigator(
      resolve: httpPushDestinationResolver(),
    ).open(context, destination);
  }

  Future<void> _initPushNotifications() async {
    final coordinator = PushNotificationScope.maybeOf(context);
    if (coordinator == null) return;
    await coordinator.onAuthenticated();
    if (!mounted || !(await coordinator.shouldShowPermissionPrompt())) return;
    await coordinator.markPermissionPromptShown();
    if (!mounted) return;
    final enable = await PushPermissionPrompt.show(context);
    if (enable == true) {
      try {
        await coordinator.enablePush();
      } catch (_) {
        // Settings remains available if permission or registration fails.
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _screenTimeTracker?.onResumed();
      unawaited(_screenTimeTracker?.flush());
      _refreshChatBadge();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_screenTimeTracker?.onPaused());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_screenTimeTracker?.onPaused());
    _screenTimeTracker?.dispose();
    unawaited(_pushDestinationSubscription?.cancel());
    final channel = _notificationBadgeChannel;
    if (channel != null) {
      _chatRepository.unsubscribe(channel);
    }
    super.dispose();
  }

  Future<void> _initAsync() async {
    final prefs = await SharedPreferences.getInstance();
    _searchRepository = SearchRepository(Supabase.instance.client, prefs);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final repository = ParentChildRepository(Supabase.instance.client);
      final tracker = await ForegroundScreenTimeTracker.create(
        userId: userId,
        sync: repository.syncScreenTime,
        preferences: prefs,
      );
      if (!mounted) {
        tracker.dispose();
        return;
      }
      _screenTimeTracker = tracker;
      _screenTimeTracker?.onResumed();
      unawaited(_screenTimeTracker?.flush());
    }
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _handlePostCreated() {
    setState(() => _index = 0);
    _homeKey.currentState?.refresh();
  }

  Future<void> _refreshChatBadge() async {
    try {
      final count = await _chatRepository.fetchUnreadChatTabBadgeCount();
      if (mounted) setState(() => _chatBadgeCount = count);
    } catch (_) {
      // Keep the last confirmed count when a refresh temporarily fails.
    }
  }

  void _handleChatBadgeCountChanged(int count) {
    if (!mounted || _chatBadgeCount == count) return;
    setState(() => _chatBadgeCount = count);
  }

  Future<void> _openFilterPage() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (context) => FilterPage(
          initialSelectedTags: _selectedFilterTags,
          tagsFuture: _tagsFuture,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedFilterTags = result;
      });
      // HomeFeedPage handles local filtering via didUpdateWidget
    }
  }

  void _toggleQuickTag(String slug) {
    setState(() {
      if (slug == 'all') {
        _selectedFilterTags.clear();
      } else if (slug == 'others') {
        _selectedFilterTags = {'others'};
      } else {
        // Toggle selection for individual tags in the quick bar
        if (_selectedFilterTags.contains(slug)) {
          _selectedFilterTags.remove(slug);
        } else {
          // If we were on 'others' or 'all', reset and just select this one
          if (_selectedFilterTags.contains('others')) {
            _selectedFilterTags = {slug};
          } else {
            _selectedFilterTags.add(slug);
          }
        }
      }
    });
  }

  void _unselectTag(String slug) {
    setState(() {
      // Create a new set to ensure proper state management and avoid reference issues
      final newTags = Set<String>.from(_selectedFilterTags);
      newTags.remove(slug);
      _selectedFilterTags = newTags;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedFilterTags.clear();
    });
  }

  String? _findTagNameFromCatalog(String slug) {
    for (final category in TagCatalog.fallback) {
      for (final tag in category.tags) {
        if (tag.slug == slug) return tag.name;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final moderationGateway = ContentModerationScope.of(context);
    final pages = [
      HomeFeedPage(
        key: _homeKey,
        feedMode: _feedMode,
        tagFilters: _selectedFilterTags.toList(),
        onClearFilters: _clearAllFilters,
        onCreatePost: () => setState(() => _index = 2),
      ),
      const ParentChildPage(),
      CreatePostPage(onPostCreated: _handlePostCreated),
      ChatPage(onBadgeCountChanged: _handleChatBadgeCountChanged),
      ProfilePage(refreshSignal: _profileRefreshSignal),
    ];

    // Determine what tags to show in the bar
    // Logic: All -> Selected (from FilterPage, excluding fixed) -> Fixed Tags -> Others -> +
    final List<TagOption> barTags = [];
    final Set<String> fixedSlugs = _fixedTags.map((t) => t.slug).toSet();

    // 1. Add selected tags that are NOT in the fixed list and NOT 'others'
    for (final slug in _selectedFilterTags) {
      if (slug != 'others' && !fixedSlugs.contains(slug)) {
        final name = _findTagNameFromCatalog(slug) ?? slug;
        barTags.add(TagOption(name: name, slug: slug));
      }
    }

    // 2. Add fixed tags
    barTags.addAll(_fixedTags);

    return Scaffold(
      appBar: _index == 0
          ? _HomeAppBar(
              onFilterTap: _openFilterPage,
              currentMode: _feedMode,
              onModeChanged: (mode) {
                setState(() {
                  _feedMode = mode;
                });
              },
              isInitialized: _isInitialized,
              searchRepository: _isInitialized ? _searchRepository : null,
            )
          : null,
      body: Column(
        children: [
          if (_index == 0)
            _QuickTagBar(
              selectedTags: _selectedFilterTags,
              barTags: barTags,
              onToggle: _toggleQuickTag,
              onUnselect: _unselectTag,
              onOpenFilter: _openFilterPage,
            ),
          if (_index == 0 &&
              moderationGateway is ModerationSubmissionCoordinator)
            PendingModerationRetryBanner(controller: moderationGateway),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x120B1F3E),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: _CyanZoneNavBar(
          selectedIndex: _index,
          onTap: (value) {
            if (value == _index) {
              if (value == 0) {
                _homeKey.currentState?.revealRefreshAndRefresh();
              } else if (value == 4) {
                setState(() => _profileRefreshSignal += 1);
              }
              return;
            }
            setState(() {
              _index = value;
              if (value == 4) {
                _profileRefreshSignal += 1;
              }
            });
            if (value == 3) {
              _refreshChatBadge();
            }
          },
          chatBadgeCount: _chatBadgeCount,
        ),
      ),
    );
  }
}

class _SearchFollowButton extends StatelessWidget {
  const _SearchFollowButton({
    required this.isFollowing,
    required this.onTap,
  });

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color:
                isFollowing ? const Color(0xFFF1F5F9) : const Color(0xFF4490AD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isFollowing ? 'Following' : 'Follow',
            style: TextStyle(
              color: isFollowing ? const Color(0xFF64748B) : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton({required this.tabIndex});

  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    if (tabIndex == 1) {
      return const SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: PostWaterfallSkeleton(
          padding: EdgeInsets.fromLTRB(14, 20, 14, 24),
        ),
      );
    }

    if (tabIndex == 2) {
      return const _SearchAccountsSkeleton();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B1F3E),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const _SearchAccountRowsSkeleton(count: 5),
        const SizedBox(height: 2),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Posts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B1F3E),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const PostWaterfallSkeleton(
          padding: EdgeInsets.symmetric(horizontal: 14),
        ),
      ],
    );
  }
}

class _SearchAccountsSkeleton extends StatelessWidget {
  const _SearchAccountsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B1F3E),
            ),
          ),
        ),
        SizedBox(height: 10),
        _SearchAccountRowsSkeleton(count: 8),
      ],
    );
  }
}

class _SearchAccountRowsSkeleton extends StatelessWidget {
  const _SearchAccountRowsSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ShimmerBlock(width: 48, height: 48, radius: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBlock(width: 140, height: 13, radius: 7),
                      SizedBox(height: 8),
                      ShimmerBlock(width: 90, height: 11, radius: 6),
                    ],
                  ),
                ),
                ShimmerBlock(width: 76, height: 32, radius: 16),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _QuickTagBar extends StatelessWidget {
  const _QuickTagBar({
    required this.selectedTags,
    required this.barTags,
    required this.onToggle,
    required this.onUnselect,
    required this.onOpenFilter,
  });

  final Set<String> selectedTags;
  final List<TagOption> barTags;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onUnselect;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _QuickTagChip(
            label: 'All',
            isSelected: selectedTags.isEmpty,
            onTap: () => onToggle('all'),
          ),
          ...barTags.map((tag) {
            final isSelected = selectedTags.contains(tag.slug);
            return _QuickTagChip(
              label: tag.name,
              isSelected: isSelected,
              onTap: () => onToggle(tag.slug),
              onUnselect: isSelected ? () => onUnselect(tag.slug) : null,
            );
          }),
          _QuickTagChip(
            label: 'Others',
            isSelected: selectedTags.contains('others'),
            onTap: () => onToggle('others'),
            onUnselect: selectedTags.contains('others')
                ? () => onUnselect('others')
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: IconButton.filledTonal(
              onPressed: onOpenFilter,
              icon: const Icon(Icons.add_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF4490AD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTagChip extends StatelessWidget {
  const _QuickTagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onUnselect,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onUnselect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF0B1F3E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0B1F3E)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF536A74),
                ),
              ),
              if (onUnselect != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    onUnselect!();
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  const _HomeAppBar({
    required this.onFilterTap,
    required this.currentMode,
    required this.onModeChanged,
    required this.isInitialized,
    required this.searchRepository,
  });

  final VoidCallback onFilterTap;
  final FeedMode currentMode;
  final ValueChanged<FeedMode> onModeChanged;
  final bool isInitialized;
  final SearchRepository? searchRepository;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<_HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<_HomeAppBar>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    setState(() => _isMenuOpen = true);
  }

  Future<void> _closeMenu() async {
    if (!_isMenuOpen) return;
    await _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isMenuOpen = false);
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _closeMenu,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 4),
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: _expandAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 6),
                        _buildMenuItem(
                          icon: Icons.dynamic_feed_rounded,
                          label: 'Feeds',
                          selected: widget.currentMode == FeedMode.feeds,
                          onTap: () {
                            widget.onModeChanged(FeedMode.feeds);
                            _closeMenu();
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.people_outline_rounded,
                          label: 'Following',
                          selected: widget.currentMode == FeedMode.following,
                          onTap: () {
                            widget.onModeChanged(FeedMode.following);
                            _closeMenu();
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Saves',
                          selected: widget.currentMode == FeedMode.saves,
                          onTap: () {
                            widget.onModeChanged(FeedMode.saves);
                            _closeMenu();
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected ? const Color(0xFF4490AD) : const Color(0xFF334155);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.black.withValues(alpha: 0.05),
        highlightColor: Colors.black.withValues(alpha: 0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: 30, // Fixed width to ensure vertical icon alignment
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFF1F5F9)),
      ),
      toolbarHeight: widget.preferredSize.height,
      centerTitle: true,
      leadingWidth: 70,
      leading: Center(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.black.withValues(alpha: 0.04),
            highlightColor: Colors.black.withValues(alpha: 0.01),
            onTap: widget.onFilterTap,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.tune_rounded,
                color: Color(0xFF0B1F3E),
                size: 24,
              ),
            ),
          ),
        ),
      ),
      title: CompositedTransformTarget(
        link: _layerLink,
        child: InkWell(
          onTap: _toggleMenu,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 54,
                  fit: BoxFit.contain,
                  semanticLabel: 'CyanZone logo',
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: Color(0xFF334155),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.black.withValues(alpha: 0.04),
                highlightColor: Colors.black.withValues(alpha: 0.01),
                onTap: () {
                  if (!widget.isInitialized ||
                      widget.searchRepository == null) {
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => _SearchPage(
                        searchRepository: widget.searchRepository!,
                      ),
                    ),
                  );
                },
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF0B1F3E),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CyanZoneNavBar extends StatelessWidget {
  const _CyanZoneNavBar({
    required this.selectedIndex,
    required this.onTap,
    this.chatBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int chatBadgeCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? 8 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE7EEF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x180B1F3E),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavButton(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavButton(
                  icon: Icons.supervised_user_circle_outlined,
                  selectedIcon: Icons.supervised_user_circle_rounded,
                  label: 'Parent-Child',
                  selected: selectedIndex == 1,
                  onTap: () => onTap(1),
                ),
                _CreateNavButton(
                  selected: selectedIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavButton(
                  icon: Icons.mode_comment_outlined,
                  selectedIcon: Icons.mode_comment_rounded,
                  label: 'Chats',
                  selected: selectedIndex == 3,
                  onTap: () => onTap(3),
                  badgeCount: chatBadgeCount,
                ),
                _NavButton(
                  icon: Icons.account_circle_outlined,
                  selectedIcon: Icons.account_circle_rounded,
                  label: 'Profile',
                  selected: selectedIndex == 4,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateNavButton extends StatelessWidget {
  const _CreateNavButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Create',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 58,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0B1F3E) : const Color(0xFFF3F7F8),
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x260B1F3E),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.add_rounded,
            color: selected ? Colors.white : const Color(0xFF0B1F3E),
            size: 31,
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0B1F3E) : const Color(0xFF667781);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.transparent, // Remove splash
          highlightColor: Colors.transparent, // Remove splash
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: selected ? 28 : 26,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 2,
                    right: 4,
                    child: UnreadBadge(count: badgeCount),
                  ),
                if (selected)
                  Positioned(
                    bottom: 1,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B1F3E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPage extends StatefulWidget {
  const _SearchPage({required this.searchRepository});

  final SearchRepository searchRepository;

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;
  int _activeSearchTabIndex = 0;
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _isLoading = false;
  Object? _searchError;
  SearchResults? _results;
  String? _activePostId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleSearchTabChanged);
    PostInteractionSync.latest.addListener(_handlePostInteractionUpdate);
    _loadRecentSearches();
  }

  void _handleSearchTabChanged() {
    if (!mounted || _activeSearchTabIndex == _tabController.index) return;
    setState(() => _activeSearchTabIndex = _tabController.index);
  }

  void _handlePostInteractionUpdate() {
    final update = PostInteractionSync.latest.value;
    final results = _results;
    if (!mounted || update == null || results == null) return;
    setState(() {
      _results = results.withPostUpdate(update.postId, update.result);
    });
  }

  void _applyPostResult(String postId, Map<String, dynamic> result) {
    final results = _results;
    if (!mounted || results == null) return;
    setState(() {
      _results = results.withPostUpdate(postId, result);
    });
  }

  Future<void> _toggleSearchProfileFollow(UserProfile profile) async {
    final results = _results;
    if (results == null) return;
    final nextIsFollowing = !profile.isFollowing;
    final optimistic = profile.copyWith(
      isFollowing: nextIsFollowing,
      followerCount: profile.followerCount + (nextIsFollowing ? 1 : -1),
    );
    setState(() {
      _results = results.withProfileUpdate(optimistic);
    });

    try {
      final repository = ProfileRepository(Supabase.instance.client);
      final isFollowing = await repository.toggleFollow(profile.id);
      if (!mounted) return;
      final currentResults = _results;
      if (currentResults == null) return;
      setState(() {
        _results = currentResults.withProfileUpdate(
          profile.copyWith(
            isFollowing: isFollowing,
            followerCount: profile.followerCount + (isFollowing ? 1 : -1),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      final currentResults = _results;
      if (currentResults != null) {
        setState(() => _results = currentResults.withProfileUpdate(profile));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _refreshSearchProfile(String profileId) async {
    final results = _results;
    if (results == null) return;
    final repository = ProfileRepository(Supabase.instance.client);
    final profile = await repository.fetchProfile(profileId);
    if (!mounted || profile == null) return;
    final currentResults = _results;
    if (currentResults == null) return;
    setState(() {
      _results = currentResults.withProfileUpdate(profile);
    });
  }

  void _loadRecentSearches() {
    setState(() {
      _recentSearches = widget.searchRepository.getLocalRecentSearches();
    });
  }

  @override
  void dispose() {
    PostInteractionSync.latest.removeListener(_handlePostInteractionUpdate);
    _tabController.removeListener(_handleSearchTabChanged);
    _controller.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _removeSearch(int index) async {
    final query = _recentSearches[index];
    await widget.searchRepository.removeLocalSearch(query);
    _loadRecentSearches();
  }

  Future<void> _clearAll() async {
    await widget.searchRepository.clearLocalHistory();
    _loadRecentSearches();
  }

  void _clearSearchAndReturn() {
    setState(() {
      _isSearching = false;
      _results = null;
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  Future<void> _handleSearch() async {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      _focusNode.unfocus();
      setState(() {
        _isSearching = true;
        _isLoading = true;
        _searchError = null;
      });

      try {
        await widget.searchRepository.saveAndLogSearch(query);
        _loadRecentSearches();

        final results = await widget.searchRepository.search(query);
        await PostCardRatioPreloader.preload(results.posts);
        if (mounted) {
          setState(() {
            _results = results;
            _isLoading = false;
          });
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _searchError = error;
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 62,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
        leadingWidth: 52,
        leading: Center(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.black.withValues(alpha: 0.04),
              highlightColor: Colors.black.withValues(alpha: 0.01),
              onTap: () {
                if (_isSearching) {
                  _clearSearchAndReturn();
                } else {
                  Navigator.pop(context);
                }
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textAlignVertical: TextAlignVertical.center,
            onSubmitted: (_) => _handleSearch(),
            onChanged: (value) {
              setState(() {}); // Update to show/hide clear button
            },
            style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
            decoration: appSearchInputDecoration(
              hintText: 'Search posts and users...',
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      onPressed: _clearSearchAndReturn,
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.black.withValues(alpha: 0.04),
                  highlightColor: Colors.black.withValues(alpha: 0.01),
                  onTap: _handleSearch,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.search_rounded,
                      color: Color(0xFF4490AD),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: _isSearching
            ? TabBar(
                controller: _tabController,
                overlayColor: WidgetStateProperty.all(
                    Colors.transparent), // Remove splash
                labelColor: const Color(0xFF0B1F3E),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF4490AD),
                indicatorWeight: 3,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(text: 'For you'),
                  Tab(text: 'Posts'),
                  Tab(text: 'Profiles'),
                ],
              )
            : null,
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: _isSearching ? _buildSearchResults() : _buildRecentSearches(),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      children: [
        const SizedBox(height: 4),
        if (_recentSearches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent searches',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: _clearAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Delete all',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _controller.text = _recentSearches[index];
                          _handleSearch();
                        },
                        child: Text(
                          _recentSearches[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _removeSearch(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading && _results == null) {
      return _SearchResultsSkeleton(tabIndex: _activeSearchTabIndex);
    }

    if (_searchError != null && _results == null) {
      return FeedMessage(
        icon: Icons.cloud_off_outlined,
        title: friendlyErrorTitle(_searchError),
        message: friendlyErrorMessage(_searchError),
        actionLabel: 'Try again',
        actionIcon: Icons.refresh_rounded,
        onAction: _handleSearch,
        onRefresh: _handleSearch,
      );
    }

    if (_results == null ||
        (_results!.posts.isEmpty && _results!.profiles.isEmpty)) {
      return FeedMessage(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        message:
            'No results found for "${_controller.text}". Try a different keyword.',
        actionLabel: 'Clear search',
        actionIcon: Icons.close_rounded,
        onAction: _clearSearchAndReturn,
        onRefresh: _handleSearch,
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildForYouTab(),
        _buildPostsTab(),
        _buildProfilesTab(),
      ],
    );
  }

  Widget _buildForYouTab() {
    // Top 5 profiles
    final topProfiles = _results!.profiles.take(5).toList();
    // Top 6 posts (likes-weighted)
    final top6Posts = _results!.posts.take(6).toList();

    return RefreshIndicator(
      onRefresh: _handleSearch,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          if (topProfiles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Accounts',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1F3E)),
              ),
            ),
            const SizedBox(height: 8),
            ...topProfiles.map((profile) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildProfileTile(profile),
                )),
            const SizedBox(height: 12),
          ],
          if (top6Posts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Posts',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0B1F3E)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: PostWaterfallGrid(
                posts: top6Posts,
                cardBuilder: (context, post) {
                  return FeedCard(
                    key: ValueKey('foryou_post_${post.id}'),
                    post: post,
                    heroTag: 'foryou_post_${post.id}',
                    showQuickActions: _activePostId == 'foryou_${post.id}',
                    onToggleQuickActions: () {
                      setState(() {
                        _activePostId = _activePostId == 'foryou_${post.id}'
                            ? null
                            : 'foryou_${post.id}';
                      });
                    },
                    onResult: (result) {
                      _applyPostResult(post.id, result);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    return _buildPostGrid(_results!.posts, isFull: true);
  }

  Widget _buildProfilesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _results!.profiles.length,
      itemBuilder: (context, index) =>
          _buildProfileTile(_results!.profiles[index]),
    );
  }

  Widget _buildProfileTile(UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(
                userId: profile.id,
                initialName: profile.name,
                initialAvatarUrl: profile.avatarUrl,
                initialIsContentCreator: profile.isContentCreator,
              ),
            ),
          );
          await _refreshSearchProfile(profile.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? const Icon(Icons.person_rounded, color: Color(0xFF94A3B8))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1E293B)),
                          ),
                        ),
                        if (profile.isContentCreator) ...[
                          const SizedBox(width: 4),
                          const ContentCreatorBadge(isVisible: true, size: 12),
                        ],
                      ],
                    ),
                    Text(
                      '${_formatCompactCount(profile.followerCount)} followers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (Supabase.instance.client.auth.currentUser?.id != profile.id)
                _SearchFollowButton(
                  isFollowing: profile.isFollowing,
                  onTap: () => _toggleSearchProfileFollow(profile),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCompactCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count >= 10000000 ? 0 : 1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}K';
    }
    return count.toString();
  }

  Widget _buildPostGrid(List<FeedPost> posts, {bool isFull = false}) {
    return RefreshIndicator(
      onRefresh: _handleSearch,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPostWaterfallGrid(
            posts: posts,
            cardBuilder: (context, post) {
              return FeedCard(
                key: ValueKey('search_post_${post.id}'),
                post: post,
                heroTag: 'search_post_${post.id}',
                showQuickActions: _activePostId == 'search_${post.id}',
                onToggleQuickActions: () {
                  setState(() {
                    _activePostId = _activePostId == 'search_${post.id}'
                        ? null
                        : 'search_${post.id}';
                  });
                },
                onResult: (result) {
                  _applyPostResult(post.id, result);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
