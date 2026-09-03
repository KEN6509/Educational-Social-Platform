import 'dart:async';

import 'package:cyanzone_mobile/src/features/parent_child/data/parent_child_repository.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/location_service.dart';
import 'package:cyanzone_mobile/src/features/parent_child/services/sos_tracking_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SosTrackingScope extends InheritedNotifier<SosTrackingCoordinator> {
  const SosTrackingScope({
    required SosTrackingCoordinator coordinator,
    required super.child,
    super.key,
  }) : super(notifier: coordinator);

  static SosTrackingCoordinator? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SosTrackingScope>()?.notifier;

  static SosTrackingCoordinator read(BuildContext context) {
    final coordinator = maybeOf(context);
    if (coordinator == null) {
      throw StateError('No SosTrackingScope found above this context');
    }
    return coordinator;
  }
}

final class SosTrackingHost extends StatefulWidget {
  const SosTrackingHost({
    required this.child,
    this.coordinator,
    super.key,
  });

  final Widget child;
  final SosTrackingCoordinator? coordinator;

  @override
  State<SosTrackingHost> createState() => _SosTrackingHostState();
}

final class _SosTrackingHostState extends State<SosTrackingHost>
    with WidgetsBindingObserver {
  late final SosTrackingCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = widget.coordinator ??
        SosTrackingCoordinator(
          repository: ParentChildRepository(Supabase.instance.client),
          locationService: GeolocatorLocationService(),
        );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_coordinator.onForeground());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_coordinator.onForeground());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _coordinator.onBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SosTrackingScope(
        coordinator: _coordinator,
        child: widget.child,
      );
}
