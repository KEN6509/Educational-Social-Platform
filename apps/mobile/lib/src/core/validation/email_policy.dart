abstract final class EmailPolicy {
  static const maxLength = 254;
  static const validationMessage = 'Enter a valid email address.';

  static final _format = RegExp(
    r'^[^\s@]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
  );

  static String? validationError(String value) {
    final email = value.trim();
    if (email.isEmpty || email.length > maxLength || !_format.hasMatch(email)) {
      return validationMessage;
    }
    return null;
  }
}
