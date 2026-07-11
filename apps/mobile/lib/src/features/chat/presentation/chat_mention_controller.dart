import '../data/chat_mention.dart';

class ChatMentionEditResult {
  const ChatMentionEditResult({
    required this.text,
    required this.selectionOffset,
    required this.mentions,
  });

  final String text;
  final int selectionOffset;
  final List<ChatMention> mentions;
}

class ChatMentionController {
  List<ChatMention> _mentions = const [];

  List<ChatMention> get mentions => List.unmodifiable(_mentions);

  String? queryFor(String text, int selectionOffset) {
    if (selectionOffset < 0 || selectionOffset > text.length) return null;
    final before = text.substring(0, selectionOffset);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(before);
    return match?.group(1);
  }

  ChatMentionEditResult insertMention({
    required String text,
    required int selectionOffset,
    required String userId,
    required String displayName,
    bool isAll = false,
  }) {
    final before = text.substring(0, selectionOffset);
    final match = RegExp(r'(?:^|\s)@[^\s@]*$').firstMatch(before);
    if (match == null) {
      return ChatMentionEditResult(
        text: text,
        selectionOffset: selectionOffset,
        mentions: mentions,
      );
    }
    final tokenStart = before.lastIndexOf('@');
    final displayText = isAll ? '@all' : '@${displayName.trim()}';
    final replacement = '$displayText ';
    final removedLength = selectionOffset - tokenStart;
    final delta = replacement.length - removedLength;
    final next =
        '${text.substring(0, tokenStart)}$replacement${text.substring(selectionOffset)}';
    final adjusted = _mentions
        .where((mention) =>
            mention.end <= tokenStart || mention.start >= selectionOffset)
        .map((mention) => mention.start >= selectionOffset
            ? ChatMention(
                userId: mention.userId,
                displayText: mention.displayText,
                start: mention.start + delta,
                end: mention.end + delta,
                isAll: mention.isAll,
                visitedAt: mention.visitedAt,
              )
            : mention)
        .toList();
    adjusted.add(ChatMention(
      userId: userId,
      displayText: displayText,
      start: tokenStart,
      end: tokenStart + displayText.length,
      isAll: isAll,
    ));
    adjusted.sort((a, b) => a.start.compareTo(b.start));
    _mentions = adjusted;
    return ChatMentionEditResult(
      text: next,
      selectionOffset: tokenStart + replacement.length,
      mentions: mentions,
    );
  }

  List<ChatMention> reconcile({
    required String previousText,
    required String text,
  }) {
    if (previousText == text) return mentions;
    _mentions = _mentions.where((mention) => mention.matches(text)).toList();
    return mentions;
  }

  void clear() => _mentions = const [];
}
