import 'package:flutter/material.dart';

import '../data/parent_supervision_models.dart';
import 'supervision_dashboard_cards.dart';

final class SupervisionDashboardCallbacks {
  const SupervisionDashboardCallbacks({
    required this.onFamily,
    required this.onRecords,
    required this.onCheckIn,
    required this.onSos,
    required this.onNotification,
  });
  final VoidCallback onFamily;
  final VoidCallback onRecords;
  final VoidCallback onCheckIn;
  final VoidCallback onSos;
  final ValueChanged<SupervisionNotification> onNotification;
}

class SupervisionDashboard extends StatelessWidget {
  const SupervisionDashboard({
    super.key,
    required this.state,
    required this.callbacks,
  });
  final SupervisionDashboardState state;
  final SupervisionDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) => switch (state.role) {
        null => _Unlinked(state: state, callbacks: callbacks),
        FamilyRole.child => _Child(state: state, callbacks: callbacks),
        FamilyRole.parent => _Parent(state: state, callbacks: callbacks),
      };
}

abstract class _DashboardBase extends StatelessWidget {
  const _DashboardBase({required this.state, required this.callbacks});
  final SupervisionDashboardState state;
  final SupervisionDashboardCallbacks callbacks;

  List<Widget> commonTail() => [
        const SizedBox(height: 18),
        SupervisionNotificationsCard(
          notifications: state.notifications,
          onTap: callbacks.onNotification,
        ),
      ];

  Widget list(List<Widget> Function(double tileExtent) childrenBuilder) =>
      LayoutBuilder(
        builder: (context, constraints) {
          const horizontalPadding = 16.0;
          const columnGap = 12.0;
          final availableWidth = constraints.maxWidth - horizontalPadding * 2;
          final tileExtent = (availableWidth - columnGap) / 2;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
            children: childrenBuilder(tileExtent),
          );
        },
      );
}

class _Unlinked extends _DashboardBase {
  const _Unlinked({required super.state, required super.callbacks});
  @override
  Widget build(BuildContext context) => list((tileExtent) => [
        ScreenTimeCard(summary: state.ownScreenTime, height: tileExtent),
        const SizedBox(height: 18),
        SummaryActionCard(
          key: const Key('family-links-card'),
          icon: Icons.people_outline_rounded,
          title: 'Family links',
          subtitle: 'No active family links yet.',
          actionLabel: 'View links',
          onTap: callbacks.onFamily,
          height: tileExtent,
        ),
        ...commonTail(),
      ]);
}

class _Child extends _DashboardBase {
  const _Child({required super.state, required super.callbacks});
  @override
  Widget build(BuildContext context) => list((tileExtent) => [
        ScreenTimeCard(summary: state.ownScreenTime, height: tileExtent),
        const SizedBox(height: 18),
        SummaryActionCard(
          key: const Key('family-links-card'),
          icon: Icons.people_outline_rounded,
          title: 'Family links',
          subtitle: 'Child role · ${state.activeLinkCount} linked parents',
          actionLabel: 'View links',
          onTap: callbacks.onFamily,
          height: tileExtent,
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: SafetyActionCard(
              key: const Key('safety-check-in-card'),
              height: tileExtent,
              title: 'Safety Check-In',
              actionLabel: 'Check in',
              description: 'Tell your linked parents that you are safe.',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF16A34A),
              enabled: state.canUseSafetyActions,
              onTap: callbacks.onCheckIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SafetyActionCard(
              key: const Key('sos-card'),
              height: tileExtent,
              title: 'SOS',
              actionLabel: 'Send SOS',
              description: 'Send an urgent alert with a location attempt.',
              icon: Icons.sos_rounded,
              color: const Color(0xFFE11D48),
              enabled: state.canUseSafetyActions,
              onTap: callbacks.onSos,
            ),
          ),
        ]),
        ...commonTail(),
      ]);
}

class _Parent extends _DashboardBase {
  const _Parent({required super.state, required super.callbacks});
  @override
  Widget build(BuildContext context) => list((tileExtent) => [
        ScreenTimeCard(summary: state.ownScreenTime, height: tileExtent),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: SummaryActionCard(
              key: const Key('family-links-card'),
              icon: Icons.people_outline_rounded,
              title: 'Family links',
              subtitle:
                  'Parent role · ${state.activeLinkCount} linked children',
              actionLabel: 'View links',
              onTap: callbacks.onFamily,
              height: tileExtent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SummaryActionCard(
              key: const Key('safety-records-card'),
              icon: Icons.assignment_late_outlined,
              title: 'Check-In & SOS records',
              subtitle: 'Review linked child safety updates',
              actionLabel: 'View records',
              onTap: callbacks.onRecords,
              height: tileExtent,
            ),
          ),
        ]),
        ...commonTail(),
      ]);
}
