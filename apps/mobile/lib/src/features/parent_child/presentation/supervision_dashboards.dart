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

  Widget list(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
        children: children,
      );
}

class _Unlinked extends _DashboardBase {
  const _Unlinked({required super.state, required super.callbacks});
  @override
  Widget build(BuildContext context) => list([
        ScreenTimeCard(summary: state.ownScreenTime),
        const SizedBox(height: 18),
        SummaryActionCard(
          key: const Key('family-links-card'),
          icon: Icons.people_outline_rounded,
          title: 'Family links',
          subtitle: 'No active family links yet.',
          actionLabel: 'View links',
          onTap: callbacks.onFamily,
        ),
        ...commonTail(),
      ]);
}

class _Child extends _DashboardBase {
  const _Child({required super.state, required super.callbacks});
  @override
  Widget build(BuildContext context) => list([
        ScreenTimeCard(summary: state.ownScreenTime),
        const SizedBox(height: 18),
        SummaryActionCard(
          key: const Key('family-links-card'),
          icon: Icons.people_outline_rounded,
          title: 'Family links',
          subtitle: 'Child role · ${state.activeLinkCount} linked parents',
          actionLabel: 'View links',
          onTap: callbacks.onFamily,
        ),
        const SizedBox(height: 18),
        SafetyActionCard(
          title: 'Safety Check-In',
          description: 'Tell your linked parents that you are safe.',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF16A34A),
          enabled: state.canUseSafetyActions,
          onTap: callbacks.onCheckIn,
        ),
        const SizedBox(height: 12),
        SafetyActionCard(
          title: 'SOS',
          description: 'Send an urgent alert with a location attempt.',
          icon: Icons.sos_rounded,
          color: const Color(0xFFE11D48),
          enabled: state.canUseSafetyActions,
          onTap: callbacks.onSos,
        ),
        ...commonTail(),
      ]);
}

class _Parent extends _DashboardBase {
  const _Parent({required super.state, required super.callbacks});
  @override
  Widget build(BuildContext context) => list([
        ScreenTimeCard(summary: state.ownScreenTime),
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
            ),
          ),
        ]),
        ...commonTail(),
      ]);
}
