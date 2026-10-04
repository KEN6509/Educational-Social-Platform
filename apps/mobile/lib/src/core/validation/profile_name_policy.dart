abstract final class ProfileNamePolicy {
  static const minLength = 1;
  static const maxLength = 24;
  static const helperText = 'Name must contain between 1 and 24 characters.';
  static const requiredError = 'Name is required.';
  static const lengthError = 'Name must be 1–24 characters.';

  static String normalize(String value) => value.trim();

  static String? validate(String? value) {
    final normalized = normalize(value ?? '');
    if (normalized.isEmpty) return requiredError;
    if (normalized.length > maxLength) return lengthError;
    return null;
  }
}
