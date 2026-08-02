enum FamilyRole { parent, child }

enum FamilyLinkStatus { pending, active, rejected, cancelled, revoked }

enum SupervisionEventType {
  linkRequest,
  linkAccepted,
  linkRejected,
  linkCancelled,
  checkInSent,
  checkInReceived,
  sosOpened,
  sosAcknowledged,
  sosResolved,
  screenTimeThreshold,
}

enum SosStatus { open, acknowledged, resolved }

enum LocationStatus { notRequested, available, unavailable }

DateTime _date(Object? value) => DateTime.parse(value as String);
DateTime? _optionalDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

final class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory ProfileSummary.fromMap(Map<String, dynamic> map) => ProfileSummary(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'CyanZone user',
        email: map['email'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );

  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
}

final class LinkCandidate {
  const LinkCandidate({
    required this.profile,
    required this.isFollower,
    required this.isFollowing,
    this.ineligibleReason,
  });

  final ProfileSummary profile;
  final bool isFollower;
  final bool isFollowing;
  final String? ineligibleReason;
  bool get isEligible => ineligibleReason == null;

  LinkCandidate copyWith({bool? isFollower, bool? isFollowing}) => LinkCandidate(
        profile: profile,
        isFollower: isFollower ?? this.isFollower,
        isFollowing: isFollowing ?? this.isFollowing,
        ineligibleReason: ineligibleReason,
      );
}

final class LocationCapture {
  const LocationCapture._({
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
    this.failureCode,
  });

  const LocationCapture.notRequested()
      : this._(status: LocationStatus.notRequested);

  const LocationCapture.unavailable(String failureCode)
      : this._(
          status: LocationStatus.unavailable,
          failureCode: failureCode,
        );

  const LocationCapture.available({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime capturedAt,
  }) : this._(
          status: LocationStatus.available,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          capturedAt: capturedAt,
        );

  factory LocationCapture.fromMap(Map<String, dynamic> map) {
    final status = _locationStatus(map['location_status'] as String?);
    if (status == LocationStatus.available) {
      return LocationCapture.available(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble() ?? 0,
        capturedAt: _optionalDate(map['location_captured_at']) ??
            _date(map['created_at']),
      );
    }
    if (status == LocationStatus.notRequested) {
      return const LocationCapture.notRequested();
    }
    return LocationCapture.unavailable(
      map['location_failure'] as String? ?? 'location_unavailable',
    );
  }

  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final String? failureCode;
}

final class FamilyLink {
  const FamilyLink({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.requestedBy,
    required this.status,
    required this.createdAt,
    this.parent,
    this.child,
    this.linkedAt,
    this.respondedAt,
    this.cancelledAt,
  });

  factory FamilyLink.fromMap(Map<String, dynamic> map) => FamilyLink(
        id: map['id'] as String,
        parentId: map['parent_id'] as String,
        childId: map['child_id'] as String,
        requestedBy: map['requested_by'] as String,
        status: _linkStatus(map['status'] as String),
        createdAt: _date(map['created_at']),
        linkedAt: _optionalDate(map['linked_at']),
        respondedAt: _optionalDate(map['responded_at']),
        cancelledAt: _optionalDate(map['cancelled_at']),
        parent: map['parent'] is Map
            ? ProfileSummary.fromMap(
                Map<String, dynamic>.from(map['parent'] as Map),
              )
            : null,
        child: map['child'] is Map
            ? ProfileSummary.fromMap(
                Map<String, dynamic>.from(map['child'] as Map),
              )
            : null,
      );

  final String id;
  final String parentId;
  final String childId;
  final String requestedBy;
  final FamilyLinkStatus status;
  final DateTime createdAt;
  final DateTime? linkedAt;
  final DateTime? respondedAt;
  final DateTime? cancelledAt;
  final ProfileSummary? parent;
  final ProfileSummary? child;
}

final class ScreenTimeSummary {
  const ScreenTimeSummary({
    required this.userId,
    required this.localDay,
    required this.secondsUsed,
    required this.nextThresholdHours,
  });

