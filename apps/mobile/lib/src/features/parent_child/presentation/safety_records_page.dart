import 'package:flutter/material.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'check_in_detail_page.dart';
import 'sos_page.dart';

part 'safety_record_widgets.dart';

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
