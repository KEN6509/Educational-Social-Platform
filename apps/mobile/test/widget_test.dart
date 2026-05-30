import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cyanzone_mobile/src/app.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('shows the auth screen when signed out',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CyanZoneApp());
    await tester.pump();

    expect(find.text('CyanZone'), findsOneWidget);
    expect(
      find.text('Beyond the Blue, Inside the Zone.'),
      findsOneWidget,
    );
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.bySemanticsLabel('CyanZone logo'), findsOneWidget);
  });
}