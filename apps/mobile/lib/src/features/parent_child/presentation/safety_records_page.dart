import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_location_map.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'sos_page.dart';

const _pageBg = Color(0xFFF8FAFC);
const _text = Color(0xFF0D2344);
const _secondary = Color(0xFF64748B);
const _muted = Color(0xFF98A3B6);
const _checkIn = Color(0xFF16A34A);
const _sos = Color(0xFFEF4444);

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

enum _RecordFilter { all, checkIns, sosAlerts }

class SafetyRecordsPage extends StatefulWidget {
  const SafetyRecordsPage({
    super.key,
    required this.repository,
    this.canManageSos = false,
  });

  final ParentChildRepositoryContract repository;
  final bool canManageSos;

  @override
  State<SafetyRecordsPage> createState() => _SafetyRecordsPageState();
}

class _SafetyRecordsPageState extends State<SafetyRecordsPage> {
  late Future<List<SafetyRecordItem>> _recordsFuture;
  _RecordFilter _filter = _RecordFilter.all;

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
        SosDetail? detail;
        try {
          detail = await widget.repository.fetchSosDetail(alert.id);
        } catch (_) {
          // The SOS page can still render the record and retry hydration.
        }
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SosPage(
              repository: widget.repository,
              initialAlert: detail == null ? alert : null,
              initialDetail: detail,
              canManage: widget.canManageSos,
            ),
          ),
        );
        await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 34),
            color: _text,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Check-In & SOS Records',
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
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
            final records = _visibleRecords(snapshot.requireData);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  _FilterBar(
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 18),
                  if (records.isEmpty)
                    const _RecordsMessage(
                      icon: Icons.health_and_safety_outlined,
                      message: 'No Check-In or SOS records yet.',
                    )
                  else
                    ..._groupedRecordWidgets(records),
                ],
              ),
            );
          },
        ),
      );

  List<SafetyRecordItem> _visibleRecords(List<SafetyRecordItem> records) {
    final filtered = switch (_filter) {
      _RecordFilter.all => records,
      _RecordFilter.checkIns =>
        records.whereType<CheckInRecordItem>().toList(growable: false),
      _RecordFilter.sosAlerts =>
        records.whereType<SosRecordItem>().toList(growable: false),
    };
    return filtered.take(100).toList(growable: false);
  }

  List<Widget> _groupedRecordWidgets(List<SafetyRecordItem> records) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final record in records) {
      final local = record.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay != day) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 22));
        widgets.add(_DateHeader(day: day));
        widgets.add(const SizedBox(height: 12));
        lastDay = day;
      } else {
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(_RecordTile(record: record, onTap: _open));
    }
    return widgets;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final _RecordFilter selected;
  final ValueChanged<_RecordFilter> onSelected;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 8, children: [
        _FilterPill(
          label: 'All',
          selected: selected == _RecordFilter.all,
          onTap: () => onSelected(_RecordFilter.all),
        ),
        _FilterPill(
          label: 'Check-Ins',
          selected: selected == _RecordFilter.checkIns,
          onTap: () => onSelected(_RecordFilter.checkIns),
        ),
        _FilterPill(
          label: 'SOS Alerts',
          selected: selected == _RecordFilter.sosAlerts,
          onTap: () => onSelected(_RecordFilter.sosAlerts),
        ),
      ]);
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _text : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _secondary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1,
              ),
            ),
          ),
        ),
      );
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) => Text(
        _formatRecordDay(day),
        style: const TextStyle(
          color: _muted,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      );
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final SafetyRecordItem record;
  final ValueChanged<SafetyRecordItem> onTap;

  @override
  Widget build(BuildContext context) {
    final visual = switch (record) {
      CheckInRecordItem(:final checkIn) => _RecordVisual(
          key: ValueKey('safety-record-check-in-${checkIn.id}'),
          label: 'CHECK-IN',
          name: checkIn.child?.name ?? 'Linked child',
          avatarUrl: checkIn.child?.avatarUrl,
          accent: _checkIn,
          background: const Color(0xFFEFFDF5),
          badgeIcon: Icons.check_rounded,
          time: formatSupervisionTime(record.createdAt),
        ),
      SosRecordItem(:final alert) => _RecordVisual(
          key: ValueKey('safety-record-sos-${alert.id}'),
          label: 'SOS',
          name: alert.child?.name ?? 'Linked child',
          avatarUrl: alert.child?.avatarUrl,
          accent: _sos,
          background: const Color(0xFFFFF1F1),
          badgeIcon: Icons.priority_high_rounded,
          time: formatSupervisionTime(record.createdAt),
        ),
    };
    return Material(
      key: visual.key,
      color: visual.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onTap(record),
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: visual.accent.withValues(alpha: .32)),
          ),
          child: Row(children: [
            _RecordAvatar(
              name: visual.name,
              avatarUrl: visual.avatarUrl,
              color: visual.accent,
              badgeIcon: visual.badgeIcon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeChip(label: visual.label, color: visual.accent),
                  const SizedBox(height: 6),
                  Text(
                    visual.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    visual.time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9AA5B5),
              size: 28,
            ),
          ]),
        ),
      ),
    );
  }
}

class _RecordVisual {
  const _RecordVisual({
    required this.key,
    required this.label,
    required this.name,
    required this.avatarUrl,
    required this.accent,
    required this.background,
    required this.badgeIcon,
    required this.time,
  });

  final Key key;
  final String label;
  final String name;
  final String? avatarUrl;
  final Color accent;
  final Color background;
  final IconData badgeIcon;
  final String time;
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      );
}

class _RecordAvatar extends StatelessWidget {
  const _RecordAvatar({
    required this.name,
    required this.avatarUrl,
    required this.color,
    required this.badgeIcon,
  });

  final String name;
  final String? avatarUrl;
  final Color color;
  final IconData badgeIcon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 60,
        height: 60,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: CircleAvatar(
              backgroundColor: color.withValues(alpha: .16),
              backgroundImage: avatarUrl == null || avatarUrl!.isEmpty
                  ? null
                  : NetworkImage(avatarUrl!),
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? Text(
                      _initials(name),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(badgeIcon, color: Colors.white, size: 16),
            ),
          ),
        ]),
      );
}

// ignore: unused_element
class _LegacyRecordTile extends StatelessWidget {
  const _LegacyRecordTile({required this.record, required this.onTap});

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
              copyOnLongPress:
                  checkIn.location.status == LocationStatus.available,
            ),
            if (checkIn.location.status == LocationStatus.available) ...[
              const SizedBox(height: 12),
              AppLocationMap(
                location: checkIn.location,
                mode: AppLocationMapMode.fixed,
              ),
            ],
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyOnLongPress = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyOnLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: copyOnLongPress
            ? () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location copied')),
                );
              }
            : null,
        child: Container(
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
                    style:
                        const TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
        ),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _formatRecordDay(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
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
