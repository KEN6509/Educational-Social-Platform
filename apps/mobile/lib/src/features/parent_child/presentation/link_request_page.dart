import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';

class LinkRequestPage extends StatefulWidget {
  const LinkRequestPage({
    super.key,
    required this.repository,
    required this.link,
    required this.currentUserId,
  });

  final ParentChildRepositoryContract repository;
  final FamilyLink link;
  final String currentUserId;

  @override
  State<LinkRequestPage> createState() => _LinkRequestPageState();
}

class _LinkRequestPageState extends State<LinkRequestPage> {
  bool _busy = false;

  bool get _isPending => widget.link.status == FamilyLinkStatus.pending;
  bool get _isOutgoing => widget.link.requestedBy == widget.currentUserId;

  Future<void> _accept() => _perform(
        () => widget.repository.acceptLinkRequest(widget.link.id),
        'Family link accepted.',
      );

  Future<void> _reject() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.link_off_rounded,
      iconColor: const Color(0xFFB42318),
      iconBackgroundColor: const Color(0xFFFEE4E2),
      title: 'Reject link request?',
      message: 'This request will no longer be available to accept.',
      primaryLabel: 'Reject',
      primaryColor: const Color(0xFFB42318),
    );
    if (confirmed == true) {
      await _perform(
        () => widget.repository.rejectLinkRequest(widget.link.id),
        'Link request rejected.',
      );
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.cancel_outlined,
      iconColor: const Color(0xFFB42318),
      iconBackgroundColor: const Color(0xFFFEE4E2),
      title: 'Cancel link request?',
      message: 'You can send a new request later.',
      primaryLabel: 'Cancel request',
      primaryColor: const Color(0xFFB42318),
    );
    if (confirmed == true) {
      await _perform(
        () => widget.repository.cancelLinkRequest(widget.link.id),
        'Link request cancelled.',
      );
    }
  }

  Future<void> _perform(
    Future<FamilyLink> Function() action,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update link request: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.link.parentId == widget.currentUserId
        ? widget.link.child
        : widget.link.parent;
    final currentRole =
        widget.link.parentId == widget.currentUserId ? 'Parent' : 'Child';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Family link request',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFE0F7FA),
            backgroundImage: other?.avatarUrl == null
                ? null
                : NetworkImage(other!.avatarUrl!),
            child: other?.avatarUrl == null
                ? const Icon(
                    Icons.family_restroom_rounded,
                    color: Color(0xFF087F8C),
                    size: 36,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            other?.name ?? 'Family link',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your role: $currentRole',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 28),
          _RequestInfoRow(
            label: 'Status',
            value: _statusLabel(widget.link.status),
          ),
          _RequestInfoRow(
            label: 'Direction',
            value: _isOutgoing ? 'Sent by you' : 'Sent to you',
          ),
          const SizedBox(height: 28),
          if (_isPending && !_isOutgoing) ...[
            FilledButton(
              onPressed: _busy ? null : _accept,
              child: const Text('Accept'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
              ),
              child: const Text('Reject'),
            ),
          ],
          if (_isPending && _isOutgoing)
            OutlinedButton(
              onPressed: _busy ? null : _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
              ),
              child: const Text('Cancel request'),
            ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(FamilyLinkStatus status) => switch (status) {
        FamilyLinkStatus.pending => 'Pending',
        FamilyLinkStatus.active => 'Active',
        FamilyLinkStatus.rejected => 'Rejected',
        FamilyLinkStatus.cancelled => 'Cancelled',
        FamilyLinkStatus.revoked => 'Ended',
      };
}

class _RequestInfoRow extends StatelessWidget {
  const _RequestInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
