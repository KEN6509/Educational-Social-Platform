import 'package:cyanzone_mobile/src/core/theme/app_input_decoration.dart';
import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
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

    expect(
      find.text('Name must contain between 1 and 24 characters.'),
      findsOneWidget,
    );
    expect(find.text('0/24'), findsNothing);
    expect(
      tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration
          .helperMaxLines,
      2,
    );
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

  testWidgets('shows a live character counter when requested', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileNameFormField(
            controller: controller,
            showCounter: true,
            decoration: appInputDecoration(hintText: 'Enter your name'),
          ),
        ),
      ),
    );

    expect(find.text('0/24'), findsOneWidget);
    final initialCounter = tester.widget<Text>(find.text('0/24'));
    expect(initialCounter.style?.fontSize, 11);
    expect(initialCounter.style?.color, AppColors.textMuted);

    await tester.enterText(find.byType(TextFormField), 'Ken');
    await tester.pump();

    expect(find.text('3/24'), findsOneWidget);
  });
}
