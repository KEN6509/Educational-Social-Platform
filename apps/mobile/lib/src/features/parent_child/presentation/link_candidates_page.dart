import 'package:flutter/material.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';

class LinkCandidatesPage extends StatefulWidget {
  const LinkCandidatesPage({
    super.key,
    required this.repository,
    this.establishedRole,
  });

  final ParentChildRepositoryContract repository;
  final FamilyRole? establishedRole;

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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Followers & Following',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search people',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF4F6F8),
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
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
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
                      title: Text(
                        profile.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(_relationship(candidate)),
                      trailing: FilledButton.tonal(
                        onPressed: !candidate.isEligible || busy
                            ? null
                            : () => _request(candidate),
                        child: busy
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Link Request'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );

  static String _relationship(LinkCandidate candidate) {
    if (candidate.ineligibleReason case final reason?) return reason;
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
