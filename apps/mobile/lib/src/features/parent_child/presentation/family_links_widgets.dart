part of 'family_links_page.dart';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.trailing});

  final String title;
  final String? count;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Row(children: [
          Text(
            title,
            style: const TextStyle(
              color: _secondary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const Spacer(),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: _familyBlue,
                borderRadius: BorderRadius.circular(AppRadii.compact),
              ),
              child: Text(
                count!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: _secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
        ]),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _PendingLinkRow extends StatelessWidget {
  const _PendingLinkRow({
    required this.link,
    required this.currentUserId,
    required this.onOpenProfile,
    required this.onAccept,
    required this.onReject,
  });

  final FamilyLink link;
  final String currentUserId;
  final ValueChanged<ProfileSummary> onOpenProfile;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile(link, currentUserId);
    final incoming = link.requestedBy != currentUserId;
    return InkWell(
      onTap: () => onOpenProfile(other),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          _Avatar(
            name: other.name,
            avatarUrl: other.avatarUrl,
            color: _avatarColor(other.id),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  other.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Link Request:',
                      style: TextStyle(color: _text, fontSize: 14),
                    ),
                    _RoleChip(label: _pendingRoleLabel(link, currentUserId)),
                  ],
                ),
                if (!incoming) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Request sent',
                    style: TextStyle(color: _secondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (incoming) ...[
            _CircleAction(
              icon: Icons.check_rounded,
              background: const Color(0xFFE5FAF1),
              foreground: const Color(0xFF10B981),
              onTap: onAccept,
            ),
            const SizedBox(width: 12),
            _CircleAction(
              icon: Icons.close_rounded,
              background: const Color(0xFFFFEEEE),
              foreground: const Color(0xFFEF4444),
              onTap: onReject,
            ),
          ],
        ]),
      ),
    );
  }
}

class _PendingUnlinkRow extends StatelessWidget {
  const _PendingUnlinkRow({
    required this.link,
    required this.currentUserId,
    required this.onOpenProfile,
    required this.onAccept,
    required this.onReject,
  });

  final FamilyLink link;
  final String currentUserId;
  final ValueChanged<ProfileSummary> onOpenProfile;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile(link, currentUserId);
    return InkWell(
      onTap: () => onOpenProfile(other),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          _Avatar(
            name: other.name,
            avatarUrl: other.avatarUrl,
            color: _avatarColor(other.id),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  other.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    Text(
                      'Unlink Request:',
                      style: TextStyle(color: _text, fontSize: 14),
                    ),
                    _RoleChip(label: 'End family link'),
                  ],
                ),
              ],
            ),
          ),
          _CircleAction(
            icon: Icons.check_rounded,
            background: const Color(0xFFE5FAF1),
            foreground: const Color(0xFF10B981),
            onTap: onAccept,
          ),
          const SizedBox(width: 12),
          _CircleAction(
            icon: Icons.close_rounded,
            background: const Color(0xFFFFEEEE),
            foreground: const Color(0xFFEF4444),
            onTap: onReject,
          ),
        ]),
      ),
    );
  }
}

class _ActiveLinkRow extends StatelessWidget {
  const _ActiveLinkRow({
    required this.link,
    required this.currentUserId,
    required this.repository,
    required this.onOpenProfile,
    required this.onRequestUnlink,
  });

  final FamilyLink link;
  final String currentUserId;
  final ParentChildRepositoryContract repository;
  final ValueChanged<ProfileSummary> onOpenProfile;
  final ValueChanged<FamilyLink> onRequestUnlink;

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile(link, currentUserId);
    final isParent = link.parentId == currentUserId;
    return InkWell(
      onTap: () => onOpenProfile(other),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
            crossAxisAlignment:
                isParent ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              _Avatar(
                name: other.name,
                avatarUrl: other.avatarUrl,
                color: _avatarColor(other.id),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: isParent
                    ? _ChildScreenTimeRow(
                        name: other.name,
                        repository: repository,
                        childId: link.childId,
                        unlinkPending: link.hasPendingUnlinkRequest,
                        onUnlink: () => onRequestUnlink(link),
                      )
                    : _LinkedNameRow(
                        name: other.name,
                        unlinkPending: link.hasPendingUnlinkRequest,
                        onUnlink: () => onRequestUnlink(link),
                      ),
              ),
            ]),
      ),
    );
  }
}

class _ChildScreenTimeRow extends StatelessWidget {
  const _ChildScreenTimeRow({
    required this.name,
    required this.repository,
    required this.childId,
    required this.unlinkPending,
    required this.onUnlink,
  });

  final String name;
  final ParentChildRepositoryContract repository;
  final String childId;
  final bool unlinkPending;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) => FutureBuilder<ScreenTimeSummary>(
        future: repository.fetchScreenTime(childId, DateTime.now()),
        builder: (context, snapshot) {
          final seconds = snapshot.data?.secondsUsed ?? 0;
          final limitHours = snapshot.data?.nextThresholdHours ?? 4;
          final progress = (seconds / (limitHours * 3600)).clamp(0.0, 1.0);
          final statusColor = progress >= 1
              ? const Color(0xFFEF4444)
              : progress >= .75
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LinkedNameRow(
                name: name,
                unlinkPending: unlinkPending,
                onUnlink: onUnlink,
              ),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Screen time today: '),
                      TextSpan(
                        text: _formatScreenTime(seconds),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: ' / ${limitHours}h'),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _text, fontSize: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: progress,
                  color: statusColor,
                  backgroundColor: const Color(0xFFE5E7EB),
                ),
              ),
            ],
          );
        },
      );
}

class _LinkedNameRow extends StatelessWidget {
  const _LinkedNameRow({
    required this.name,
    required this.unlinkPending,
    required this.onUnlink,
  });

  final String name;
  final bool unlinkPending;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        _UnlinkPill(
          pending: unlinkPending,
          onTap: unlinkPending ? null : onUnlink,
        ),
      ]);
}

class _LocalSupervisionNotice {
  const _LocalSupervisionNotice({required this.title, required this.body});

  final String title;
  final String body;
}

class _LocalNoticeRow extends StatelessWidget {
  const _LocalNoticeRow({required this.notice});

  final _LocalSupervisionNotice notice;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              color: _text,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.body,
                  style: const TextStyle(color: _secondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _EmptyLinkedCard extends StatelessWidget {
  const _EmptyLinkedCard();

  @override
  Widget build(BuildContext context) => const _SectionCard(
        children: [
          Padding(
            padding: EdgeInsets.all(22),
            child: Text(
              'No active family links yet.',
              style: TextStyle(color: _secondary),
            ),
          ),
        ],
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.color,
  });

  final String name;
  final String? avatarUrl;
  final Color color;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 26,
        backgroundColor: color,
        foregroundImage: avatarUrl == null || avatarUrl!.trim().isEmpty
            ? null
            : NetworkImage(avatarUrl!.trim()),
        onForegroundImageError: avatarUrl == null || avatarUrl!.trim().isEmpty
            ? null
            : (exception, stackTrace) {},
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _familyBlue,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: foreground, size: 22),
          ),
        ),
      );
}

class _UnlinkPill extends StatelessWidget {
  const _UnlinkPill({required this.pending, required this.onTap});

  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: pending ? _secondary : _text,
          backgroundColor: const Color(0xFFF3F5FA),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          pending ? 'Pending' : 'Unlink',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );
}
