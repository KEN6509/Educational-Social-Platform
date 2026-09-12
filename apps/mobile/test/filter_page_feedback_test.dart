import 'package:cyanzone_mobile/src/core/theme/app_theme.dart';
import 'package:cyanzone_mobile/src/features/posts/data/tag_catalog.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/filter_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tag selection limit keeps its two-second warning',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FilterPage(
          initialSelectedTags: const {
            'one',
            'two',
            'three',
            'four',
            'five',
          },
          tagsFuture: Future.value(const [
            TagCategory(
              name: 'Test topics',
              tags: [
                TagOption(name: 'One', slug: 'one'),
                TagOption(name: 'Two', slug: 'two'),
                TagOption(name: 'Three', slug: 'three'),
                TagOption(name: 'Four', slug: 'four'),
                TagOption(name: 'Five', slug: 'five'),
                TagOption(name: 'Six', slug: 'six'),
              ],
            ),
          ]),
          isSelectionMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Six'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(find.text('Maximum 5 tags allowed'), findsOneWidget);
    expect(snackBar.duration, const Duration(seconds: 2));
  });
}
