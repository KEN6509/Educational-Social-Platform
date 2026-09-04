import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:cyanzone_mobile/src/features/auth/domain/registration_request.dart';
import 'package:cyanzone_mobile/src/features/auth/presentation/registration_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_gateway.dart';
import '../../../support/fake_pending_registration_store.dart';

void main() {
  late FakeAuthGateway authGateway;
  late FakePendingRegistrationStore store;
  late RegistrationController controller;

  final request = RegistrationRequest(
    name: 'Ming Jiang',
    email: '  MING@Example.COM ',
    password: 'StrongPass12!',
    termsVersion: '1.0',
    privacyVersion: '1.0',
    consentAcceptedAt: DateTime.utc(2026, 9, 4),
  );

  setUp(() {
    authGateway = FakeAuthGateway();
    store = FakePendingRegistrationStore();
    controller = RegistrationController(
      authGateway: authGateway,
      pendingRegistrationStore: store,
      countdownDuration: const Duration(seconds: 1),
    );
  });

  tearDown(() {
    controller.dispose();
    authGateway.dispose();
  });

  test('confirmation-required registration saves email and awaits OTP',
      () async {
    authGateway.registrationOutcome = RegistrationOutcome.confirmationRequired;

    await controller.register(request);

    expect(store.email, 'ming@example.com');
    expect(controller.state.phase, RegistrationPhase.awaitingOtp);
    expect(controller.state.pendingEmail, 'ming@example.com');
    expect(controller.state.resendSecondsRemaining, 1);
  });

  test('restore resumes the OTP step without restoring secrets', () async {
    store.email = 'ming@example.com';

    await controller.restore();

    expect(controller.state.phase, RegistrationPhase.awaitingOtp);
    expect(controller.state.pendingEmail, 'ming@example.com');
    expect(controller.state.resendSecondsRemaining, 1);
  });

  test('back clears local pending email and returns to editing', () async {
    store.email = 'ming@example.com';
    await controller.restore();

    await controller.backToForm();

    expect(store.email, isNull);
    expect(controller.state.phase, RegistrationPhase.editing);
    expect(controller.state.pendingEmail, isNull);
  });

  test('successful verification clears pending email', () async {
    store.email = 'ming@example.com';
    await controller.restore();

    await controller.verifyOtp('123456');

    expect(authGateway.verificationEmail, 'ming@example.com');
    expect(authGateway.verificationToken, '123456');
    expect(store.email, isNull);
    expect(controller.state.phase, RegistrationPhase.editing);
  });

  test('verification failure keeps the OTP step', () async {
    store.email = 'ming@example.com';
    authGateway.verificationError = const AuthFailure(
      'That verification code is not valid.',
      reason: AuthFailureReason.invalidOtp,
    );
    await controller.restore();

    await controller.verifyOtp('123456');

    expect(controller.state.phase, RegistrationPhase.awaitingOtp);
    expect(controller.state.pendingEmail, 'ming@example.com');
    expect(controller.state.message, 'That verification code is not valid.');
  });

  test('resend is blocked until the countdown reaches zero', () async {
    store.email = 'ming@example.com';
    await controller.restore();

    await controller.resendOtp();
    expect(authGateway.resendEmail, isNull);

    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 50));
    await controller.resendOtp();

    expect(authGateway.resendEmail, 'ming@example.com');
    expect(controller.state.resendSecondsRemaining, 1);
  });

  test('unconfirmed login can resume OTP recovery', () async {
    await controller.resumeUnconfirmedLogin('  USER@Example.COM ');

    expect(store.email, 'user@example.com');
    expect(controller.state.phase, RegistrationPhase.awaitingOtp);
    expect(controller.state.message, 'Verify your email before logging in.');
  });
}
