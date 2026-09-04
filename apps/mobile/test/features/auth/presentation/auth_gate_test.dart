import 'dart:io';

import 'package:cyanzone_mobile/src/features/auth/presentation/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_gateway.dart';

void main() {
  late FakeAuthGateway authGateway;

  setUp(() {
    authGateway = FakeAuthGateway();
    addTearDown(authGateway.dispose);
  });

  Widget buildGate() {
    return MaterialApp(
      home: AuthGate(
        authGateway: authGateway,
        authenticatedChild: const SizedBox(
          key: ValueKey('authenticated-destination'),
        ),
      ),
    );
  }

  testWidgets('shows authentication when initially signed out', (tester) async {
    await tester.pumpWidget(buildGate());

    expect(find.text('Beyond the Blue, Inside the Zone.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('authenticated-destination')),
      findsNothing,
    );
  });

  testWidgets('shows the authenticated destination when initially signed in',
      (tester) async {
    authGateway.emitSignedIn(true);

    await tester.pumpWidget(buildGate());

    expect(
      find.byKey(const ValueKey('authenticated-destination')),
      findsOneWidget,
    );
    expect(find.text('Beyond the Blue, Inside the Zone.'), findsNothing);
  });

  testWidgets('reacts when the gateway emits a signed-in state',
      (tester) async {
    await tester.pumpWidget(buildGate());

    authGateway.emitSignedIn(true);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('authenticated-destination')),
      findsOneWidget,
    );
    expect(find.text('Beyond the Blue, Inside the Zone.'), findsNothing);
  });

  test('AuthGate presentation does not import or access Supabase', () {
    final source = File(
      'lib/src/features/auth/presentation/auth_gate.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('supabase_flutter')));
    expect(source, isNot(contains('Supabase.instance')));
  });
}
