String formatHiddenRepliesLabel(int count) {
  final noun = count == 1 ? 'reply' : 'replies';
  return 'View $count more $noun';
}
