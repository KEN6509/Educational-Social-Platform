import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_gateway.dart';
import '../domain/registration_request.dart';

final class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;
  late final Stream<bool> _signedInChanges = _client.auth.onAuthStateChange
      .map((state) => state.session?.user.emailConfirmedAt != null)
      .distinct();

  @override
  bool get isSignedIn =>
      _client.auth.currentSession?.user.emailConfirmedAt != null;

  @override
  Stream<bool> get signedInChanges => _signedInChanges;

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
  Future<RegistrationOutcome> register(RegistrationRequest request) async {
    try {
      final response = await _client.auth.signUp(
        email: request.email,
        password: request.password,
        data: {
          'name': request.name,
          'terms_version': request.termsVersion,
          'privacy_version': request.privacyVersion,
          'consent_accepted_at':
              request.consentAcceptedAt.toUtc().toIso8601String(),
        },
      );
      return response.session == null
          ? RegistrationOutcome.confirmationRequired
          : RegistrationOutcome.signedIn;
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> resendRegistrationOtp({required String email}) async {
    try {
      await _client.auth.resend(email: email, type: OtpType.signup);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