  factory ScreenTimeSummary.zero(String userId, DateTime localDay) =>
      ScreenTimeSummary(
        userId: userId,
        localDay: localDay,
        secondsUsed: 0,
        nextThresholdHours: 3,
      );

  factory ScreenTimeSummary.fromMap(Map<String, dynamic> map) {
    final seconds = map['seconds_used'] as int? ?? 0;
    return ScreenTimeSummary(
      userId: map['user_id'] as String,
      localDay: DateTime.parse(map['log_date'] as String),
      secondsUsed: seconds,
      nextThresholdHours: (seconds ~/ 3600 + 1).clamp(3, 24),
    );
  }

  final String userId;
  final DateTime localDay;
  final int secondsUsed;
  final int nextThresholdHours;
}

final class SosAlert {
  const SosAlert({
    required this.id,
    required this.childId,
    required this.status,
    required this.location,
    required this.createdAt,
    this.child,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
  });

  factory SosAlert.fromMap(Map<String, dynamic> map) => SosAlert(
        id: map['id'] as String,
        childId: map['child_id'] as String,
        status: _sosStatus(map['status'] as String),
        location: LocationCapture.fromMap(map),
        createdAt: _date(map['created_at']),
        acknowledgedBy: map['acknowledged_by'] as String?,
        acknowledgedAt: _optionalDate(map['acknowledged_at']),
        resolvedBy: map['resolved_by'] as String?,
        resolvedAt: _optionalDate(map['resolved_at']),
        child: map['child'] is Map
            ? ProfileSummary.fromMap(
                Map<String, dynamic>.from(map['child'] as Map),
              )
            : null,
      );

  final String id;
  final String childId;
  final SosStatus status;
  final LocationCapture location;
  final DateTime createdAt;
  final ProfileSummary? child;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  bool get hasLocation => location.status == LocationStatus.available;
}

final class CheckInDraft {
  const CheckInDraft({required this.message, required this.location});
  final String message;
  final LocationCapture location;
}

final class SosDraft {
  const SosDraft({required this.location});
  final LocationCapture location;
}

final class SafetyCheckIn {
  const SafetyCheckIn({
    required this.id,
    required this.childId,
    required this.message,
    required this.location,
    required this.createdAt,
    this.child,
  });

  factory SafetyCheckIn.fromMap(Map<String, dynamic> map) => SafetyCheckIn(
        id: map['id'] as String,
        childId: map['user_id'] as String,
        message: map['message'] as String,
        location: LocationCapture.fromMap(map),
        createdAt: _date(map['created_at']),
        child: map['child'] is Map
            ? ProfileSummary.fromMap(
                Map<String, dynamic>.from(map['child'] as Map),
              )
            : null,
      );

  final String id;
  final String childId;
  final String message;
  final LocationCapture location;
  final DateTime createdAt;
  final ProfileSummary? child;
}

final class ScreenTimeSession {
  const ScreenTimeSession({
    required this.clientSessionId,
    required this.localDay,
    required this.secondsUsed,
    required this.timezoneOffsetMinutes,
  });
  final String clientSessionId;
  final DateTime localDay;
  final int secondsUsed;
  final int timezoneOffsetMinutes;
}

final class ScreenTimeSyncResult {
  const ScreenTimeSyncResult({
    required this.dailySeconds,
    required this.nextThresholdHours,
    required this.applied,
  });

  factory ScreenTimeSyncResult.fromMap(Map<String, dynamic> map) =>
      ScreenTimeSyncResult(
        dailySeconds: map['daily_seconds'] as int,
        nextThresholdHours: map['next_threshold_hours'] as int,
        applied: map['applied'] as bool,
      );

  final int dailySeconds;
  final int nextThresholdHours;
  final bool applied;
}

