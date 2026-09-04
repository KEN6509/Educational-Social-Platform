import 'dart:async';

import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';

final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({bool isSignedIn = false}) : _isSignedIn = isSignedIn;

  final _signedInController = StreamController<bool>.broadcast();
  bool _isSignedIn;

  String? signInEmail;
  String? signInPassword;
  Object? signInError;

  String? registrationName;
  String? registrationEmail;
  String? registrationPassword;
  Object? registrationError;
  RegistrationOutcome registrationOutcome = RegistrationOutcome.signedIn;

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
  Future<RegistrationOutcome> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final error = registrationError;
    if (error != null) {
      throw error;
    }
    registrationName = name;
    registrationEmail = email;
    registrationPassword = password;
    return registrationOutcome;
  }

  void emitSignedIn(bool value) {
    _isSignedIn = value;
    _signedInController.add(value);
  }

  Future<void> dispose() => _signedInController.close();
}
