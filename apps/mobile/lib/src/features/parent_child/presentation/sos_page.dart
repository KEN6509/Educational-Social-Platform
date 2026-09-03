import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_confirmation_dialog.dart';
import '../../../core/widgets/app_location_map.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import '../domain/sos_lifecycle_state.dart';
import '../services/location_service.dart';

class SosPage extends StatefulWidget {
  SosPage({
    super.key,
    required this.repository,
    LocationService? locationService,
    this.initialAlert,
    this.initialDetail,
    this.canManage = false,
    this.onSosStarted,
    this.subscribeToRealtime = true,
  })  : assert(initialAlert == null || initialDetail == null),
        locationService = locationService ?? GeolocatorLocationService();

  final ParentChildRepositoryContract repository;
  final LocationService locationService;
  final SosAlert? initialAlert;
  final SosDetail? initialDetail;
  final bool canManage;
  final Future<void> Function(SosAlert alert)? onSosStarted;
  final bool subscribeToRealtime;

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  SosAlert? _alert;
  SosDetail? _detail;
  SosDraft? _lastDraft;
  RealtimeChannel? _channel;
  Timer? _refreshDebounce;
  bool _busy = false;
  bool _sentHere = false;
  bool _loadingDetail = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _alert = widget.initialDetail?.alert ?? widget.initialAlert;
    final alert = _alert;
    if (alert != null && widget.subscribeToRealtime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startRealtime(alert.id));
      });
    }
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
        _detail = null;
        _sentHere = true;
        _busy = false;
      });
      if (widget.subscribeToRealtime) {
        unawaited(_startRealtime(alert.id));
      }
      final onSosStarted = widget.onSosStarted;
      if (onSosStarted != null) {
        try {
          await onSosStarted(alert);
        } catch (_) {
          // The SOS is delivered; the tracking coordinator owns its retries.
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sendError = 'Unable to confirm SOS delivery: $error';
      });
    }
  }

  Future<void> _startRealtime(String sosId) async {
    final previous = _channel;
    if (previous != null) await widget.repository.unsubscribe(previous);
    if (!mounted || _alert?.id != sosId) return;
    _channel = widget.repository.subscribeToSosDetailChanges(
      sosId: sosId,
      onChange: _scheduleDetailRefresh,
    );
    await _refreshDetail();
  }

  void _scheduleDetailRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(_refreshDetail()),
    );
  }

  Future<void> _refreshDetail() async {
    final alert = _alert;
    if (alert == null || _loadingDetail) return;
    if (mounted) setState(() => _loadingDetail = true);
    try {
      final detail = await widget.repository.fetchSosDetail(alert.id);
      if (!mounted || _alert?.id != alert.id) return;
      setState(() {
        _detail = detail;
        _alert = detail.alert;
      });
    } catch (_) {
      // Existing status and coordinates stay useful while Realtime retries.
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _acknowledge() async {
    await _updateAlert(() => widget.repository.acknowledgeSos(_alert!.id));
  }

  Future<void> _confirmResolve() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      icon: Icons.check_circle_outline_rounded,
      iconColor: const Color(0xFFE11D48),
      iconBackgroundColor: const Color(0xFFFFE4E6),
      title: 'Resolve this SOS?',
      message:
          'Resolving stops the child’s live location updates for this alert. This action applies to every linked parent.',
      primaryLabel: 'Resolve SOS',
      primaryColor: const Color(0xFFE11D48),
    );
    if (confirmed == true && mounted) {
      await _updateAlert(() => widget.repository.resolveSos(_alert!.id));
    }
  }

  Future<void> _updateAlert(Future<SosAlert> Function() operation) async {
    setState(() => _busy = true);
    try {
      final returned = await operation();
      if (!mounted) return;
      final currentDetail = _detail;
      setState(() {
        _alert = returned;
        if (currentDetail != null) {
          _detail = SosDetail(
            alert: returned,
            latestLocation: currentDetail.latestLocation,
            events: currentDetail.events,
            currentUserId: currentDetail.currentUserId,
          );
        }
      });
      if (widget.subscribeToRealtime) await _refreshDetail();
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
  void dispose() {
    _refreshDebounce?.cancel();
    final channel = _channel;
    if (channel != null) unawaited(widget.repository.unsubscribe(channel));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = _parentAction;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'SOS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _alert == null ? _buildSend(context) : _buildDetail(context),
      bottomNavigationBar: action == SosParentAction.none
          ? null
          : _BottomSosAction(
              action: action,
              busy: _busy,
              onPressed: action == SosParentAction.acknowledge
                  ? _acknowledge
                  : _confirmResolve,
            ),
    );
  }

  SosParentAction get _parentAction {
    final alert = _alert;
    if (!widget.canManage || alert == null || _loadingDetail) {
      return SosParentAction.none;
    }
    final hasAcknowledged = _detail == null
        ? alert.acknowledgedBy != null
        : _detail!.hasCurrentUserAcknowledged;
    return sosLifecycleStateFor(alert.status).actionFor(
      hasCurrentParentAcknowledged: hasAcknowledged,
    );
  }

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
    final location =
        _detail?.latestLocation?.toLocationCapture() ?? alert.location;
    final events = _detail?.events ?? _legacyEvents(alert);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
          value: location.status == LocationStatus.available
              ? '${location.latitude!.toStringAsFixed(5)}, '
                  '${location.longitude!.toStringAsFixed(5)}'
              : 'Location unavailable',
          icon: Icons.location_on_outlined,
        ),
        if (location.status == LocationStatus.available) ...[
          const SizedBox(height: 10),
          AppLocationMap(location: location, mode: AppLocationMapMode.live),
          if (_detail?.latestLocation case final latest?) ...[
            const SizedBox(height: 7),
            Text(
              _locationFreshness(latest),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        _TimelineCard(events: events),
        if (_sentHere) ...[
          const SizedBox(height: 14),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ],
      ],
    );
  }

  static List<SosEvent> _legacyEvents(SosAlert alert) {
    final events = <SosEvent>[
      SosEvent(
        id: '${alert.id}-triggered',
        sosId: alert.id,
        type: SosEventType.triggered,
        actorId: alert.childId,
        actorName: alert.child?.name ?? 'Child',
        createdAt: alert.createdAt,
      ),
    ];
    if (alert.acknowledgedBy case final actorId?) {
      events.add(SosEvent(
        id: '${alert.id}-acknowledged',
        sosId: alert.id,
        type: SosEventType.acknowledged,
        actorId: actorId,
        actorName: actorId,
        createdAt: alert.acknowledgedAt ?? alert.createdAt,
      ));
    }
    if (alert.resolvedBy case final actorId?) {
      events.add(SosEvent(
        id: '${alert.id}-resolved',
        sosId: alert.id,
        type: SosEventType.resolved,
        actorId: actorId,
        actorName: actorId,
        createdAt: alert.resolvedAt ?? alert.createdAt,
      ));
    }
    return events;
  }

  static String _statusLabel(SosStatus status) => switch (status) {
        SosStatus.open => 'Open',
        SosStatus.acknowledged => 'Acknowledged',
        SosStatus.resolved => 'Resolved',
      };

  static String _locationFreshness(SosLiveLocation location) {
    final elapsed = DateTime.now().difference(location.updatedAt.toLocal());
    if (elapsed <= const Duration(seconds: 30)) {
      return 'Live location • updated just now';
    }
    final value = elapsed.inMinutes < 1
        ? '${elapsed.inSeconds}s'
        : '${elapsed.inMinutes}m';
    return 'Last updated $value ago • tracking may be paused';
  }
}

