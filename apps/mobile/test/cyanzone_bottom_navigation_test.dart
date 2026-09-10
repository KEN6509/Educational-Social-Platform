import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/features/shell/presentation/widgets/cyanzone_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the floating navigation and routes taps',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
          child: Scaffold(
            extendBody: true,
            body: ColoredBox(color: AppColors.mint),
            bottomNavigationBar: CyanZoneBottomNavigation(
              selectedIndex: selectedIndex,
              chatBadgeCount: 3,
              onTap: (value) => selectedIndex = value,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.supervised_user_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CyanZoneBottomNavigation)).height,
      AppLayout.floatingNavigationClearance + 24,
    );

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    expect(selectedIndex, 3);
  });

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
}

void _noop(int _) {}
