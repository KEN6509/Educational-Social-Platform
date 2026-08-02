import 'package:supabase_flutter/supabase_flutter.dart';

import 'parent_supervision_models.dart';

abstract interface class ParentChildRepositoryContract {
  Future<List<FamilyLink>> fetchLinks();
  Future<ScreenTimeSummary> fetchScreenTime(String userId, DateTime localDay);
  Future<List<SupervisionNotification>> fetchNotifications();
  Future<SupervisionDashboardState> fetchDashboard(
      {required DateTime localDay});
  Future<List<LinkCandidate>> fetchLinkCandidates();
  Future<FamilyLink> createLinkRequest(
      String candidateId, FamilyRole requesterRole);
  Future<FamilyLink> acceptLinkRequest(String linkId);
  Future<FamilyLink> rejectLinkRequest(String linkId);
  Future<FamilyLink> cancelLinkRequest(String linkId);
  Future<List<SafetyCheckIn>> fetchCheckIns();
  Future<List<SosAlert>> fetchSosAlerts();
  Future<SafetyCheckIn> submitCheckIn(CheckInDraft draft);
  Future<SosAlert> submitSos(SosDraft draft);
  Future<SosAlert> acknowledgeSos(String sosId);
  Future<SosAlert> resolveSos(String sosId);
  Future<ScreenTimeSyncResult> syncScreenTime(ScreenTimeSession session);
  Future<void> markNotificationRead(String notificationId);
  RealtimeChannel subscribeToSupervisionChanges(
      {required void Function() onChange});
  Future<void> unsubscribe(RealtimeChannel channel);
}

