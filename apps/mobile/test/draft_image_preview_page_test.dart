import 'dart:convert';

import 'package:cyanzone_mobile/src/features/posts/presentation/draft_image_preview_page.dart';
import 'package:cyanzone_mobile/src/features/posts/presentation/zoomable_preview_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==',
  );

  testWidgets(
      'opens at the tapped image, pages, and closes without editing images',
      (tester) async {
    final images = <ImageProvider>[
      MemoryImage(pixel),
      MemoryImage(pixel),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        DraftImagePreviewPage(images: images, initialIndex: 1),
                  )),
                  child: const Text('Open preview'),
                )),
      ),
    ));

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(
        tester
            .widget<ZoomablePreviewImage>(
                find.byType(ZoomablePreviewImage).first)
            .image,
        same(images[1]));

    await tester.flingFrom(const Offset(300, 400), const Offset(250, 0), 1000);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page,
        lessThan(0.5));
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(find.text('Open preview'), findsOneWidget);
    expect(images, hasLength(2));
  });
}