final class _BottomSosAction extends StatelessWidget {
  const _BottomSosAction({
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final SosParentAction action;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('sos-bottom-action'),
            style: FilledButton.styleFrom(
              backgroundColor: action == SosParentAction.resolve
                  ? const Color(0xFFE11D48)
                  : const Color(0xFF087F8C),
            ),
            onPressed: busy ? null : onPressed,
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    action == SosParentAction.acknowledge
                        ? 'Acknowledge SOS'
                        : 'Resolve SOS',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      );
}

final class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<SosEvent> events;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('sos-timeline'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.timeline_rounded, color: Color(0xFF087F8C)),
              SizedBox(width: 12),
              Text(
                'Timeline',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ]),
            const SizedBox(height: 12),
            for (var index = 0; index < events.length; index++) ...[
              _TimelineEventRow(event: events[index]),
              if (index != events.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      );
}

final class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({required this.event});

  final SosEvent event;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _formatTime(event.createdAt),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              switch (event.type) {
                SosEventType.triggered => 'SOS triggered by ${event.actorName}',
                SosEventType.acknowledged =>
                  '${event.actorName} acknowledged alert',
                SosEventType.resolved => '${event.actorName} resolved alert',
              },
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

final class _DetailCard extends StatelessWidget {
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
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ]),
      );
}
