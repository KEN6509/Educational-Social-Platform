import 'package:flutter/material.dart';

import '../data/parent_supervision_models.dart';

const _navy = Color(0xFF0D2548);
const _text = Color(0xFF0D2344);
const _secondary = Color(0xFF607284);
const _border = Color(0xFFD7E0E7);

class ScreenTimeCard extends StatelessWidget {
  const ScreenTimeCard({
    super.key,
    required this.summary,
    required this.height,
  });
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260D2548),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          key: const Key('screen-time-content'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Expanded(
                child: Text(
                  'My screen time · Today',
                  style: TextStyle(color: Color(0xFFDCE6F2), fontSize: 14),
                ),
              ),
              Icon(Icons.schedule_rounded, color: Color(0xFF9AA9BD), size: 24),
            ]),
            Text(
              _formatUsed(summary.secondsUsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                color: const Color(0xFF55A6C4),
                backgroundColor: const Color(0xFF53667F),
              ),
            ),
            Text(
              '${_formatRemaining(remainingSeconds)} until your '
              '${summary.nextThresholdHours}h 0m reminder',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB5C0D0), fontSize: 13),
            ),
          ],
        ),
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
    this.wide = false,
    this.iconBackgroundColor,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final double height;
  final bool wide;
  final Color? iconBackgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(16);
    final iconExtent = wide ? 56.0 : 52.0;
    final iconSize = wide ? 32.0 : 30.0;
    final titleGap = wide ? 6.0 : 5.0;
    const titleSize = 18.0;
    const subtitleSize = 14.0;
    const actionSize = 14.0;
    const chevronSize = 18.0;

    return SizedBox(
      height: height,
      child: _Surface(
        onTap: onTap,
        padding: padding,
        borderRadius: 20,
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconExtent,
              height: iconExtent,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: iconColor ?? _text,
                size: iconSize,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AutoFitTitle(
                  title,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w800,
                    fontSize: titleSize,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: titleGap),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondary,
                    fontSize: subtitleSize,
                    height: 1.25,
                  ),
                ),
              ],
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  actionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: actionSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: _text,
                size: chevronSize,
              ),
            ]),
          ],
        ),
      ),
    );
  }
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AutoFitTitle(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    enabled
                        ? description
                        : 'Available after the link is accepted.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _text,
                  size: 18,
                ),
              ]),
            ],
          ),
        ),
      );
}

class _AutoFitTitle extends StatelessWidget {
  const _AutoFitTitle(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: style,
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
  Widget build(BuildContext context) {
    final latest = notifications.take(10).toList(growable: false);
    return _Surface(
      padding: EdgeInsets.zero,
      elevation: 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Row(children: [
            Expanded(
              child: Text(
                'Supervision notifications',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Only 10 latest be displayed',
              style: TextStyle(
                color: _secondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ]),
        ),
        if (latest.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
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
            ),
          )
        else
          for (var index = 0; index < latest.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xFFE2E8F0)),
            _NotificationTile(notification: latest[index], onTap: onTap),
          ],
      ]),
    );
  }
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
      color: Colors.white,
      child: InkWell(
        onTap: () => onTap(notification),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.background,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.foreground, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notification.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _relativeTime(notification.createdAt),
              style: const TextStyle(color: _secondary, fontSize: 11),
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
          foreground: const Color(0xFF16A34A),
          background: const Color(0xFFDCFCE7),
        ),
      SupervisionEventType.screenTimeThreshold => (
          icon: Icons.shield_outlined,
          foreground: const Color(0xFFD69E00),
          background: const Color(0xFFFFF7C7),
        ),
      SupervisionEventType.linkRequest ||
      SupervisionEventType.linkAccepted ||
      SupervisionEventType.linkRejected ||
      SupervisionEventType.linkCancelled =>
        (
          icon: Icons.people_outline_rounded,
          foreground: _text,
          background: const Color(0xFFEAF1FF),
        ),
    };

String _relativeTime(DateTime createdAt) {
  final now = DateTime.now();
  final local = createdAt.toLocal();
  final difference = now.difference(local);
  if (!difference.isNegative && difference.inMinutes < 1) return 'Now';
  if (!difference.isNegative && difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (!difference.isNegative && difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (!difference.isNegative && difference.inDays < 7) {
    return '${difference.inDays}d ago';
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
    this.borderRadius = 24,
    this.elevation = 0,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: elevation,
        shadowColor: const Color(0x260D2548),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}
