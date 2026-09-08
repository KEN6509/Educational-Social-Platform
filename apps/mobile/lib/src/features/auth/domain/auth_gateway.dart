import 'registration_request.dart';

enum RegistrationOutcome {
  signedIn,
  confirmationRequired,
}

enum AuthFailureReason {
  emailNotConfirmed,
  invalidOtp,
  expiredOtp,
  rateLimited,
  network,
  other,
}

final class AuthFailure implements Exception {
  const AuthFailure(
    this.message, {
    this.reason = AuthFailureReason.other,
  });

  final String message;
  final AuthFailureReason reason;

  @override
  String toString() => message;
}

abstract interface class AuthGateway {
  bool get isSignedIn;

  Stream<bool> get signedInChanges;

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<RegistrationOutcome> register(RegistrationRequest request);

  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  });

  Future<void> resendRegistrationOtp({required String email});
}
