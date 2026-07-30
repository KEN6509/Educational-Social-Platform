class PasswordPolicyResult {
  const PasswordPolicyResult({
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
  });

  final bool hasMinimumLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;

  bool get isValid =>
      hasMinimumLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSymbol;
}

class PasswordPolicy {
  const PasswordPolicy._();

  static const validationMessage =
      'Use at least 12 characters with uppercase, lowercase, a number, '
      'and a symbol such as . or _.';

  static PasswordPolicyResult evaluate(String value) {
    return PasswordPolicyResult(
      hasMinimumLength: value.length >= 12,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(value),
      hasLowercase: RegExp(r'[a-z]').hasMatch(value),
      hasNumber: RegExp(r'[0-9]').hasMatch(value),
      hasSymbol: RegExp(r'[^A-Za-z0-9\s]').hasMatch(value),
    );
  }

  static String? validationError(String value) {
    return evaluate(value).isValid ? null : validationMessage;
  }
}
