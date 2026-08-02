import 'package:flutter/material.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import '../services/location_service.dart';

class SosPage extends StatefulWidget {
  SosPage({
    super.key,
    required this.repository,
    LocationService? locationService,
    this.initialAlert,
    this.canManage = false,
  }) : locationService = locationService ?? GeolocatorLocationService();

  final ParentChildRepositoryContract repository;
  final LocationService locationService;
  final SosAlert? initialAlert;
  final bool canManage;

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  SosAlert? _alert;
  SosDraft? _lastDraft;
  bool _busy = false;
  bool _sentHere = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _alert = widget.initialAlert;
  }

  Future<void> _confirmAndSend() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.sos_rounded,
      iconColor: const Color(0xFFE11D48),
      iconBackgroundColor: const Color(0xFFFFE4E6),
      title: 'Share location and alert parents?',
      message:
          'CyanZone will try to share your current location with all linked parents. The SOS will still send if location is unavailable.',
      primaryLabel: 'Send SOS',
      primaryColor: const Color(0xFFE11D48),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _sendError = null;
    });
    final location = await widget.locationService.capture();
    if (!mounted) return;
    _lastDraft = SosDraft(location: location);
    await _submitLastDraft();
  }

  Future<void> _retrySubmission() async {
    if (_lastDraft == null) return;
    setState(() {
      _busy = true;
      _sendError = null;
    });
    await _submitLastDraft();
  }

  Future<void> _submitLastDraft() async {
    try {
      final alert = await widget.repository.submitSos(_lastDraft!);
      if (!mounted) return;
      setState(() {
        _alert = alert;
        _sentHere = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sendError = 'Unable to confirm SOS delivery: $error';
      });
    }
  }

  Future<void> _acknowledge() async {
    await _updateAlert(() => widget.repository.acknowledgeSos(_alert!.id));
  }

  Future<void> _resolve() async {
    await _updateAlert(() => widget.repository.resolveSos(_alert!.id));
  }

  Future<void> _updateAlert(Future<SosAlert> Function() operation) async {
    setState(() => _busy = true);
    try {
      final returned = await operation();
      if (mounted) setState(() => _alert = returned);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update SOS: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'SOS',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _alert == null ? _buildSend(context) : _buildDetail(context),
      );

  Widget _buildSend(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(children: [
              Icon(Icons.sos_rounded, size: 58, color: Color(0xFFE11D48)),
              SizedBox(height: 14),
              Text(
                'Send an urgent alert',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 8),
              Text(
                'All linked parents will receive this SOS. CyanZone will always attempt to include your current location.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.45),
              ),
            ]),
          ),
          if (_sendError case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: Color(0xFFB42318)),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
              ),
              onPressed: _busy
                  ? null
                  : _lastDraft == null
                      ? _confirmAndSend
                      : _retrySubmission,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sos_rounded),
              label: Text(
                _busy
                    ? 'Sending…'
                    : _lastDraft == null
                        ? 'Send SOS'
                        : 'Try again',
              ),
            ),
          ),
        ],
      );

  Widget _buildDetail(BuildContext context) {
    final alert = _alert!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_sentHere) ...[
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 52,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sent',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
        ],
        _DetailCard(
          title: 'Status',
          value: _statusLabel(alert.status),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Location',
          value: alert.hasLocation
              ? '${alert.location.latitude!.toStringAsFixed(5)}, '
                  '${alert.location.longitude!.toStringAsFixed(5)}'
              : 'Location unavailable',
          icon: Icons.location_on_outlined,
        ),
        if (alert.acknowledgedBy != null) ...[
          const SizedBox(height: 12),
          _DetailCard(
            title: 'Acknowledged by',
            value: alert.acknowledgedBy!,
            icon: Icons.person_outline_rounded,
          ),
          if (alert.acknowledgedAt case final acknowledgedAt?) ...[
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Acknowledged at',
              value: _formatLocalDateTime(acknowledgedAt),
              icon: Icons.schedule_rounded,
            ),
          ],
        ],
        const SizedBox(height: 22),
        if (widget.canManage && alert.status == SosStatus.open)
          FilledButton(
            onPressed: _busy ? null : _acknowledge,
            child: const Text('Acknowledge SOS'),
          ),
        if (widget.canManage && alert.status == SosStatus.acknowledged)
          FilledButton(
            onPressed: _busy ? null : _resolve,
            child: const Text('Resolve SOS'),
          ),
        if (_sentHere)
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
      ],
    );
  }

  static String _statusLabel(SosStatus status) => switch (status) {
        SosStatus.open => 'Open',
        SosStatus.acknowledged => 'Acknowledged',
        SosStatus.resolved => 'Resolved',
      };

  static String _formatLocalDateTime(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour:$minute $period';
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF087F8C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ]),
      );
}
