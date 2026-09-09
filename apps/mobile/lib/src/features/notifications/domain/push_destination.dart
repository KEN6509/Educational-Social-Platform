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
    return PushDestination(
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
  }

  Map<String, String> toData() {
    final values = <String, String>{
      'version': '1',
      'sourceTable': sourceTable,
      'sourceId': sourceId,
      'route': route.name == 'systemNotification'
          ? 'system_notification'
          : route.name,
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

  static String? _string(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
