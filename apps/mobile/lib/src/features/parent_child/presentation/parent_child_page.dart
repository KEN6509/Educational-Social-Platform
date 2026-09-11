import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/application/async_refresh_coordinator.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'check_in_page.dart';
import 'family_links_page.dart';
import 'link_candidates_page.dart';
import 'safety_records_page.dart';
import 'sos_page.dart';
import 'sos_tracking_scope.dart';
import 'supervision_dashboards.dart';
import 'supervision_notification_router.dart';

class ParentChildPage extends StatefulWidget {
  const ParentChildPage({
    super.key,
    this.repository,
    this.subscribeToRealtime = true,
  });

  final ParentChildRepositoryContract? repository;
  final bool subscribeToRealtime;

  @override
  State<ParentChildPage> createState() => _ParentChildPageState();
}

class _ParentChildPageState extends State<ParentChildPage>
    with WidgetsBindingObserver {
  late final ParentChildRepositoryContract _repository;
  late Future<SupervisionDashboardState> _dashboardFuture;
  late final AsyncRefreshCoordinator _refreshCoordinator;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository =
        widget.repository ?? ParentChildRepository(Supabase.instance.client);
    _refreshCoordinator = AsyncRefreshCoordinator(
      debounce: const Duration(milliseconds: 180),
      refresh: _performRefresh,
      onError: (error, _) {
        assert(() {
          debugPrint('Parent Supervision refresh failed: $error');
          return true;
        }());
      },
    );
    _dashboardFuture = _repository.fetchDashboard(localDay: DateTime.now());
    _refreshCoordinator
        .trackInitialRefresh(_dashboardFuture.then<void>((_) {}));
    if (widget.subscribeToRealtime) {
      _channel = _repository.subscribeToSupervisionChanges(
        onChange: _refreshCoordinator.schedule,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _performRefresh() async {
    if (!mounted) return;
    final next = _repository.fetchDashboard(localDay: DateTime.now());
    setState(() {
      _dashboardFuture = next;
    });
    await next;
  }

  Future<void> _refresh() => _refreshCoordinator.refreshNow();

  Future<void> _openCandidates() async {
    try {
      final state = await _dashboardFuture;
      if (!mounted) return;
      var changed = false;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: .86,
          child: LinkCandidatesPage(
            repository: _repository,
            establishedRole: state.role,
            embedded: true,
            onRequestCreated: () => changed = true,
          ),
        ),
      );
      if (changed) await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open family link requests right now.'),
        ),
      );
    }
  }

  Future<void> _openFamilyLinks(SupervisionDashboardState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyLinksPage(
          repository: _repository,
          currentUserId: state.currentUserId,
          initialLinks: state.links,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _openCheckIn() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckInPage(repository: _repository),
      ),
    );
    if (sent == true) await _refresh();
  }

  Future<void> _openSos() async {
    final coordinator = SosTrackingScope.maybeOf(context);
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SosPage(
          repository: _repository,
          onSosStarted: coordinator?.start,
        ),
      ),
    );
    if (sent == true) await _refresh();
  }

  Future<void> _openRecords(SupervisionDashboardState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SafetyRecordsPage(
          repository: _repository,
          canManageSos: state.role == FamilyRole.parent,
        ),
      ),
    );
    await _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshCoordinator.dispose();
    final channel = _channel;
    if (channel != null) unawaited(_repository.unsubscribe(channel));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: const Text(
            'Parent Supervision',
            style: TextStyle(
              color: Color(0xFF0B1F3E),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Add family link',
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFF0B1F3E),
                size: 28,
              ),
              onPressed: _openCandidates,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<SupervisionDashboardState>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Unable to load Parent Supervision.'),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _refresh, child: const Text('Retry')),
                  ]),
                ),
              );
            }
            final state = snapshot.requireData;
            final notificationRouter = SupervisionNotificationRouter(
              repository: _repository,
              currentUserId: state.currentUserId,
              canManageSos: state.role == FamilyRole.parent,
              subscribeToRealtime: widget.subscribeToRealtime,
            );
            return RefreshIndicator(
              onRefresh: _refresh,
              child: SupervisionDashboard(
                state: state,
                callbacks: SupervisionDashboardCallbacks(
                  onFamily: () => _openFamilyLinks(state),
                  onRecords: () => _openRecords(state),
                  onCheckIn: _openCheckIn,
                  onSos: _openSos,
                  onNotification: (notification) {
                    unawaited(
                      notificationRouter
                          .open(context, notification)
                          .whenComplete(_refresh),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
}
