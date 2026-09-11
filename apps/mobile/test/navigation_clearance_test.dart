import 'dart:io';

import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/core/widgets/navigation_clearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigation-aware insets preserve injected bottom clearance',
      (tester) async {
    EdgeInsets? observedInsets;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 86)),
          child: Builder(
            builder: (context) {
              observedInsets = withNavigationClearance(
                context,
                const EdgeInsets.fromLTRB(14, 10, 14, 24),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(observedInsets, const EdgeInsets.fromLTRB(14, 10, 14, 86));
  });

  test('Home feed applies navigation-aware padding to its final sliver', () {
    final source = File(
      'lib/src/features/posts/presentation/home_feed_page.dart',
    ).readAsStringSync();

    expect(source, contains('withNavigationClearance('));
  });

  testWidgets('supports extra breathing room above floating navigation',
      (tester) async {
    EdgeInsets? observedInsets;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 86)),
          child: Builder(
            builder: (context) {
              observedInsets = withNavigationClearance(
                context,
                const EdgeInsets.fromLTRB(20, 0, 20, 40),
                additionalBottom: AppSpacing.lg,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(observedInsets, const EdgeInsets.fromLTRB(20, 0, 20, 102));
  });
}
