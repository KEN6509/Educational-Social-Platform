enum RegistrationOutcome {
  signedIn,
  confirmationRequired,
}

final class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

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

  Future<RegistrationOutcome> register({
    required String name,
    required String email,
    required String password,
  });
}
