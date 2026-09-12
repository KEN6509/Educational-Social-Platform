import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/friendly_error.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../posts/data/feed_post.dart';
import '../../posts/data/post_collection_order.dart';
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
import 'profile_message_action.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';

part 'profile_header_widgets.dart';
part 'profile_post_grid.dart';

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

  void _handlePostedPostDeleted() {
    final profile = _profile;
    if (profile == null || profile.postCount <= 0) return;
    final updated = profile.copyWith(postCount: profile.postCount - 1);
    setState(() => _profile = updated);
    _profileMemoryCache[updated.id] = updated;
    unawaited(_cacheProfile(updated));
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
        color: AppColors.cyan,
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
                      labelColor: AppColors.navy,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.cyan,
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
                  onPostDeleted: _handlePostedPostDeleted,
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
      AppFeedback.showError(
        context,
        'Unable to update follow status. Please try again.',
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
                  color: AppColors.navy,
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
