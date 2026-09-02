import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import '../../profile/presentation/profile_page.dart';

const _pageBg = Color(0xFFF1F5F9);
const _text = Color(0xFF0D2344);
const _secondary = Color(0xFF7A879B);
const _border = Color(0xFFE2E8F0);
const _familyBlue = Color(0xFF4F7DF3);

typedef FamilyProfilePageBuilder = Widget Function(ProfileSummary profile);

class FamilyLinksPage extends StatefulWidget {
  const FamilyLinksPage({
    super.key,
    required this.repository,
    required this.currentUserId,
    required this.initialLinks,
    this.profilePageBuilder,
  });

  final ParentChildRepositoryContract repository;
  final String currentUserId;
  final List<FamilyLink> initialLinks;
  final FamilyProfilePageBuilder? profilePageBuilder;

  @override
  State<FamilyLinksPage> createState() => _FamilyLinksPageState();
}

class _FamilyLinksPageState extends State<FamilyLinksPage> {
  late List<FamilyLink> _links;
  final List<_LocalSupervisionNotice> _localNotices = [];

  @override
  void initState() {
    super.initState();
    _links = widget.initialLinks;
  }

  Future<void> _refresh() async {
    final links = await widget.repository.fetchLinks();
    if (mounted) setState(() => _links = links);
  }

