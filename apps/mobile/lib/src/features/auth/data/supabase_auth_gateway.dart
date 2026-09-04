import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_gateway.dart';

final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges => _client.auth.onAuthStateChange
      .map((state) => state.session != null)
      .distinct();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<RegistrationOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      return response.session == null
          ? RegistrationOutcome.confirmationRequired
          : RegistrationOutcome.signedIn;
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
