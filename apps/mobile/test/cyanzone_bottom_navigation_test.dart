import 'dart:io';

import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in const [Size(320, 640), Size(412, 915)]) {
    testWidgets('routes all destinations at ${viewport.width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 24),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              extendBody: true,
              body: const ColoredBox(color: AppColors.mint),
              bottomNavigationBar: CyanZoneBottomNavigation(
                selectedIndex: 0,
                chatBadgeCount: 3,
                onTap: taps.add,
              ),
            ),
          ),
        ),
      );

      Finder destination(String label) => find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == label,
          );

      const labels = ['Home', 'Parent-Child', 'Create', 'Chats', 'Profile'];
      for (var index = 0; index < labels.length; index += 1) {
        final finder = destination(labels[index]);
        expect(finder, findsOneWidget);
        await tester.tap(finder);
        expect(taps.last, index);
      }
      expect(find.text('3'), findsOneWidget);
      expect(
        tester.getSize(find.byType(CyanZoneBottomNavigation)).height,
        AppLayout.floatingNavigationClearance + 24,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses the rounded surface token for the navigation pill',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.shrink(),
          bottomNavigationBar: CyanZoneBottomNavigation(
            selectedIndex: 0,
            onTap: _noop,
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(CyanZoneBottomNavigation),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.navigation));
  });

  testWidgets('extendBody exposes navigation clearance to nested tab scaffolds',
      (tester) async {
    double? observedBottomPadding;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Scaffold(
            body: Builder(
              builder: (context) {
                observedBottomPadding = MediaQuery.paddingOf(context).bottom;
                return const SizedBox.expand();
              },
            ),
          ),
          bottomNavigationBar: const SizedBox(
            height: AppLayout.floatingNavigationClearance,
          ),
        ),
      ),
    );

    expect(observedBottomPadding, AppLayout.floatingNavigationClearance);
  });

  test('main shell enables extendBody and delegates all navigation taps', () {
    final source = File(
      'lib/src/features/shell/presentation/main_shell.dart',
    ).readAsStringSync();

    expect(source, contains('extendBody: true'));
    expect(source, contains('onTap: _handleNavigationTap'));
    expect(source, contains('chatBadgeCount: _chatBadgeCount'));
    expect(source, contains('if (value == 0)'));
    expect(source, contains('else if (value == 4)'));
  });
}

void _noop(int _) {}