  Future<void> _accept(FamilyLink link) async {
    final other = _otherProfile(link, widget.currentUserId);
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.people_outline_rounded,
      iconColor: _text,
      iconBackgroundColor: const Color(0xFFEAF1FF),
      title: 'Accept family link?',
      message: 'Allow ${other.name} to connect with your supervision module.',
      primaryLabel: 'Accept',
      primaryColor: const Color(0xFF10B981),
      primaryKey: const ValueKey('confirm-accept-family-link'),
    );
    if (confirmed != true || !mounted) return;
    final updated = await widget.repository.acceptLinkRequest(link.id);
    if (!mounted) return;
    setState(() {
      _links = [
        for (final item in _links)
          item.id == link.id ? _withProfileFallback(updated, item) : item,
      ];
    });
  }

  Future<void> _reject(FamilyLink link) async {
    await widget.repository.rejectLinkRequest(link.id);
    if (!mounted) return;
    setState(() {
      _links = _links.where((item) => item.id != link.id).toList();
    });
  }

  Future<void> _acceptUnlink(FamilyLink link) async {
    final other = _otherProfile(link, widget.currentUserId);
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.link_off_rounded,
      iconColor: const Color(0xFFEF4444),
      iconBackgroundColor: const Color(0xFFFFEEEE),
      title: 'Accept unlink request?',
      message: 'End your family link with ${other.name}.',
      primaryLabel: 'Accept',
      primaryColor: const Color(0xFFEF4444),
      primaryKey: const ValueKey('confirm-accept-unlink-family-link'),
    );
    if (confirmed != true || !mounted) return;
    final updated = await widget.repository.acceptUnlink(link.id);
    if (!mounted) return;
    setState(() {
      _links = [
        for (final item in _links)
          item.id == link.id ? _withProfileFallback(updated, item) : item,
      ];
    });
  }

  Future<void> _rejectUnlink(FamilyLink link) async {
    final updated = await widget.repository.rejectUnlink(link.id);
    if (!mounted) return;
    setState(() {
      _links = [
        for (final item in _links)
          item.id == link.id ? _withProfileFallback(updated, item) : item,
      ];
    });
  }

  Future<void> _requestUnlink(FamilyLink link) async {
    final other = _otherProfile(link, widget.currentUserId);
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.link_off_rounded,
      iconColor: const Color(0xFFEF4444),
      iconBackgroundColor: const Color(0xFFFFEEEE),
      title: 'Confirm unlink',
      message: 'Send ${other.name} a request to end this family link.',
      primaryLabel: 'Unlink',
      primaryColor: const Color(0xFFEF4444),
      primaryKey: const ValueKey('confirm-unlink-family-link'),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated = await widget.repository.requestUnlink(link.id);
      if (!mounted) return;
      setState(() {
        _links = [
          for (final item in _links)
            item.id == link.id ? _withProfileFallback(updated, item) : item,
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localNotices.insert(
          0,
          const _LocalSupervisionNotice(
            title: 'Unable to request unlink',
            body: 'Try again later. Your family link is still active.',
          ),
        );
        if (_localNotices.length > 10) {
          _localNotices.removeRange(10, _localNotices.length);
        }
      });
    }
  }

  Future<void> _openProfile(ProfileSummary profile) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            widget.profilePageBuilder?.call(profile) ??
            ProfilePage(
              userId: profile.id,
              initialName: profile.name,
              initialAvatarUrl: profile.avatarUrl,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _links
        .where((link) =>
            link.status == FamilyLinkStatus.pending &&
            link.requestedBy != widget.currentUserId)
        .toList(growable: false);
    final active = _links
        .where((link) => link.status == FamilyLinkStatus.active)
        .toList(growable: false);
    final incomingUnlinks = active
        .where((link) =>
            link.hasPendingUnlinkRequest &&
            link.unlinkRequestedBy != widget.currentUserId)
        .toList(growable: false);
    final activeRole = active.isEmpty ? null : _role(active.first);
    final activeUnit = activeRole == FamilyRole.parent ? 'children' : 'parents';
    final pendingCount = pending.length + incomingUnlinks.length;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Family links',
          style: TextStyle(color: _text, fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (pendingCount > 0) ...[
              _SectionHeader(
                title: 'PENDING REQUESTS',
                count: pendingCount.toString(),
              ),
              _SectionCard(
                children: [
                  for (var index = 0;
                      index < pending.length + incomingUnlinks.length;
                      index++) ...[
                    if (index > 0) const Divider(height: 1, color: _border),
                    if (index < pending.length)
                      _PendingLinkRow(
                        link: pending[index],
                        currentUserId: widget.currentUserId,
                        onOpenProfile: _openProfile,
                        onAccept: () => _accept(pending[index]),
                        onReject: () => _reject(pending[index]),
                      )
                    else
                      _PendingUnlinkRow(
                        link: incomingUnlinks[index - pending.length],
                        currentUserId: widget.currentUserId,
                        onOpenProfile: _openProfile,
                        onAccept: () => _acceptUnlink(
                            incomingUnlinks[index - pending.length]),
                        onReject: () => _rejectUnlink(
                            incomingUnlinks[index - pending.length]),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
            ],
            _SectionHeader(
              title: 'ACCOUNTS LINKED',
              trailing: '${active.length} $activeUnit',
            ),
            if (active.isEmpty)
              const _EmptyLinkedCard()
            else
              _SectionCard(
                children: [
                  for (var index = 0; index < active.length; index++) ...[
                    if (index > 0) const Divider(height: 1, color: _border),
                    _ActiveLinkRow(
                      link: active[index],
                      currentUserId: widget.currentUserId,
                      repository: widget.repository,
                      onOpenProfile: _openProfile,
                      onRequestUnlink: _requestUnlink,
                    ),
                  ],
                ],
              ),
            if (_localNotices.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'SUPERVISION NOTIFICATION',
                trailing: 'Local',
              ),
              _SectionCard(
                children: [
                  for (var index = 0;
                      index < _localNotices.length;
                      index++) ...[
                    if (index > 0) const Divider(height: 1, color: _border),
                    _LocalNoticeRow(notice: _localNotices[index]),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  FamilyRole _role(FamilyLink link) => link.parentId == widget.currentUserId
      ? FamilyRole.parent
      : FamilyRole.child;
}

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
                borderRadius: BorderRadius.circular(14),
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

ProfileSummary _otherProfile(FamilyLink link, String currentUserId) {
  final other = link.parentId == currentUserId ? link.child : link.parent;
  return other ?? const ProfileSummary(id: 'unknown', name: 'Family member');
}

FamilyLink _withProfileFallback(FamilyLink updated, FamilyLink previous) =>
    FamilyLink(
      id: updated.id,
      parentId: updated.parentId,
      childId: updated.childId,
      requestedBy: updated.requestedBy,
      status: updated.status,
      createdAt: updated.createdAt,
      parent: updated.parent ?? previous.parent,
      child: updated.child ?? previous.child,
      linkedAt: updated.linkedAt,
      respondedAt: updated.respondedAt,
      cancelledAt: updated.cancelledAt,
      unlinkRequestedBy: updated.unlinkRequestedBy,
      unlinkRequestedAt: updated.unlinkRequestedAt,
    );

String _pendingRoleLabel(FamilyLink link, String currentUserId) {
  final otherIsChild = link.childId != currentUserId;
  return otherIsChild ? 'Be your child' : 'Be your parent';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _formatScreenTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

Color _avatarColor(String id) {
  const colors = [
    Color(0xFFF08CC4),
    Color(0xFF93C5FD),
    Color(0xFF86EFAC),
    Color(0xFFFDBA74),
    Color(0xFFC4B5FD),
    Color(0xFF5EEAD4),
  ];
  return colors[id.hashCode.abs() % colors.length];
}
