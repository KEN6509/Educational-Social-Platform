String formatPostDate(DateTime dateTime, DateTime now) {
  final localDate = dateTime.toLocal();
  final diff = _nonNegativeDifference(now, localDate);

  if (diff.inDays >= 1 && diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }
  if (diff.inHours >= 1 && diff.inDays < 1) {
    return '${diff.inHours}h ago';
  }
  if (diff.inMinutes < 60 && diff.inHours < 1) {
    return '${diff.inMinutes.clamp(1, 59)}m ago';
  }
  return _absoluteDate(localDate, now);
}

String formatCommentDate(DateTime dateTime, DateTime now) {
  final localDate = dateTime.toLocal();
  final diff = _nonNegativeDifference(now, localDate);

  if (diff.inDays >= 1 && diff.inDays < 7) {
    return '${diff.inDays}d';
  }
  if (diff.inHours >= 1 && diff.inDays < 1) {
    return '${diff.inHours}h';
  }
  if (diff.inMinutes < 60 && diff.inHours < 1) {
    return '${diff.inMinutes.clamp(1, 59)}m';
  }
  return _absoluteDate(localDate, now);
}

Duration _nonNegativeDifference(DateTime now, DateTime localDate) {
  final diff = now.difference(localDate);
  return diff.isNegative ? Duration.zero : diff;
}

String _absoluteDate(DateTime localDate, DateTime now) {
  if (localDate.year == now.year) {
    return '${_two(localDate.month)}-${_two(localDate.day)}';
  }
  return '${localDate.year}-${_two(localDate.month)}-${_two(localDate.day)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
