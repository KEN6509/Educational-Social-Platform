import 'package:cyanzone_mobile/src/features/auth/domain/auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthFailure exposes its safe user-facing message', () {
    const failure = AuthFailure('Invalid login credentials');

    expect(failure.message, 'Invalid login credentials');
    expect(failure.toString(), 'Invalid login credentials');
  });

  test('registration outcome distinguishes session and confirmation flows', () {
    expect(
      RegistrationOutcome.values,
      [
        RegistrationOutcome.signedIn,
        RegistrationOutcome.confirmationRequired,
      ],
    );
  });
}
