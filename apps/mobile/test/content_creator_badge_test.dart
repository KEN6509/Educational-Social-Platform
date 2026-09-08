import 'package:cyanzone_mobile/src/features/profile/presentation/content_creator_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creator badge uses a cyan rosette with a white tick',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentCreatorBadge(isVisible: true, size: 24),
        ),
      ),
    );

    final rosette = tester.widget<Icon>(find.byIcon(Icons.verified_rounded));
    final tick = tester.widget<Icon>(find.byIcon(Icons.check_rounded));

    expect(rosette.color, const Color(0xFF4490AD));
    expect(tick.color, Colors.white);
    expect(
        find.byKey(const ValueKey('verified-creator-rosette')), findsOneWidget);
  });

  testWidgets('creator badge stays hidden for ordinary members',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentCreatorBadge(isVisible: false),
        ),
      ),
    );

    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });
}
