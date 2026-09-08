import 'dart:async';

import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/domain/registration_request.dart';

final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({bool isSignedIn = false}) : _isSignedIn = isSignedIn;

  final _signedInController = StreamController<bool>.broadcast();
  bool _isSignedIn;

  String? signInEmail;
  String? signInPassword;
  Object? signInError;

  RegistrationRequest? registrationRequest;
  String? get registrationName => registrationRequest?.name;
  String? get registrationEmail => registrationRequest?.email;
  String? get registrationPassword => registrationRequest?.password;
  Object? registrationError;
  RegistrationOutcome registrationOutcome = RegistrationOutcome.signedIn;
  String? verificationEmail;
  String? verificationToken;
  Object? verificationError;
  String? resendEmail;
  Object? resendError;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  Stream<bool> get signedInChanges => _signedInController.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) {
      throw error;
    }
    signInEmail = email;
    signInPassword = password;
  }

  @override
  Future<RegistrationOutcome> register(RegistrationRequest request) async {
    final error = registrationError;
    if (error != null) {
      throw error;
    }
    registrationRequest = request;
    return registrationOutcome;
  }

  @override
  Future<void> verifyRegistrationOtp({
    required String email,
    required String token,
  }) async {
    final error = verificationError;
    if (error != null) {
      throw error;
    }
    verificationEmail = email;
    verificationToken = token;
  }

  @override
  Future<void> resendRegistrationOtp({required String email}) async {
    final error = resendError;
    if (error != null) {
      throw error;
    }
    resendEmail = email;
  }

  void emitSignedIn(bool value) {
    _isSignedIn = value;
    _signedInController.add(value);
  }

  Future<void> dispose() => _signedInController.close();
}
