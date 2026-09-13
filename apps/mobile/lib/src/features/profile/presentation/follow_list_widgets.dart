part of 'follow_list_page.dart';

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
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friendlyErrorMessage(error),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
    required this.isSelf,
    required this.onOpenProfile,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final bool isSelf;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.navy,
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
            color: isFollowing ? AppColors.surfaceMuted : AppColors.cyan,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isFollowing ? 'Following' : 'Follow',
            style: TextStyle(
              color: isFollowing ? AppColors.textSecondary : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
