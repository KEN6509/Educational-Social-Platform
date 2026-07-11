class ChatMention {
  const ChatMention({
    required this.userId,
    required this.displayText,
    required this.start,
    required this.end,
    this.isAll = false,
    this.visitedAt,
  });

  final String userId;
  final String displayText;
  final int start;
  final int end;
  final bool isAll;
  final DateTime? visitedAt;

  bool matches(String text) {
    return start >= 0 &&
        end <= text.length &&
        start < end &&
        text.substring(start, end) == displayText;
  }

  Map<String, Object> toRpcMap() => {
        'user_id': userId,
        'display_text': displayText,
        'start_offset': start,
        'end_offset': end,
        'is_all': isAll,
      };

  Map<String, Object?> toJson() => {
        ...toRpcMap(),
        'visited_at': visitedAt?.toIso8601String(),
      };

  factory ChatMention.fromMap(Map<dynamic, dynamic> map) {
    return ChatMention(
      userId: '${map['mentioned_user_id'] ?? map['user_id'] ?? ''}',
      displayText: '${map['display_text'] ?? ''}',
      start: _asInt(map['start_offset']),
      end: _asInt(map['end_offset']),
      isAll: map['is_all_source'] == true || map['is_all'] == true,
      visitedAt: DateTime.tryParse('${map['visited_at'] ?? ''}'),
    );
  }

  static List<String> uniqueRecipientIds(Iterable<ChatMention> values) {
    return values
        .where((value) => !value.isAll)
        .map((value) => value.userId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  static int _asInt(Object? value) {
    return value is int ? value : int.tryParse('$value') ?? 0;
  }
}
