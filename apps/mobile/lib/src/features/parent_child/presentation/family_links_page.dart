import 'package:flutter/material.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import '../../profile/presentation/profile_page.dart';

part 'family_links_widgets.dart';

const _pageBg = AppColors.surfaceMuted;
const _text = Color(0xFF0D2344);
const _secondary = Color(0xFF7A879B);
const _border = AppColors.border;
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
