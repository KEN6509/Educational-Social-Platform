part of 'profile_page.dart';

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
                  border: Border.all(color: AppColors.border),
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
                          color: AppColors.navy,
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
                    color: AppColors.surfaceMuted,
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
                    onTap: () => openProfileMessage(
                      context: context,
                      profile: profile,
                    ),
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
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friendlyErrorMessage(error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
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
              backgroundColor: AppColors.navy,
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
              color: AppColors.navy,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
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
                backgroundColor: AppColors.cyan,
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
                backgroundColor: AppColors.surfaceMuted,
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
