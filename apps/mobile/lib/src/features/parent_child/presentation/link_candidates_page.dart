import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';

const _navy = Color(0xFF0B1F3E);
const _cyan = Color(0xFF4490AD);
const _softGrey = Color(0xFFF1F5F9);
const _divider = Color(0xFFE2E8F0);

class LinkCandidatesPage extends StatefulWidget {
  const LinkCandidatesPage({
    super.key,
    required this.repository,
    this.establishedRole,
    this.embedded = false,
    this.onRequestCreated,
  });

  final ParentChildRepositoryContract repository;
  final FamilyRole? establishedRole;
  final bool embedded;
  final VoidCallback? onRequestCreated;

  @override
  State<LinkCandidatesPage> createState() => _LinkCandidatesPageState();
}

class _LinkCandidatesPageState extends State<LinkCandidatesPage> {
  late Future<List<LinkCandidate>> _candidatesFuture;
  String _query = '';
  String? _busyCandidateId;
  final Set<String> _locallyPendingCandidateIds = <String>{};

  @override
  void initState() {
    super.initState();
    _candidatesFuture = widget.repository.fetchLinkCandidates();
  }

  void _retry() {
    setState(() {
      _candidatesFuture = widget.repository.fetchLinkCandidates();
    });
  }

  Future<void> _request(LinkCandidate candidate) async {
    final role = widget.establishedRole ?? await _chooseRole();
    if (role == null || !mounted) return;
    setState(() => _busyCandidateId = candidate.profile.id);
    try {
      await widget.repository.createLinkRequest(candidate.profile.id, role);
      if (!mounted) return;
      setState(() {
        _busyCandidateId = null;
        _locallyPendingCandidateIds.add(candidate.profile.id);
      });
      widget.onRequestCreated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Link request sent to ${candidate.profile.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send link request: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyCandidateId = null);
    }
  }

  Future<FamilyRole?> _chooseRole() async {
    final childSelected = await showAppConfirmationDialog(
      context: context,
      icon: Icons.family_restroom_rounded,
      iconColor: _cyan,
      iconBackgroundColor: const Color(0xFFE7F4F8),
      title: 'Choose your role',
      message:
          'Your role stays the same while you have pending or active family links.',
      primaryLabel: 'Child',
      secondaryLabel: 'Parent',
      primaryColor: _cyan,
    );
    if (childSelected == null) return null;
    return childSelected ? FamilyRole.child : FamilyRole.parent;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(children: [
      if (widget.embedded) ...[
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD5DEE5),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 10, 2),
          child: Row(children: [
            const Expanded(
              child: Text(
                'Request Account Linking',
                style: TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search people',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: _softGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<LinkCandidate>>(
          future: _candidatesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _CandidatesMessage(
                icon: Icons.cloud_off_outlined,
                message: 'Unable to load followers and following.',
                action: TextButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              );
            }
            final normalizedQuery = _query.toLowerCase();
            final candidates = snapshot.requireData.where((candidate) {
              if (normalizedQuery.isEmpty) return true;
              return candidate.profile.name.toLowerCase().contains(
                        normalizedQuery,
                      ) ||
                  (candidate.profile.email ?? '')
                      .toLowerCase()
                      .contains(normalizedQuery);
            }).toList(growable: false);
            if (candidates.isEmpty) {
              return const _CandidatesMessage(
                icon: Icons.people_outline_rounded,
                message: 'No matching followers or following found.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: candidates.length,
              separatorBuilder: (_, index) => Divider(
                key: Key('link-candidate-divider-$index'),
                height: 1,
                indent: 58,
                color: _divider,
              ),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final profile = candidate.profile;
                final busy = _busyCandidateId == profile.id;
                final linkState =
                    _locallyPendingCandidateIds.contains(profile.id)
                        ? LinkCandidateState.pending
                        : candidate.linkState;
                final requestable = linkState == LinkCandidateState.requestable;
                final label = switch (linkState) {
                  LinkCandidateState.requestable => 'Request',
                  LinkCandidateState.pending => 'Pending',
                  LinkCandidateState.linked => 'Linked',
                };
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: _cyan.withValues(alpha: 0.14),
                      backgroundImage: profile.avatarUrl == null
                          ? null
                          : NetworkImage(profile.avatarUrl!),
                      child: profile.avatarUrl == null
                          ? Text(
                              profile.name.isEmpty
                                  ? '?'
                                  : profile.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: _navy,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _relationship(candidate),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 94,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: requestable ? Colors.white : _cyan,
                          disabledForegroundColor:
                              requestable ? Colors.white : _cyan,
                          backgroundColor: requestable ? _cyan : _softGrey,
                          disabledBackgroundColor:
                              requestable ? _cyan : _softGrey,
                          side: const BorderSide(color: Colors.transparent),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(78, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: !requestable || busy
                            ? null
                            : () => _request(candidate),
                        child: busy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);

    if (widget.embedded) {
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Request Account Linking',
          style: TextStyle(
            color: _navy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: content,
    );
  }

  static String _relationship(LinkCandidate candidate) {
    if (candidate.isFollower && candidate.isFollowing) return 'Mutual follow';
    if (candidate.isFollower) return 'Follows you';
    return 'Following';
  }
}

class _CandidatesMessage extends StatelessWidget {
  const _CandidatesMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 42, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action case final action?) action,
          ]),
        ),
      );
}
