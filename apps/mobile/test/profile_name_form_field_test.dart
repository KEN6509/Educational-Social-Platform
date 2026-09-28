import 'package:cyanzone_mobile/src/core/widgets/profile_name_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the name policy and validates an empty value',
      (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: ProfileNameFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('1–24 characters'), findsOneWidget);
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Name is required.'), findsOneWidget);
  });

  testWidgets('limits entered names to twenty-four characters', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileNameFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField),
      List.filled(25, 'K').join(),
    );

    expect(controller.text.length, 24);
  });
}
