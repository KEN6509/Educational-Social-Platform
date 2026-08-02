import 'package:flutter/material.dart';

import '../data/parent_supervision_models.dart';

const _navy = Color(0xFF0D2548);
const _text = Color(0xFF0D2344);
const _secondary = Color(0xFF607284);
const _border = Color(0xFFD7E0E7);
const _paleCyan = Color(0xFFE7F4F8);

class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard(
      {super.key, required this.summary, required this.height});
  final ScreenTimeSummary summary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final thresholdSeconds = summary.nextThresholdHours * 3600;
    final remainingSeconds = (thresholdSeconds - summary.secondsUsed).clamp(
      0,
      thresholdSeconds,
    );
    final progress = thresholdSeconds == 0
        ? 0.0
        : (summary.secondsUsed / thresholdSeconds).clamp(0.0, 1.0);

    return SizedBox(
      key: const Key('screen-time-hero'),
      height: height,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(
              child: Text(
                'My screen time · Today',
                style: TextStyle(color: Color(0xFFDCE6F2), fontSize: 13),
              ),
            ),
            Icon(Icons.schedule_rounded, color: Color(0xFFBFCDDC), size: 20),
          ]),
          const SizedBox(height: 6),
          Text(
            _formatUsed(summary.secondsUsed),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: const Color(0xFF55A6C4),
              backgroundColor: const Color(0xFF53667F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatRemaining(remainingSeconds)} until your '
            '${summary.nextThresholdHours}-hour reminder',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFCFD9E6), fontSize: 11),
          ),
        ]),
      ),
    );
  }

  static String _formatUsed(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  static String _formatRemaining(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class SummaryActionCard extends StatelessWidget {
  const SummaryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    required this.height,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: _Surface(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _paleCyan,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF67808E), size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF718493),
                  size: 18,
                ),
              ]),
            ],
          ),
        ),
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
    required this.actionLabel,
    required this.height,
    this.enabled = true,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String actionLabel;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: _Surface(
          onTap: enabled ? onTap : null,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                enabled ? description : 'Available after the link is accepted.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _secondary,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: _secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(
              child: Text(
                'Supervision notifications',
                style: TextStyle(
                  color: _text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF23946E),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 8),
            ),
            SizedBox(width: 5),
            Text(
              'Live · Latest 10',
              style: TextStyle(
                color: Color(0xFF16845F),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            Container(
              key: const Key('supervision-notifications-empty'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No supervision updates yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary),
              ),
            )
          else
            for (final notification in notifications.take(10)) ...[
              _NotificationTile(notification: notification, onTap: onTap),
              if (notification != notifications.take(10).last)
                const SizedBox(height: 10),
            ],
        ]),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final SupervisionNotification notification;
  final ValueChanged<SupervisionNotification> onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _notificationVisual(notification.eventType);
    return Material(
      key: ValueKey('supervision-notification-tile-${notification.id}'),
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(notification),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(visual.icon, color: visual.foreground, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _secondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _relativeTime(notification.createdAt),
              style: const TextStyle(color: _secondary, fontSize: 10),
            ),
          ]),
        ),
      ),
    );
  }
}

({IconData icon, Color foreground, Color background}) _notificationVisual(
  SupervisionEventType type,
) =>
    switch (type) {
      SupervisionEventType.sosOpened ||
      SupervisionEventType.sosAcknowledged ||
      SupervisionEventType.sosResolved =>
        (
          icon: Icons.sos_rounded,
          foreground: const Color(0xFFE63F61),
          background: const Color(0xFFFFEAEF),
        ),
      SupervisionEventType.checkInSent ||
      SupervisionEventType.checkInReceived =>
        (
          icon: Icons.location_on_outlined,
          foreground: const Color(0xFF6C8796),
          background: _paleCyan,
        ),
      SupervisionEventType.screenTimeThreshold => (
          icon: Icons.schedule_rounded,
          foreground: const Color(0xFF6C8796),
          background: _paleCyan,
        ),
      SupervisionEventType.linkRequest ||
      SupervisionEventType.linkAccepted ||
      SupervisionEventType.linkRejected ||
      SupervisionEventType.linkCancelled =>
        (
          icon: Icons.person_add_alt_1_rounded,
          foreground: const Color(0xFF6C8796),
          background: _paleCyan,
        ),
    };

String _relativeTime(DateTime createdAt) {
  final now = DateTime.now();
  final local = createdAt.toLocal();
  final difference = now.difference(local);
  if (!difference.isNegative && difference.inMinutes < 1) return 'Now';
  if (now.year == local.year &&
      now.month == local.month &&
      now.day == local.day) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday';
  }
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
  return '${local.day} ${months[local.month - 1]}';
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}
