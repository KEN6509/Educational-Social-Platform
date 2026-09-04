final class RegistrationRequest {
  const RegistrationRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.termsVersion,
    required this.privacyVersion,
    required this.consentAcceptedAt,
  });

  final String name;
  final String email;
  final String password;
  final String termsVersion;
  final String privacyVersion;
  final DateTime consentAcceptedAt;
}
