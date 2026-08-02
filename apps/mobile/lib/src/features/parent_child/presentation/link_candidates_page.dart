import 'package:flutter/material.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';

class LinkCandidatesPage extends StatefulWidget {
  const LinkCandidatesPage({
    super.key,
    required this.repository,
    this.establishedRole,
    this.embedded = false,
  });

  final ParentChildRepositoryContract repository;
  final FamilyRole? establishedRole;
  final bool embedded;

  @override
  State<LinkCandidatesPage> createState() => _LinkCandidatesPageState();
}

class _LinkCandidatesPageState extends State<LinkCandidatesPage> {
  late Future<List<LinkCandidate>> _candidatesFuture;
  String _query = '';
  String? _busyCandidateId;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Link request sent to ${candidate.profile.name}.')),
      );
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send link request: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyCandidateId = null);
    }
  }

  Future<FamilyRole?> _chooseRole() => showDialog<FamilyRole>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose your role'),
          content: const Text(
            'Your role stays the same while you have pending or active family links.',
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, FamilyRole.parent),
              icon: const Icon(Icons.supervisor_account_outlined),
              label: const Text('I am the parent'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, FamilyRole.child),
              icon: const Icon(Icons.child_care_rounded),
              label: const Text('I am the child'),
            ),
          ],
        ),
      );

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
                'Followers & Following',
                style: TextStyle(
                  color: Color(0xFF0D2344),
                  fontSize: 20,
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
            fillColor: const Color(0xFFF1F5F7),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final profile = candidate.profile;
                final busy = _busyCandidateId == profile.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE0F7FA),
                      backgroundImage: profile.avatarUrl == null
                          ? null
                          : NetworkImage(profile.avatarUrl!),
                      child: profile.avatarUrl == null
                          ? Text(
                              profile.name.isEmpty
                                  ? '?'
                                  : profile.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF087F8C),
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _relationship(candidate),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF607284),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 112,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: !candidate.isEligible || busy
                            ? null
                            : () => _request(candidate),
                        child: busy
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Link Request'),
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
        title: const Text(
          'Followers & Following',
          style: TextStyle(fontWeight: FontWeight.w900),
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
