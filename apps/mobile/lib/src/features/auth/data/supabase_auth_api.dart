import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SupabaseAuthApi {
  bool get hasConfirmedSession;

  Stream<bool> get confirmedSessionChanges;

  Future<void> signIn({required String email, required String password});

  Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  });

  Future<void> verifySignupOtp({
    required String email,
    required String token,
  });

  Future<void> resendSignupOtp({required String email});
}

final class GoTrueSupabaseAuthApi implements SupabaseAuthApi {
  GoTrueSupabaseAuthApi(this._auth);

  final GoTrueClient _auth;

  @override
  bool get hasConfirmedSession =>
      _auth.currentSession?.user.emailConfirmedAt != null;

  @override
  Stream<bool> get confirmedSessionChanges => _auth.onAuthStateChange.map(
        (state) => state.session?.user.emailConfirmedAt != null,
      );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: data,
    );
    return response.session != null;
  }

  @override
  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    await _auth.verifyOTP(email: email, token: token, type: OtpType.signup);
  }

  @override
  Future<void> resendSignupOtp({required String email}) async {
    await _auth.resend(email: email, type: OtpType.signup);
  }
}
