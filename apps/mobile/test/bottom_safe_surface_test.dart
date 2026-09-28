import 'package:cyanzone_mobile/src/core/theme/app_design_tokens.dart';
import 'package:cyanzone_mobile/src/core/widgets/bottom_safe_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in const [Size(360, 800), Size(412, 915)]) {
    testWidgets('owns the physical bottom at $viewport', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport,
              padding: const EdgeInsets.only(bottom: 34),
            ),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: BottomSafeSurface(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: SizedBox(height: 62),
                ),
              ),
            ),
          ),
        ),
      );

      final surface = find.byType(BottomSafeSurface);
      final padding = tester.widget<Padding>(
        find.descendant(of: surface, matching: find.byType(Padding)).first,
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(12, 8, 12, 46));
      expect(tester.getSize(surface).height, 116);
      expect(tester.getBottomLeft(surface).dy, viewport.height);
      expect(
        tester.widget<BottomSafeSurface>(surface).color,
        AppColors.background,
      );
    });
  }
}
