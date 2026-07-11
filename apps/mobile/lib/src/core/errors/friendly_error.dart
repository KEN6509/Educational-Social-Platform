String friendlyErrorTitle(Object? error) {
  final message = error.toString().toLowerCase();
  if (message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network') ||
      message.contains('connection') ||
      message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('clientexception') ||
      message.contains('xmlhttprequest')) {
    return 'No internet connection';
  }
  return 'Something went wrong';
}

String friendlyErrorMessage(Object? error) {
  final title = friendlyErrorTitle(error);
  if (title == 'No internet connection') {
    return 'Please check your connection and try again.';
  }
  return 'Please try again in a moment.';
}
