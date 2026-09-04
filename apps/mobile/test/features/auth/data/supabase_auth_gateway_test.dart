import 'dart:async';

import 'package:cyanzone_mobile/src/features/auth/data/supabase_auth_api.dart';
import 'package:cyanzone_mobile/src/features/auth/data/supabase_auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/domain/registration_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late FakeSupabaseAuthApi api;

  setUp(() {
    api = FakeSupabaseAuthApi();
  });

  tearDown(() async {
    await api.dispose();
  });

  test('exposes one stable authentication-state stream', () {
    final gateway = SupabaseAuthGateway.fromApi(api);

    expect(identical(gateway.signedInChanges, gateway.signedInChanges), isTrue);
  });

  test('register sends versioned consent metadata', () async {
    final gateway = SupabaseAuthGateway.fromApi(api);
    final acceptedAt = DateTime.utc(2026, 9, 4, 9);

    final outcome = await gateway.register(RegistrationRequest(
      name: 'Ming Jiang',
      email: 'ming@example.com',
      password: 'StrongPass12!',
      termsVersion: '1.0',
      privacyVersion: '1.0',
      consentAcceptedAt: acceptedAt,
    ));

    expect(outcome, RegistrationOutcome.confirmationRequired);
    expect(api.signUpEmail, 'ming@example.com');
    expect(api.signUpPassword, 'StrongPass12!');
    expect(api.signUpData, {
      'name': 'Ming Jiang',
      'terms_version': '1.0',
      'privacy_version': '1.0',
      'consent_accepted_at': '2026-09-04T09:00:00.000Z',
    });
  });

  test('verification and resend use signup OTP', () async {
    final gateway = SupabaseAuthGateway.fromApi(api);

    await gateway.verifyRegistrationOtp(
      email: 'ming@example.com',
      token: '123456',
    );
    await gateway.resendRegistrationOtp(email: 'ming@example.com');

    expect(api.verifiedEmail, 'ming@example.com');
    expect(api.verifiedToken, '123456');
    expect(api.resentEmail, 'ming@example.com');
  });

  test('only confirmed sessions are signed in', () {
    final gateway = SupabaseAuthGateway.fromApi(api);
    expect(gateway.isSignedIn, isFalse);

    api.isConfirmedSession = true;
    expect(gateway.isSignedIn, isTrue);
  });

  test('maps unconfirmed login to a recoverable failure', () async {
    api.signInError = const AuthException(
      'Email not confirmed',
      code: 'email_not_confirmed',
    );
    final gateway = SupabaseAuthGateway.fromApi(api);

    await expectLater(
      gateway.signIn(email: 'ming@example.com', password: 'Secret123!'),
      throwsA(
        isA<AuthFailure>()
            .having((error) => error.reason, 'reason',
                AuthFailureReason.emailNotConfirmed)
            .having((error) => error.message, 'message',
                'Verify your email before logging in.'),
      ),
    );
  });

  test('maps OTP expiry and network errors safely', () async {
    final gateway = SupabaseAuthGateway.fromApi(api);

    api.verifyError = const AuthException(
      'Token has expired',
      code: 'otp_expired',
    );
    await expectLater(
      gateway.verifyRegistrationOtp(
        email: 'ming@example.com',
        token: '123456',
      ),
      throwsA(isA<AuthFailure>().having(
        (error) => error.reason,
        'reason',
        AuthFailureReason.expiredOtp,
      )),
    );

    api.verifyError = AuthRetryableFetchException();
    await expectLater(
      gateway.verifyRegistrationOtp(
        email: 'ming@example.com',
        token: '123456',
      ),
      throwsA(isA<AuthFailure>().having(
        (error) => error.reason,
        'reason',
        AuthFailureReason.network,
      )),
    );
  });
}

final class FakeSupabaseAuthApi implements SupabaseAuthApi {
  final _stateController = StreamController<bool>.broadcast();

  bool isConfirmedSession = false;
  bool signUpHasSession = false;
  Object? signInError;
  Object? signUpError;
  Object? verifyError;
  Object? resendError;
  String? signUpEmail;
  String? signUpPassword;
  Map<String, dynamic>? signUpData;
  String? verifiedEmail;
  String? verifiedToken;
  String? resentEmail;

  @override
  bool get hasConfirmedSession => isConfirmedSession;

  @override
  Stream<bool> get confirmedSessionChanges => _stateController.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError case final error?) throw error;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    if (signUpError case final error?) throw error;
    signUpEmail = email;
    signUpPassword = password;
    signUpData = data;
    return signUpHasSession;
  }

  @override
  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    if (verifyError case final error?) throw error;
    verifiedEmail = email;
    verifiedToken = token;
  }

  @override
  Future<void> resendSignupOtp({required String email}) async {
    if (resendError case final error?) throw error;
    resentEmail = email;
  }

  Future<void> dispose() => _stateController.close();
}
