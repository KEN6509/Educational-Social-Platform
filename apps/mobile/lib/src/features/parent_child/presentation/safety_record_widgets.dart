part of 'safety_records_page.dart';

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
          borderRadius: BorderRadius.circular(AppRadii.compact),
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
          AppColors.error,
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
