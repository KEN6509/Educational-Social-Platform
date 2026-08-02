import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'check_in_page.dart';
import 'family_links_page.dart';
import 'link_candidates_page.dart';
import 'safety_records_page.dart';
import 'sos_page.dart';
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
  RealtimeChannel? _channel;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository =
        widget.repository ?? ParentChildRepository(Supabase.instance.client);
    _dashboardFuture = _repository.fetchDashboard(localDay: DateTime.now());
    if (widget.subscribeToRealtime) {
      _channel = _repository.subscribeToSupervisionChanges(
        onChange: _scheduleRefresh,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 180), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _dashboardFuture = _repository.fetchDashboard(localDay: DateTime.now());
    });
  }

  Future<void> _openCandidates() async {
    try {
      final state = await _dashboardFuture;
      if (!mounted) return;
      final changed = await showModalBottomSheet<bool>(
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
          ),
        ),
      );
      if (changed == true) _refresh();
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
    _refresh();
  }

  Future<void> _openCheckIn() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CheckInPage(repository: _repository),
      ),
    );
    if (sent == true) _refresh();
  }

  Future<void> _openSos() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SosPage(repository: _repository),
      ),
    );
    if (sent == true) _refresh();
  }

  Future<void> _openRecords() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SafetyRecordsPage(repository: _repository),
      ),
    );
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    final channel = _channel;
    if (channel != null) unawaited(_repository.unsubscribe(channel));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF3F6F8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          toolbarHeight: 74,
          titleSpacing: 20,
          title: const Text(
            'Family Connection',
            style: TextStyle(
              color: Color(0xFF0D2344),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton.filledTonal(
                tooltip: 'Add family link',
                onPressed: _openCandidates,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE7F4F8),
                  foregroundColor: const Color(0xFF397D99),
                  minimumSize: const Size.square(50),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 22),
              ),
            ),
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
            );
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: SupervisionDashboard(
                state: state,
                callbacks: SupervisionDashboardCallbacks(
                  onFamily: () => _openFamilyLinks(state),
                  onRecords: _openRecords,
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