class ParentChildRepository implements ParentChildRepositoryContract {
  ParentChildRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Authentication required');
    return id;
  }

  @override
  Future<List<FamilyLink>> fetchLinks() async {
    final id = _userId;
    final rows = await _client
        .from('parent_child_links')
        .select(
          '*, parent:profiles!parent_child_links_parent_id_fkey(id, name, email, avatar_url), child:profiles!parent_child_links_child_id_fkey(id, name, email, avatar_url)',
        )
        .or('parent_id.eq.$id,child_id.eq.$id')
        .order('created_at', ascending: false);
    return rows.map(FamilyLink.fromMap).toList(growable: false);
  }

  @override
  Future<ScreenTimeSummary> fetchScreenTime(
    String userId,
    DateTime localDay,
  ) async {
    final day = _localDay(localDay);
    final row = await _client
        .from('screen_time_logs')
        .select('user_id, log_date, seconds_used')
        .eq('user_id', userId)
        .eq('log_date', day)
        .eq('source', 'device')
        .maybeSingle();
    return row == null
        ? ScreenTimeSummary.zero(userId, localDay)
        : ScreenTimeSummary.fromMap(row);
  }

  @override
  Future<List<SupervisionNotification>> fetchNotifications() async {
    final rows = await _client
        .from('supervision_notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(10);
    return rows.map(SupervisionNotification.fromMap).toList(growable: false);
  }

  @override
  Future<SupervisionDashboardState> fetchDashboard({
    required DateTime localDay,
  }) async {
    final id = _userId;
    final values = await Future.wait<Object>([
      fetchLinks(),
      fetchScreenTime(id, localDay),
      fetchNotifications(),
    ]);
    return SupervisionDashboardState.fromParts(
      currentUserId: id,
      links: values[0] as List<FamilyLink>,
      ownScreenTime: values[1] as ScreenTimeSummary,
      notifications: values[2] as List<SupervisionNotification>,
    );
  }

  @override
  Future<List<LinkCandidate>> fetchLinkCandidates() async {
    final id = _userId;
    final rows = await _client
        .from('follows')
        .select(
          'follower:profiles!follows_follower_id_fkey(id, name, email, avatar_url), following:profiles!follows_following_id_fkey(id, name, email, avatar_url), follower_id, following_id',
        )
        .or('follower_id.eq.$id,following_id.eq.$id');
    final candidates = <String, LinkCandidate>{};
    for (final row in rows) {
      final isFollower = row['following_id'] == id;
      final profileMap = Map<String, dynamic>.from(
        (isFollower ? row['follower'] : row['following']) as Map,
      );
      final profile = ProfileSummary.fromMap(profileMap);
      final previous = candidates[profile.id];
      candidates[profile.id] = previous == null
          ? LinkCandidate(
              profile: profile,
              isFollower: isFollower,
              isFollowing: !isFollower,
            )
          : previous.copyWith(
              isFollower: previous.isFollower || isFollower,
              isFollowing: previous.isFollowing || !isFollower,
            );
    }
    final result = candidates.values.toList()
      ..sort((a, b) => a.profile.name.compareTo(b.profile.name));
    return result;
  }

  @override
  Future<FamilyLink> createLinkRequest(
    String candidateId,
    FamilyRole requesterRole,
  ) async =>
      FamilyLink.fromMap(await _rpcRow('create_parent_child_link', {
        'p_candidate_id': candidateId,
        'p_requester_role': requesterRole.name,
      }));

  @override
  Future<FamilyLink> acceptLinkRequest(String linkId) async =>
      FamilyLink.fromMap(await _rpcRow('accept_parent_child_link', {
        'p_link_id': linkId,
      }));

  @override
  Future<FamilyLink> rejectLinkRequest(String linkId) async =>
      FamilyLink.fromMap(await _rpcRow('reject_parent_child_link', {
        'p_link_id': linkId,
      }));

  @override
  Future<FamilyLink> cancelLinkRequest(String linkId) async =>
      FamilyLink.fromMap(await _rpcRow('cancel_parent_child_link', {
        'p_link_id': linkId,
      }));

  @override
  Future<List<SafetyCheckIn>> fetchCheckIns() async {
    final rows = await _client
        .from('check_ins')
        .select(
            '*, child:profiles!check_ins_user_id_fkey(id, name, avatar_url)')
        .order('created_at', ascending: false);
    return rows.map(SafetyCheckIn.fromMap).toList(growable: false);
  }

  @override
  Future<List<SosAlert>> fetchSosAlerts() async {
    final rows = await _client
        .from('sos_alerts')
        .select(
            '*, child:profiles!sos_alerts_child_id_fkey(id, name, avatar_url)')
        .order('created_at', ascending: false);
    return rows.map(SosAlert.fromMap).toList(growable: false);
  }

  @override
  Future<SafetyCheckIn> submitCheckIn(CheckInDraft draft) async =>
      SafetyCheckIn.fromMap(await _rpcRow('submit_safety_check_in', {
        'p_message': draft.message.trim(),
        ..._locationParams(draft.location),
      }));

  @override
  Future<SosAlert> submitSos(SosDraft draft) async =>
      SosAlert.fromMap(await _rpcRow('submit_sos_alert', {
        ..._locationParams(draft.location),
        'p_location_failure': draft.location.failureCode,
      }));

  @override
  Future<SosAlert> acknowledgeSos(String sosId) async =>
      SosAlert.fromMap(await _rpcRow('acknowledge_sos_alert', {
        'p_sos_id': sosId,
      }));

  @override
  Future<SosAlert> resolveSos(String sosId) async =>
      SosAlert.fromMap(await _rpcRow('resolve_sos_alert', {
        'p_sos_id': sosId,
      }));

  @override
  Future<ScreenTimeSyncResult> syncScreenTime(
    ScreenTimeSession session,
  ) async =>
      ScreenTimeSyncResult.fromMap(await _rpcRow('sync_screen_time_session', {
        'p_client_session_id': session.clientSessionId,
        'p_local_day': _localDay(session.localDay),
        'p_seconds_used': session.secondsUsed,
        'p_timezone_offset_minutes': session.timezoneOffsetMinutes,
      }));

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _client.rpc('mark_supervision_notification_read', params: {
      'p_notification_id': notificationId,
    });
  }

  @override
  RealtimeChannel subscribeToSupervisionChanges({
    required void Function() onChange,
  }) {
    return _client
        .channel('parent-supervision-$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'supervision_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'parent_child_links',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sos_alerts',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  @override
  Future<void> unsubscribe(RealtimeChannel channel) =>
      _client.removeChannel(channel);

  Future<Map<String, dynamic>> _rpcRow(
    String function,
    Map<String, dynamic> params,
  ) async {
    final response = await _client.rpc(function, params: params);
    if (response is List) {
      if (response.isEmpty) throw StateError('$function returned no row');
      return Map<String, dynamic>.from(response.first as Map);
    }
    return Map<String, dynamic>.from(response as Map);
  }

  static Map<String, dynamic> _locationParams(LocationCapture location) => {
        'p_latitude': location.latitude,
        'p_longitude': location.longitude,
        'p_accuracy_meters': location.accuracyMeters,
        'p_location_captured_at': location.capturedAt?.toIso8601String(),
      };

  static String _localDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
