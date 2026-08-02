import 'package:flutter/material.dart';

import '../data/parent_supervision_models.dart';

class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({super.key, required this.summary});
  final ScreenTimeSummary summary;

  @override
  Widget build(BuildContext context) {
    final hours = summary.secondsUsed ~/ 3600;
    final minutes = (summary.secondsUsed % 3600) ~/ 60;
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.schedule_rounded, color: Color(0xFF4490AD)),
          SizedBox(width: 8),
          Text('My screen time', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Text('${hours}h ${minutes}m',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Next update at ${summary.nextThresholdHours} hours',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ]),
    );
  }
}

class SummaryActionCard extends StatelessWidget {
  const SummaryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Surface(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF4490AD)),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 5),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ]),
      );
}

class SafetyActionCard extends StatelessWidget {
  const SafetyActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => _Surface(
        onTap: enabled ? onTap : null,
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(enabled ? description : 'Available after the link is accepted.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ]),
      );
}

class SupervisionNotificationsCard extends StatelessWidget {
  const SupervisionNotificationsCard({
    super.key,
    required this.notifications,
    required this.onTap,
  });
  final List<SupervisionNotification> notifications;
  final ValueChanged<SupervisionNotification> onTap;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Supervision notifications',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (notifications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No supervision updates yet.',
                  style: TextStyle(color: Color(0xFF64748B))),
            )
          else
            for (final notification in notifications.take(10))
              ListTile(
                key: ValueKey(
                  'supervision-notification-tile-${notification.id}',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(notification.title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(notification.body, maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onTap(notification),
              ),
        ]),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );
}
