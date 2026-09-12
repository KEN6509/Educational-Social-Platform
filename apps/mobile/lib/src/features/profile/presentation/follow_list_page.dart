import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';
import 'content_creator_badge.dart';
import 'profile_page.dart';

part 'follow_list_widgets.dart';

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
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.cyan,
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
                color: AppColors.surfaceMuted,
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
                    color: AppColors.textMuted,
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
              style: TextStyle(color: AppColors.textMuted),
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
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: profiles.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            color: AppColors.surfaceMuted,
          ),
          itemBuilder: (context, index) {
            final currentUserId = Supabase.instance.client.auth.currentUser?.id;
            return _FollowTile(
              profile: profiles[index],
              isSelf: currentUserId == profiles[index].id,
              onOpenProfile: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(userId: profiles[index].id),
                  ),
                );
              },
              onToggleFollow: () async {
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
                  if (!context.mounted) return;
                  setState(() => profiles[index] = updated);
                } catch (e) {
                  if (!context.mounted) return;
                  setState(() => profiles[index] = current);
                  AppFeedback.showError(context, friendlyErrorTitle(e));
                }
              },
            );
          },
        );
      },
    );
  }
}
