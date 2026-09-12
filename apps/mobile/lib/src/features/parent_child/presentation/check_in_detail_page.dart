import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../core/widgets/app_location_map.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/parent_supervision_models.dart';
import 'supervision_formatters.dart';

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
                AppFeedback.show(
                  context,
                  message: 'Location copied',
                  kind: AppFeedbackKind.neutral,
                );
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
