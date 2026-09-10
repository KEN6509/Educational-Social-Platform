enum PushRoute {
  conversation,
  post,
  profile,
  systemNotification,
  familyLink,
  checkIn,
  sos,
  screenTime,
}

class PushDestination {
  const PushDestination({
    required this.sourceTable,
    required this.sourceId,
    required this.route,
    this.notificationId,
    this.conversationId,
    this.postId,
    this.commentId,
    this.profileId,
    this.linkId,
    this.checkInId,
    this.sosId,
    this.childId,
  });

  final String sourceTable;
  final String sourceId;
  final PushRoute route;
  final String? notificationId;
  final String? conversationId;
  final String? postId;
  final String? commentId;
  final String? profileId;
  final String? linkId;
  final String? checkInId;
  final String? sosId;
  final String? childId;

  static PushDestination? tryParse(Map<String, dynamic> raw) {
    final map = raw['destination'] is Map
        ? Map<String, dynamic>.from(raw['destination'] as Map)
        : raw;
    if (map['version'] != '1') return null;
    final sourceTable = _string(map['sourceTable']);
    final sourceId = _string(map['sourceId']);
    final routeName = _string(map['route']);
    if (sourceTable == null || sourceId == null || routeName == null) {
      return null;
    }
    final route = switch (routeName) {
      'conversation' => PushRoute.conversation,
      'post' => PushRoute.post,
      'profile' => PushRoute.profile,
      'system_notification' => PushRoute.systemNotification,
      'family_link' => PushRoute.familyLink,
      'check_in' => PushRoute.checkIn,
      'sos' => PushRoute.sos,
      'screen_time' => PushRoute.screenTime,
      _ => null,
    };
    if (route == null) return null;
    final destination = PushDestination(
      sourceTable: sourceTable,
      sourceId: sourceId,
      route: route,
      notificationId: _string(map['notificationId']),
      conversationId: _string(map['conversationId']),
      postId: _string(map['postId']),
      commentId: _string(map['commentId']),
      profileId: _string(map['profileId']),
      linkId: _string(map['linkId']),
      checkInId: _string(map['checkInId']),
      sosId: _string(map['sosId']),
      childId: _string(map['childId']),
    );
    return destination._isValid ? destination : null;
  }

  Map<String, String> toData() {
    final values = <String, String>{
      'version': '1',
      'sourceTable': sourceTable,
      'sourceId': sourceId,
      'route': switch (route) {
        PushRoute.conversation => 'conversation',
        PushRoute.post => 'post',
        PushRoute.profile => 'profile',
        PushRoute.systemNotification => 'system_notification',
        PushRoute.familyLink => 'family_link',
        PushRoute.checkIn => 'check_in',
        PushRoute.sos => 'sos',
        PushRoute.screenTime => 'screen_time',
      },
    };
    final optional = <String, String?>{
      'notificationId': notificationId,
      'conversationId': conversationId,
      'postId': postId,
      'commentId': commentId,
      'profileId': profileId,
      'linkId': linkId,
      'checkInId': checkInId,
      'sosId': sosId,
      'childId': childId,
    };
    optional.forEach((key, value) {
      if (value != null) values[key] = value;
    });
    return values;
  }

  bool get _isValid {
    final ordinary = sourceTable == 'notifications';
    final supervision = sourceTable == 'supervision_notifications';
    return switch (route) {
      PushRoute.conversation => ordinary && conversationId != null,
      PushRoute.post => ordinary && postId != null,
      PushRoute.profile => ordinary && profileId != null,
      PushRoute.systemNotification => ordinary && notificationId != null,
      PushRoute.familyLink => supervision && linkId != null,
      PushRoute.checkIn => supervision && checkInId != null,
      PushRoute.sos => supervision && sosId != null,
      PushRoute.screenTime => supervision && childId != null,
    };
  }

  static String? _string(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class ResolvedPushDestination {
  const ResolvedPushDestination({
    required this.destination,
    required this.source,
  });

  final PushDestination destination;
  final Map<String, dynamic> source;

  static ResolvedPushDestination? tryParse(Map<String, dynamic> raw) {
    final destination = PushDestination.tryParse(raw);
    final rawSource = raw['source'];
    if (destination == null || rawSource is! Map) return null;
    final source = Map<String, dynamic>.from(rawSource);
    if (PushDestination._string(source['id']) != destination.sourceId ||
        PushDestination._string(source['sourceTable']) !=
            destination.sourceTable) {
      return null;
    }
    return ResolvedPushDestination(
      destination: destination,
      source: Map.unmodifiable(source),
    );
  }
}
