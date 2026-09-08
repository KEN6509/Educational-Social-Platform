enum PendingModerationTargetType { post, comment }

final class PendingModerationTarget {
  const PendingModerationTarget._(this.type, this.id);

  const PendingModerationTarget.post(String id)
      : this._(PendingModerationTargetType.post, id);

  const PendingModerationTarget.comment(String id)
      : this._(PendingModerationTargetType.comment, id);

  final PendingModerationTargetType type;
  final String id;

  String get storageValue => '${type.name}:$id';

  static PendingModerationTarget? tryParse(String value) {
    final separator = value.indexOf(':');
    if (separator <= 0 || separator == value.length - 1) return null;
    final type = value.substring(0, separator);
    final id = value.substring(separator + 1).trim();
    if (id.isEmpty) return null;
    return switch (type) {
      'post' => PendingModerationTarget.post(id),
      'comment' => PendingModerationTarget.comment(id),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PendingModerationTarget &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

abstract interface class PendingModerationRetryStore {
  Future<List<PendingModerationTarget>> load();

  Future<void> save(PendingModerationTarget target);

  Future<void> remove(PendingModerationTarget target);
}
