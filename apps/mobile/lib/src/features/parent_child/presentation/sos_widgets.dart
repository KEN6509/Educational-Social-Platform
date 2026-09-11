part of 'sos_page.dart';

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
                  ? AppColors.error
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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                color: AppColors.textSecondary,
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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
