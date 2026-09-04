import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_gateway.dart';
import '../domain/registration_request.dart';
import 'supabase_auth_api.dart';

final class SupabaseAuthGateway implements AuthGateway {
  factory SupabaseAuthGateway(SupabaseClient client) {
    return SupabaseAuthGateway.fromApi(GoTrueSupabaseAuthApi(client.auth));
  }

  SupabaseAuthGateway.fromApi(this._api);

  final SupabaseAuthApi _api;
  late final Stream<bool> _signedInChanges =
      _api.confirmedSessionChanges.distinct();

  @override
  bool get isSignedIn => _api.hasConfirmedSession;

  @override
  Stream<bool> get signedInChanges => _signedInChanges;

  @override
  Future<void> signIn({required String email, required String password}) {
    return _guard(() => _api.signIn(email: email, password: password));
  }

  @override
  Future<RegistrationOutcome> register(RegistrationRequest request) async {
    final hasSession = await _guard(() => _api.signUp(
          email: request.email,
          password: request.password,
          data: {
            'name': request.name,
            'terms_version': request.termsVersion,
            'privacy_version': request.privacyVersion,
            'consent_accepted_at':
                request.consentAcceptedAt.toUtc().toIso8601String(),
          },
        ));

    return hasSession
        ? RegistrationOutcome.signedIn
        : RegistrationOutcome.confirmationRequired;
  }

  @override
  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  }) {
    return _guard(() => _api.verifySignupOtp(email: email, token: token));
  }

  @override
  Future<void> resendRegistrationOtp({required String email}) {
    return _guard(() => _api.resendSignupOtp(email: email));
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthRetryableFetchException {
      throw const AuthFailure(
        'Unable to reach CyanZone. Check your connection and try again.',
        reason: AuthFailureReason.network,
      );
    } on AuthException catch (error) {
      throw _mapAuthFailure(error);
    }
  }

  AuthFailure _mapAuthFailure(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();

    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return const AuthFailure(
        'Verify your email before logging in.',
        reason: AuthFailureReason.emailNotConfirmed,
      );
    }
    if (code.contains('otp_expired') || message.contains('expired')) {
      return const AuthFailure(
        'That verification code has expired. Request a new code.',
        reason: AuthFailureReason.expiredOtp,
      );
    }
    if (code.contains('rate_limit') || message.contains('rate limit')) {
      return const AuthFailure(
        'Please wait before requesting another verification code.',
        reason: AuthFailureReason.rateLimited,
      );
    }
    if (code.contains('otp') || message.contains('token')) {
      return const AuthFailure(
        'That verification code is not valid.',
        reason: AuthFailureReason.invalidOtp,
      );
    }
    return const AuthFailure(
      'Unable to complete authentication. Please try again.',
    );
  }
}
