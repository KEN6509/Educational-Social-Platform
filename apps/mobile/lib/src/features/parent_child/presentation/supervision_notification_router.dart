import 'package:flutter/material.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'link_request_page.dart';
import 'safety_records_page.dart';
import 'sos_page.dart';

enum SupervisionDestination { familyLink, checkIn, sos, screenTime }

final class SupervisionNotificationRouter {
  const SupervisionNotificationRouter({
    required this.repository,
    required this.currentUserId,
    this.canManageSos = false,
  });

  final ParentChildRepositoryContract repository;
  final String currentUserId;
  final bool canManageSos;

  SupervisionDestination destinationFor(
    SupervisionNotification notification,
  ) =>
      switch (notification.eventType) {
        SupervisionEventType.linkRequest ||
        SupervisionEventType.linkAccepted ||
        SupervisionEventType.linkRejected ||
        SupervisionEventType.linkCancelled =>
          SupervisionDestination.familyLink,
        SupervisionEventType.checkInSent ||
        SupervisionEventType.checkInReceived =>
          SupervisionDestination.checkIn,
        SupervisionEventType.sosOpened ||
        SupervisionEventType.sosAcknowledged ||
        SupervisionEventType.sosResolved =>
          SupervisionDestination.sos,
        SupervisionEventType.screenTimeThreshold =>
          SupervisionDestination.screenTime,
      };

  Future<void> open(
    BuildContext context,
    SupervisionNotification notification,
  ) async {
    final markRead = repository
        .markNotificationRead(notification.id)
        .then<bool>((_) => true, onError: (_) => false);
    try {
      switch (destinationFor(notification)) {
        case SupervisionDestination.familyLink:
          await _openLink(context, _required(notification.linkId));
        case SupervisionDestination.checkIn:
          await _openCheckIn(context, _required(notification.checkInId));
        case SupervisionDestination.sos:
          await _openSos(context, _required(notification.sosId));
        case SupervisionDestination.screenTime:
          await _openScreenTime(context, _required(notification.childId));
      }
    } catch (_) {
      if (context.mounted) _showUnavailable(context);
    } finally {
      await markRead;
    }
  }

  Future<void> _openLink(BuildContext context, String linkId) async {
    final links = await repository.fetchLinks();
    final link = links.where((item) => item.id == linkId).firstOrNull;
    if (link == null || !context.mounted) throw StateError('Missing link');
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LinkRequestPage(
          repository: repository,
          link: link,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  Future<void> _openCheckIn(BuildContext context, String checkInId) async {
    final records = await repository.fetchCheckIns();
    final record = records.where((item) => item.id == checkInId).firstOrNull;
    if (record == null || !context.mounted) {
      throw StateError('Missing Check-In');
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CheckInDetailPage(checkIn: record),
      ),
    );
  }

  Future<void> _openSos(BuildContext context, String sosId) async {
    final records = await repository.fetchSosAlerts();
    final alert = records.where((item) => item.id == sosId).firstOrNull;
    if (alert == null || !context.mounted) throw StateError('Missing SOS');
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SosPage(
          repository: repository,
          initialAlert: alert,
          canManage: canManageSos,
        ),
      ),
    );
  }

  Future<void> _openScreenTime(BuildContext context, String childId) async {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyScreenTimePage(
          repository: repository,
          childId: childId,
        ),
      ),
    );
  }

  static String _required(String? id) {
    if (id == null || id.isEmpty) throw StateError('Missing related ID');
    return id;
  }

  static void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This supervision record is no longer available.'),
      ),
    );
  }
}

class FamilyScreenTimePage extends StatelessWidget {
  const FamilyScreenTimePage({
    super.key,
    required this.repository,
    required this.childId,
  });

  final ParentChildRepositoryContract repository;
  final String childId;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Child screen time',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: FutureBuilder<ScreenTimeSummary>(
          future: repository.fetchScreenTime(childId, DateTime.now()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load screen time.'));
            }
            final summary = snapshot.requireData;
            final hours = summary.secondsUsed ~/ 3600;
            final minutes = (summary.secondsUsed % 3600) ~/ 60;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 48,
                    color: Color(0xFF087F8C),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$hours h $minutes min',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('CyanZone usage today'),
                ]),
              ),
            );
          },
        ),
      );
}
