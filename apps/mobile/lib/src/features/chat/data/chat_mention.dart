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

  Map<String, Object> toRpcMap(String body) => {
        'user_id': userId,
        'display_text': displayText,
        'start_offset': body.substring(0, start).runes.length,
        'end_offset': body.substring(0, end).runes.length,
        'is_all': isAll,
      };

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'display_text': displayText,
        'start': start,
        'end': end,
        'is_all': isAll,
        'visited_at': visitedAt?.toIso8601String(),
      };

  factory ChatMention.fromMap(Map<dynamic, dynamic> map, {String? body}) {
    final cachedStart = map['start'];
    final cachedEnd = map['end'];
    final rawStart = _asInt(cachedStart ?? map['start_offset']);
    final rawEnd = _asInt(cachedEnd ?? map['end_offset']);
    return ChatMention(
      userId: '${map['mentioned_user_id'] ?? map['user_id'] ?? ''}',
      displayText: '${map['display_text'] ?? ''}',
      start: cachedStart != null || body == null
          ? rawStart
          : _codePointOffsetToUtf16(body, rawStart),
      end: cachedEnd != null || body == null
          ? rawEnd
          : _codePointOffsetToUtf16(body, rawEnd),
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

  static int _codePointOffsetToUtf16(String value, int codePointOffset) {
    if (codePointOffset <= 0) return 0;
    return String.fromCharCodes(value.runes.take(codePointOffset)).length;
  }
}
