import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';
import 'content_creator_badge.dart';
import 'profile_page.dart';

class FollowListPage extends StatefulWidget {
  const FollowListPage({
    required this.userId,
    required this.userName,
    this.initialIndex = 0,
    super.key,
  });

  final String userId;
  final String userName;
  final int initialIndex;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  late final ProfileRepository _repository;
  late final TabController _tabController;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = ProfileRepository(Supabase.instance.client);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: Text(
          widget.userName,
          style: const TextStyle(
            color: Color(0xFF0B1F3E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          labelColor: const Color(0xFF0B1F3E),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF4490AD),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
                decoration: appSearchInputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FollowList(
                  loader: () => _repository.fetchFollowers(widget.userId),
                  onToggleFollow: _toggleFollow,
                  searchQuery: _searchQuery,
                ),
                _FollowList(
                  loader: () => _repository.fetchFollowing(widget.userId),
                  onToggleFollow: _toggleFollow,
                  searchQuery: _searchQuery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<UserProfile> _toggleFollow(UserProfile profile) async {
    final isFollowing = await _repository.toggleFollow(profile.id);
    return profile.copyWith(
      isFollowing: isFollowing,
      followerCount: profile.followerCount + (isFollowing ? 1 : -1),
    );
  }
}

class _FollowList extends StatefulWidget {
  const _FollowList({
    required this.loader,
    required this.onToggleFollow,
    required this.searchQuery,
  });

  final Future<List<UserProfile>> Function() loader;
  final Future<UserProfile> Function(UserProfile profile) onToggleFollow;
  final String searchQuery;

  @override
  State<_FollowList> createState() => _FollowListState();
}

class _FollowListState extends State<_FollowList> {
  late Future<List<UserProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FollowListSkeleton();
        }

        if (snapshot.hasError) {
          return _FollowListError(error: snapshot.error);
        }

        final allProfiles = snapshot.data ?? <UserProfile>[];
        if (allProfiles.isEmpty) {
          return const Center(
            child: Text(
              'No users yet',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          );
        }

        final profiles = widget.searchQuery.isEmpty
            ? allProfiles
            : allProfiles
                .where(
                  (profile) =>
                      profile.name.toLowerCase().contains(widget.searchQuery),
                )
                .toList();

        if (profiles.isEmpty) {
          return const Center(
            child: Text(
              'No users found',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: profiles.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: Color(0xFFF1F5F9),
          ),
          itemBuilder: (context, index) {
            return _FollowTile(
              profile: profiles[index],
              onOpenProfile: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: profiles[index].id),
                  ),
                );
              },
              onToggleFollow: () async {
                final messenger = ScaffoldMessenger.of(context);
                final current = profiles[index];
                final optimistic = current.copyWith(
                  isFollowing: !current.isFollowing,
                  followerCount:
                      current.followerCount + (!current.isFollowing ? 1 : -1),
                );
                if (!mounted) return;
                setState(() => profiles[index] = optimistic);
                try {
                  final updated = await widget.onToggleFollow(current);
                  if (!mounted) return;
                  setState(() => profiles[index] = updated);
                } catch (e) {
                  if (!mounted) return;
                  setState(() => profiles[index] = current);
                  messenger.showSnackBar(
                    SnackBar(content: Text(friendlyErrorTitle(e))),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _FollowListSkeleton extends StatelessWidget {
  const _FollowListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        return const Row(
          children: [
            _FollowSkeletonBlock(width: 48, height: 48, radius: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FollowSkeletonBlock(width: 140, height: 13, radius: 7),
                  SizedBox(height: 8),
                  _FollowSkeletonBlock(width: 90, height: 11, radius: 6),
                ],
              ),
            ),
            SizedBox(width: 18),
            _FollowSkeletonBlock(width: 76, height: 32, radius: 16),
          ],
        );
      },
    );
  }
}

class _FollowListError extends StatelessWidget {
  const _FollowListError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
      children: [
        Icon(Icons.cloud_off_outlined, size: 44, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          friendlyErrorTitle(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0B1F3E),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friendlyErrorMessage(error),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }
}

class _FollowSkeletonBlock extends StatelessWidget {
  const _FollowSkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ShimmerBlock(width: width, height: height, radius: radius);
  }
}

class _FollowTile extends StatelessWidget {
  const _FollowTile({
    required this.profile,
    required this.onOpenProfile,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = currentUserId == profile.id;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpenProfile,
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: const Color(0xFFE7F8F5),
        backgroundImage:
            profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
        child: profile.avatarUrl == null
            ? Text(
                profile.name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF2C7189),
                  fontWeight: FontWeight.w900,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0B1F3E),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (profile.isContentCreator) ...[
            const SizedBox(width: 4),
            const ContentCreatorBadge(isVisible: true, size: 12),
          ],
        ],
      ),
      trailing: isSelf
          ? null
          : _SmallFollowButton(
              isFollowing: profile.isFollowing,
              onTap: onToggleFollow,
            ),
    );
  }
}

class _SmallFollowButton extends StatelessWidget {
  const _SmallFollowButton({
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
