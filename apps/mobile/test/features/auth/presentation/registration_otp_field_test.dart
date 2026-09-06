import 'package:cyanzone_mobile/src/features/auth/presentation/registration_otp_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders six cells as one centered group', (tester) async {
    final controller = TextEditingController(text: '123');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationOtpField(controller: controller),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('registration-otp-cells')),
      findsOneWidget,
    );
    for (var index = 0; index < 6; index++) {
      expect(
        find.byKey(ValueKey('registration-otp-cell-$index')),
        findsOneWidget,
      );
    }
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('registration-otp-cells')),
        matching: find.byType(Center),
      ),
      findsOneWidget,
    );
  });

  testWidgets('accepts six digits and submits only when complete',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submitted = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationOtpField(
            controller: controller,
            onSubmitted: (value) => submitted = value,
          ),
        ),
      ),
    );

    final input = find.byKey(const ValueKey('registration-otp-field'));
    final field = tester.widget<TextField>(input);
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(
      field.inputFormatters!
          .whereType<LengthLimitingTextInputFormatter>()
          .single
          .maxLength,
      6,
    );

    await tester.enterText(input, '12345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, isEmpty);

    await tester.enterText(input, '12ab345678');
    expect(controller.text, '123456');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, '123456');
  });

  testWidgets('highlights the next empty cell while focused', (tester) async {
    final controller = TextEditingController(text: '12');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFF4490AD)),
        home: Scaffold(
          body: RegistrationOtpField(controller: controller),
        ),
      ),
    );

    final activeCell = find.byKey(const ValueKey('registration-otp-cell-2'));
    final before = tester.widget<AnimatedContainer>(activeCell);
    final beforeBorder =
        (before.decoration! as BoxDecoration).border! as Border;

    await tester.tap(find.byKey(const ValueKey('registration-otp-field')));
    await tester.pumpAndSettle();

    final after = tester.widget<AnimatedContainer>(activeCell);
    final afterBorder = (after.decoration! as BoxDecoration).border! as Border;
    expect(afterBorder.top.width, greaterThan(beforeBorder.top.width));
    expect(afterBorder.top.color,
        Theme.of(tester.element(activeCell)).colorScheme.primary);
  });
}
