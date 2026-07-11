import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_room_page.dart';
import '../../posts/data/feed_post.dart';
import '../../posts/data/post_interaction_sync.dart';
import '../../posts/data/post_image_disk_cache.dart';
import '../../posts/data/posts_repository.dart';
import '../../posts/presentation/feed_card.dart';
import '../../posts/presentation/post_card_ratio_preloader.dart';
import '../../posts/presentation/post_card_skeleton.dart';
import '../../posts/presentation/post_waterfall_layout.dart';
import '../data/profile_repository.dart';
import '../data/profile_avatar_cache.dart';
import '../data/user_profile.dart';
import 'content_creator_badge.dart';
import 'follow_list_page.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    this.userId,
    this.refreshSignal = 0,
    this.initialName,
    this.initialAvatarUrl,
    this.initialAvatarBytes,
    this.initialIsContentCreator = false,
    super.key,
  });

  final String? userId;
  final int refreshSignal;
  final String? initialName;
  final String? initialAvatarUrl;
  final Uint8List? initialAvatarBytes;
  final bool initialIsContentCreator;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static final Map<String, UserProfile> _profileMemoryCache = {};

  late final ProfileRepository _profileRepository;
  late final PostsRepository _postsRepository;
  UserProfile? _profile;
  Uint8List? _cachedAvatarBytes;
  bool _isLoading = true;
  Object? _profileError;
  int _refreshVersion = 0;
  bool get _isOwnProfile {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && _profile?.id == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _profileRepository = ProfileRepository(client);
    _postsRepository = PostsRepository(client);
    final userId = widget.userId ?? client.auth.currentUser?.id;
    if (userId != null) {
      _profile = _profileMemoryCache[userId] ?? _initialProfile(userId);
      _cachedAvatarBytes =
          ProfileAvatarCache.peek(userId) ?? widget.initialAvatarBytes;
      final initialBytes = widget.initialAvatarBytes;
      if (initialBytes != null) {
        ProfileAvatarCache.remember(
          userId,
          initialBytes,
          url: widget.initialAvatarUrl,
        );
      }
      _isLoading = _profile == null;
    }
    _restoreCachedProfile();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      final userId =
          widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
      setState(() {
        _profile = userId == null
            ? null
            : _profileMemoryCache[userId] ?? _initialProfile(userId);
        _cachedAvatarBytes = userId == null
            ? null
            : ProfileAvatarCache.peek(userId) ?? widget.initialAvatarBytes;
        _isLoading = _profile == null;
        _profileError = null;
      });
      _restoreCachedProfile();
      _loadData();
      return;
    }
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _refreshProfile();
    }
  }

  UserProfile? _initialProfile(String userId) {
    final name = widget.initialName;
    if (name == null || name.isEmpty) return null;
    final profile = UserProfile(
      id: userId,
      email: '',
      name: name,
      avatarUrl: widget.initialAvatarUrl,
      isContentCreator: widget.initialIsContentCreator,
    );
    _profileMemoryCache[userId] = profile;
    return profile;
  }

  Future<void> _loadData() async {
    final userId =
        widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    if (mounted && _profile == null) {
      setState(() {
        _isLoading = true;
        _profileError = null;
      });
    }

    try {
      final profile = await _profileRepository.fetchProfile(userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _profileError = null;
        });
      }
      if (profile != null) {
        _profileMemoryCache[profile.id] = profile;
        unawaited(_cacheProfile(profile));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _profileError = e;
        });
      }
    }
  }

  Future<void> _restoreCachedProfile() async {
    final userId =
        widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile_cache_$userId');
    if (raw == null || !mounted || _profile?.email.isNotEmpty == true) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final avatarBytes = await ProfileAvatarCache.restore(userId);
      final profile = UserProfile.fromMap(map);
      _profileMemoryCache[userId] = profile;
      setState(() {
        _profile = profile;
        _cachedAvatarBytes = avatarBytes;
        _isLoading = false;
      });
    } catch (_) {
      await prefs.remove('profile_cache_$userId');
    }
  }

  Future<Uint8List?> _cacheProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'profile_cache_${profile.id}',
      jsonEncode({
        'id': profile.id,
        'email': profile.email,
        'name': profile.name,
        'avatar_url': profile.avatarUrl,
        'bio': profile.bio,
        'is_content_creator': profile.isContentCreator,
        'is_admin': profile.isAdmin,
        'is_following': profile.isFollowing,
        'post_count': profile.postCount,
        'follower_count': profile.followerCount,
        'following_count': profile.followingCount,
      }),
    );
    final avatarBytes = await ProfileAvatarCache.cacheFromUrl(
      userId: profile.id,
      url: profile.avatarUrl,
    );
    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      await prefs.remove('profile_avatar_cache_${profile.id}');
      return null;
    }
    if (avatarBytes != null) {
      if (mounted && _profile?.id == profile.id) {
        setState(() => _cachedAvatarBytes = avatarBytes);
      }
    }
    return avatarBytes;
  }

  Future<void> _refreshProfile() async {
    await _loadData();
    if (!mounted) return;
    setState(() => _refreshVersion += 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: const _ProfileSkeleton(),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: _ProfileLoadError(error: _profileError, onRetry: _loadData),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: const Color(0xFF4490AD),
        notificationPredicate: (notification) {
          return notification.metrics.axis == Axis.vertical &&
              notification.metrics.pixels <= 0;
        },
        child: DefaultTabController(
          length: 3,
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    profile: _profile!,
                    cachedAvatarBytes: _cachedAvatarBytes,
                    isOwnProfile: _isOwnProfile,
                    onRefresh: _loadData,
                    onToggleFollow: _toggleFollow,
                    onFollowersTap: () => _openFollowList(0),
                    onFollowingTap: () => _openFollowList(1),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    const TabBar(
                      overlayColor: WidgetStatePropertyAll(Colors.transparent),
                      labelColor: Color(0xFF0B1F3E),
                      unselectedLabelColor: Color(0xFF64748B),
                      indicatorColor: Color(0xFF4490AD),
                      indicatorWeight: 3,
                      tabs: [
                        Tab(icon: Icon(Icons.grid_view_rounded)),
                        Tab(icon: Icon(Icons.bookmark_border_rounded)),
                        Tab(icon: Icon(Icons.favorite_border_rounded)),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: [
                _ProfilePostGrid(
                  fetcher: () => _postsRepository.fetchUserPosts(_profile!.id),
                  mode: _ProfilePostGridMode.posted,
                  profileUserId: _profile!.id,
                  refreshVersion: _refreshVersion,
                ),
                _ProfilePostGrid(
                  fetcher: () =>
                      _postsRepository.fetchSavedPosts(userId: _profile!.id),
                  mode: _ProfilePostGridMode.saved,
                  profileUserId: _profile!.id,
                  refreshVersion: _refreshVersion,
                ),
                _ProfilePostGrid(
                  fetcher: () =>
                      _postsRepository.fetchLikedPosts(userId: _profile!.id),
                  mode: _ProfilePostGridMode.liked,
                  profileUserId: _profile!.id,
                  refreshVersion: _refreshVersion,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _isOwnProfile) return;
    final nextIsFollowing = !profile.isFollowing;
    setState(() {
      _profile = profile.copyWith(
        isFollowing: nextIsFollowing,
        followerCount: profile.followerCount + (nextIsFollowing ? 1 : -1),
      );
    });
    _profileMemoryCache[profile.id] = _profile!;

    try {
      final isFollowing = await _profileRepository.toggleFollow(profile.id);
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          isFollowing: isFollowing,
          followerCount: profile.followerCount + (isFollowing ? 1 : -1),
        );
      });
      _profileMemoryCache[profile.id] = _profile!;
    } catch (e) {
      if (!mounted) return;
      setState(() => _profile = profile);
      _profileMemoryCache[profile.id] = profile;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: widget.userId != null
          ? IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            )
          : null,
      actions: widget.userId == null && _isOwnProfile
          ? [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.short_text_rounded,
                  color: Color(0xFF0B1F3E),
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
            ]
          : null,
    );
  }

  void _openFollowList(int index) {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListPage(
          userId: profile.id,
          userName: profile.name,
          initialIndex: index,
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.cachedAvatarBytes,
    required this.isOwnProfile,
    required this.onRefresh,
    required this.onToggleFollow,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final UserProfile profile;
  final Uint8List? cachedAvatarBytes;
  final bool isOwnProfile;
  final VoidCallback onRefresh;
  final VoidCallback onToggleFollow;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ImageProvider<Object>? avatarImage = cachedAvatarBytes != null
        ? MemoryImage(cachedAvatarBytes!)
        : profile.avatarUrl != null
            ? NetworkImage(profile.avatarUrl!)
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar and Name
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFE7F8F5),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                          profile.name.characters.first.toUpperCase(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFF2C7189),
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B1F3E),
                        ),
                      ),
                    ),
                    if (profile.isContentCreator) ...[
                      const SizedBox(width: 6),
                      const ContentCreatorBadge(isVisible: true, size: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Row 2: Stats and Edit Profile button
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _StatItem(
                        label: 'Posts', value: profile.postCount.toString()),
                    const SizedBox(width: 24),
                    _StatItem(
                      label: 'Followers',
                      value: profile.followerCount.toString(),
                      onTap: onFollowersTap,
                    ),
                    const SizedBox(width: 24),
                    _StatItem(
                      label: 'Following',
                      value: profile.followingCount.toString(),
                      onTap: onFollowingTap,
                    ),
                  ],
                ),
              ),
              if (isOwnProfile)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfilePage(profile: profile),
                        ),
                      );
                      if (result == true) {
                        onRefresh();
                      }
                    },
                    child: const Center(
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Row 3: Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              profile.bio!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ],
          if (!isOwnProfile) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ProfileActionButton(
                    label: profile.isFollowing ? 'Following' : 'Follow',
                    filled: !profile.isFollowing,
                    onTap: onToggleFollow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProfileActionButton(
                    label: 'Message',
                    filled: false,
                    onTap: () async {
                      try {
                        final repository =
                            ChatRepository(Supabase.instance.client);
                        final conversationId = await repository
                            .createDirectConversation(profile.id);
                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomPage(
                              conversation: ChatConversation.fromMap({
                                'id': conversationId,
                                'type': 'direct',
                                'request_status': profile.isFollowing
                                    ? 'accepted'
                                    : 'pending',
                                'unread_count': 0,
                                'other_user_id': profile.id,
                                'other_user_name': profile.name,
                                'other_user_avatar_url': profile.avatarUrl,
                              }),
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(friendlyErrorMessage(error)),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      children: const [
        Row(
          children: [
            ShimmerBlock(width: 80, height: 80, radius: 40),
            SizedBox(width: 16),
            ShimmerBlock(width: 150, height: 20, radius: 10),
          ],
        ),
        SizedBox(height: 26),
        SizedBox(height: 24),
        ShimmerBlock(width: double.infinity, height: 12, radius: 6),
        SizedBox(height: 8),
        ShimmerBlock(width: 220, height: 12, radius: 6),
        SizedBox(height: 34),
        PostWaterfallSkeleton(),
      ],
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 14),
        Text(
          friendlyErrorTitle(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0B1F3E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friendlyErrorMessage(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B1F3E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B1F3E),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4490AD),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(label),
            ),
    );
  }
}

enum _ProfilePostGridMode { posted, saved, liked }

class _ProfilePostGrid extends StatefulWidget {
  const _ProfilePostGrid({
    required this.fetcher,
    required this.mode,
    required this.profileUserId,
    required this.refreshVersion,
  });

  final Future<List<FeedPost>> Function() fetcher;
  final _ProfilePostGridMode mode;
  final String profileUserId;
  final int refreshVersion;

  @override
  State<_ProfilePostGrid> createState() => _ProfilePostGridState();
}

class _ProfilePostGridState extends State<_ProfilePostGrid> {
  static final Map<String, List<FeedPost>> _postedPostsCache = {};

  late Future<List<FeedPost>> _future;
  List<FeedPost> _posts = [];

  @override
  void initState() {
    super.initState();
    if (widget.mode == _ProfilePostGridMode.posted) {
      _posts = _approvedPostedPostsFromMemoryCache();
      _restoreCachedPostedPosts();
    }
    _future = _fetchPostsWithRatios();
    PostInteractionSync.latest.addListener(_handlePostInteractionUpdate);
  }

  @override
  void dispose() {
    PostInteractionSync.latest.removeListener(_handlePostInteractionUpdate);
    super.dispose();
  }

  void _handlePostInteractionUpdate() {
    final update = PostInteractionSync.latest.value;
    if (!mounted || update == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final canInsertForProfile = widget.profileUserId == currentUserId;
    final insertIfMissing = canInsertForProfile &&
        ((widget.mode == _ProfilePostGridMode.liked && update.post.isLiked) ||
            (widget.mode == _ProfilePostGridMode.saved && update.post.isSaved));

    final updatedPosts = update.applyToPosts(
      _posts,
      insertIfMissing: insertIfMissing,
    );
    if (updatedPosts == _posts) return;

    setState(() {
      _posts = updatedPosts;
    });
  }

  @override
  void didUpdateWidget(covariant _ProfilePostGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fetcher != widget.fetcher ||
        oldWidget.refreshVersion != widget.refreshVersion) {
      if (widget.mode == _ProfilePostGridMode.posted) {
        _posts = _approvedPostedPostsFromMemoryCache(fallback: _posts);
      }
      _future = _fetchPostsWithRatios();
    }
  }

  List<FeedPost> _approvedPostedPostsFromMemoryCache({
    List<FeedPost> fallback = const <FeedPost>[],
  }) {
    final cached = _postedPostsCache[widget.profileUserId] ?? fallback;
    return cached.where((post) => post.isApproved).toList();
  }

  Future<List<FeedPost>> _fetchPostsWithRatios() async {
    if (!await _hasInternetConnection()) {
      throw const SocketException('No internet connection');
    }
    final posts = await widget.fetcher().timeout(
          const Duration(seconds: 5),
        );
    await PostCardRatioPreloader.preload(posts);
    unawaited(
      PostImageDiskCache.cacheUrls(
        posts.take(12).expand((post) => post.imageUrls),
      ),
    );
    if (widget.mode == _ProfilePostGridMode.posted) {
      _postedPostsCache[widget.profileUserId] = List<FeedPost>.of(posts);
      await _cachePostedPosts(posts);
    }
    return posts;
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _restoreCachedPostedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postedPostsCacheKey);
    if (raw == null || raw.isEmpty || !mounted || _posts.isNotEmpty) return;
    try {
      final rows = (jsonDecode(raw) as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(FeedPost.fromCacheMap)
          .where((post) => post.isApproved)
          .toList();
      _postedPostsCache[widget.profileUserId] = rows;
      if (mounted && _posts.isEmpty) {
        setState(() {
          _posts = rows;
        });
      }
    } catch (_) {
      await prefs.remove(_postedPostsCacheKey);
    }
  }

  Future<void> _cachePostedPosts(List<FeedPost> posts) async {
    final approvedPosts = posts.where((post) => post.isApproved).toList();
    await PostImageDiskCache.cacheUrls(
      approvedPosts
          .map((post) => post.imageUrls.firstOrNull)
          .whereType<String>(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _postedPostsCacheKey,
      jsonEncode(approvedPosts.map((post) => post.toCacheMap()).toList()),
    );
  }

  String get _postedPostsCacheKey =>
      'profile_posted_posts_cache_${widget.profileUserId}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeedPost>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _posts = snapshot.data ?? <FeedPost>[];
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _posts.isEmpty) {
          return const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: PostWaterfallSkeleton(),
          );
        }

        if (snapshot.hasError &&
            _posts.isEmpty &&
            widget.mode == _ProfilePostGridMode.posted &&
            friendlyErrorTitle(snapshot.error) == 'No internet connection') {
          return const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: PostWaterfallSkeleton(),
          );
        }

        if (snapshot.hasError && _posts.isEmpty) {
          return _ProfileGridError(error: snapshot.error);
        }

        if (_posts.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.45,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No posts yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: PostWaterfallGrid(
            posts: _posts,
            cardBuilder: (context, post) {
              return FeedCard(
                key: ValueKey('profile_post_${post.id}'),
                post: post,
                heroTag: 'profile_post_${post.id}',
                showQuickActions: false,
                enableQuickActions: false,
                onToggleQuickActions: () {},
                onResult: (_) {},
              );
            },
          ),
        );
      },
    );
  }
}

class _ProfileGridError extends StatelessWidget {
  const _ProfileGridError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.38,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  friendlyErrorTitle(error),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friendlyErrorMessage(error),
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
