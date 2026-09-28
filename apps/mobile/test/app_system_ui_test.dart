import 'package:cyanzone_mobile/src/core/theme/app_system_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system UI keeps edge-to-edge navigation free of a contrast scrim', () {
    expect(
      cyanZoneSystemUiOverlayStyle.systemNavigationBarColor,
      Colors.transparent,
    );
    expect(
      cyanZoneSystemUiOverlayStyle.systemNavigationBarDividerColor,
      Colors.transparent,
    );
    expect(
      cyanZoneSystemUiOverlayStyle.systemNavigationBarContrastEnforced,
      isFalse,
    );
    expect(
      cyanZoneSystemUiOverlayStyle.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });
}
