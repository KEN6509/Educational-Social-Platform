import 'package:flutter/material.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'link_request_page.dart';

class FamilyLinksPage extends StatefulWidget {
  const FamilyLinksPage({
    super.key,
    required this.repository,
    required this.currentUserId,
    required this.initialLinks,
  });

  final ParentChildRepositoryContract repository;
  final String currentUserId;
  final List<FamilyLink> initialLinks;

  @override
  State<FamilyLinksPage> createState() => _FamilyLinksPageState();
}

class _FamilyLinksPageState extends State<FamilyLinksPage> {
  late List<FamilyLink> _links;

  @override
  void initState() {
    super.initState();
    _links = widget.initialLinks;
  }

  Future<void> _refresh() async {
    final links = await widget.repository.fetchLinks();
    if (mounted) setState(() => _links = links);
  }

  Future<void> _open(FamilyLink link) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LinkRequestPage(
          repository: widget.repository,
          link: link,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Family links',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _links.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No family links or pending requests yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _links.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final link = _links[index];
                    final other = link.parentId == widget.currentUserId
                        ? link.child
                        : link.parent;
                    return Card(
                      elevation: 0,
                      color: const Color(0xFFF6F8FA),
                      child: ListTile(
                        onTap: () => _open(link),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE0F7FA),
                          child: Text(
                            (other?.name.isNotEmpty ?? false)
                                ? other!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF087F8C),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          other?.name ?? 'Family member',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(_description(link)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                ),
              ),
      );

  String _description(FamilyLink link) {
    final role = link.parentId == widget.currentUserId ? 'Parent' : 'Child';
    final status = switch (link.status) {
      FamilyLinkStatus.pending => link.requestedBy == widget.currentUserId
          ? 'Request sent'
          : 'Action needed',
      FamilyLinkStatus.active => 'Linked',
      FamilyLinkStatus.rejected => 'Rejected',
      FamilyLinkStatus.cancelled => 'Cancelled',
      FamilyLinkStatus.revoked => 'Ended',
    };
    return '$role role · $status';
  }
}
