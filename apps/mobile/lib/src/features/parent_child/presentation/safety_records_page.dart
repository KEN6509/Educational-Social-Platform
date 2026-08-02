import 'package:flutter/material.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'sos_page.dart';

sealed class SafetyRecordItem {
  const SafetyRecordItem(this.createdAt);
  final DateTime createdAt;
}

final class CheckInRecordItem extends SafetyRecordItem {
  CheckInRecordItem(this.checkIn) : super(checkIn.createdAt);
  final SafetyCheckIn checkIn;
}

final class SosRecordItem extends SafetyRecordItem {
  SosRecordItem(this.alert) : super(alert.createdAt);
  final SosAlert alert;
}

class SafetyRecordsPage extends StatefulWidget {
  const SafetyRecordsPage({super.key, required this.repository});

  final ParentChildRepositoryContract repository;

  @override
  State<SafetyRecordsPage> createState() => _SafetyRecordsPageState();
}

class _SafetyRecordsPageState extends State<SafetyRecordsPage> {
  late Future<List<SafetyRecordItem>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _fetch();
  }

  Future<List<SafetyRecordItem>> _fetch() async {
    final values = await Future.wait<Object>([
      widget.repository.fetchCheckIns(),
      widget.repository.fetchSosAlerts(),
    ]);
    final records = <SafetyRecordItem>[
      ...(values[0] as List<SafetyCheckIn>).map(CheckInRecordItem.new),
      ...(values[1] as List<SosAlert>).map(SosRecordItem.new),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<void> _refresh() async {
    final future = _fetch();
    setState(() => _recordsFuture = future);
    await future;
  }

  void _retry() => setState(() => _recordsFuture = _fetch());

  Future<void> _open(SafetyRecordItem record) async {
    switch (record) {
      case CheckInRecordItem(:final checkIn):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => CheckInDetailPage(checkIn: checkIn),
          ),
        );
      case SosRecordItem(:final alert):
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SosPage(
              repository: widget.repository,
              initialAlert: alert,
              canManage: true,
            ),
          ),
        );
        await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Check-In & SOS records',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: FutureBuilder<List<SafetyRecordItem>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RecordsMessage(
                icon: Icons.cloud_off_outlined,
                message: 'Unable to load safety records.',
                action: TextButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              );
            }
            final records = snapshot.requireData;
            if (records.isEmpty) {
              return const _RecordsMessage(
                icon: Icons.health_and_safety_outlined,
                message: 'No Check-In or SOS records yet.',
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _RecordTile(record: records[index], onTap: _open),
              ),
            );
          },
        ),
      );
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final SafetyRecordItem record;
  final ValueChanged<SafetyRecordItem> onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (record) {
      CheckInRecordItem(:final checkIn) => (
          Icons.check_circle_outline_rounded,
          const Color(0xFF16A34A),
          'Check-In',
          '${checkIn.child?.name ?? 'Linked child'} · ${checkIn.message}',
        ),
      SosRecordItem(:final alert) => (
          Icons.sos_rounded,
          const Color(0xFFE11D48),
          'SOS · ${_sosStatus(alert.status)}',
          alert.child?.name ?? 'Linked child',
        ),
    };
    return Card(
      elevation: 0,
      color: const Color(0xFFF6F8FA),
      child: ListTile(
        onTap: () => onTap(record),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '$subtitle\n${formatSupervisionTime(record.createdAt)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  static String _sosStatus(SosStatus status) => switch (status) {
        SosStatus.open => 'Open',
        SosStatus.acknowledged => 'Acknowledged',
        SosStatus.resolved => 'Resolved',
      };
}

class CheckInDetailPage extends StatelessWidget {
  const CheckInDetailPage({super.key, required this.checkIn});

  final SafetyCheckIn checkIn;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Check-In detail',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Child',
              value: checkIn.child?.name ?? 'Linked child',
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Sent at',
              value: formatSupervisionTime(checkIn.createdAt),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.message_outlined,
              label: 'Message',
              value: checkIn.message,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: checkIn.location.status == LocationStatus.available
                  ? '${checkIn.location.latitude!.toStringAsFixed(5)}, '
                      '${checkIn.location.longitude!.toStringAsFixed(5)}'
                  : checkIn.location.status == LocationStatus.notRequested
                      ? 'Not shared'
                      : 'Location unavailable',
            ),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF087F8C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ]),
      );
}

class _RecordsMessage extends StatelessWidget {
  const _RecordsMessage({
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
            Icon(icon, size: 44, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action case final action?) action,
          ]),
        ),
      );
}

String formatSupervisionTime(DateTime value) {
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
