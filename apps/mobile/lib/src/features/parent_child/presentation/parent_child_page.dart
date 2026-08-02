import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/parent_child_repository.dart';
import '../data/parent_supervision_models.dart';
import 'supervision_dashboards.dart';

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
    _repository = widget.repository ??
        ParentChildRepository(Supabase.instance.client);
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Parent Supervision',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'Add family link',
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
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
                    FilledButton(onPressed: _refresh, child: const Text('Retry')),
                  ]),
                ),
              );
            }
            final state = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: SupervisionDashboard(
                state: state,
                callbacks: SupervisionDashboardCallbacks(
                  onFamily: () {},
                  onRecords: () {},
                  onCheckIn: () {},
                  onSos: () {},
                  onNotification: (notification) async {
                    try {
                      await _repository.markNotificationRead(notification.id);
                    } finally {
                      _refresh();
                    }
                  },
                ),
              ),
            );
          },
        ),
      );
}