final class SupervisionNotification {
  const SupervisionNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.createdAt,
    this.linkId,
    this.checkInId,
    this.sosId,
    this.childId,
    this.thresholdHours,
    this.readAt,
  });

  factory SupervisionNotification.fromMap(Map<String, dynamic> map) =>
      SupervisionNotification(
        id: map['id'] as String,
        eventType: _eventType(map['event_type'] as String),
        title: map['title'] as String,
        body: map['body'] as String,
        createdAt: _date(map['created_at']),
        linkId: map['link_id'] as String?,
        checkInId: map['check_in_id'] as String?,
        sosId: map['sos_id'] as String?,
        childId: map['child_id'] as String?,
        thresholdHours: map['threshold_hours'] as int?,
        readAt: _optionalDate(map['read_at']),
      );

  final String id;
  final SupervisionEventType eventType;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? linkId;
  final String? checkInId;
  final String? sosId;
  final String? childId;
  final int? thresholdHours;
  final DateTime? readAt;
}

final class SupervisionDashboardState {
  const SupervisionDashboardState({
    required this.role,
    required this.links,
    required this.ownScreenTime,
    required this.notifications,
  });

  factory SupervisionDashboardState.fromParts({
    required String currentUserId,
    required List<FamilyLink> links,
    required ScreenTimeSummary ownScreenTime,
    required List<SupervisionNotification> notifications,
  }) {
    FamilyRole? role;
    for (final link in links.where((link) =>
        link.status == FamilyLinkStatus.pending ||
        link.status == FamilyLinkStatus.active)) {
      final currentRole = link.parentId == currentUserId
          ? FamilyRole.parent
          : link.childId == currentUserId
              ? FamilyRole.child
              : throw StateError('Current user is not part of family link');
      if (role != null && role != currentRole) {
        throw StateError('Conflicting family roles returned by server');
      }
      role = currentRole;
    }
    final latest = List<SupervisionNotification>.of(notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return SupervisionDashboardState(
      role: role,
      links: List.unmodifiable(links),
      ownScreenTime: ownScreenTime,
      notifications: List.unmodifiable(latest.take(10)),
    );
  }

  final FamilyRole? role;
  final List<FamilyLink> links;
  final ScreenTimeSummary ownScreenTime;
  final List<SupervisionNotification> notifications;
  int get activeLinkCount =>
      links.where((link) => link.status == FamilyLinkStatus.active).length;
  bool get canUseSafetyActions =>
      role == FamilyRole.child && activeLinkCount > 0;
}

FamilyLinkStatus _linkStatus(String value) => switch (value) {
      'pending' => FamilyLinkStatus.pending,
      'active' => FamilyLinkStatus.active,
      'rejected' => FamilyLinkStatus.rejected,
      'cancelled' => FamilyLinkStatus.cancelled,
      'revoked' => FamilyLinkStatus.revoked,
      _ => throw FormatException('Unknown family link status: $value'),
    };

SosStatus _sosStatus(String value) => switch (value) {
      'open' => SosStatus.open,
      'acknowledged' => SosStatus.acknowledged,
      'resolved' => SosStatus.resolved,
      _ => throw FormatException('Unknown SOS status: $value'),
    };

LocationStatus _locationStatus(String? value) => switch (value) {
      null || 'not_requested' => LocationStatus.notRequested,
      'available' => LocationStatus.available,
      'unavailable' => LocationStatus.unavailable,
      _ => throw FormatException('Unknown location status: $value'),
    };

SupervisionEventType _eventType(String value) => switch (value) {
      'link_request' => SupervisionEventType.linkRequest,
      'link_accepted' => SupervisionEventType.linkAccepted,
      'link_rejected' => SupervisionEventType.linkRejected,
      'link_cancelled' => SupervisionEventType.linkCancelled,
      'check_in_sent' => SupervisionEventType.checkInSent,
      'check_in_received' => SupervisionEventType.checkInReceived,
      'sos_opened' => SupervisionEventType.sosOpened,
      'sos_acknowledged' => SupervisionEventType.sosAcknowledged,
      'sos_resolved' => SupervisionEventType.sosResolved,
      'screen_time_threshold' => SupervisionEventType.screenTimeThreshold,
      _ => throw FormatException('Unknown supervision event type: $value'),
    };
