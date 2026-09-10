import 'package:cyanzone_mobile/src/core/widgets/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides zero and caps large unread counts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 0)));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: UnreadBadge(count: 120)));
    expect(find.text('99+'), findsOneWidget);
  });
}
