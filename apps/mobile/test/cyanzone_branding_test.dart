import 'dart:io';

import 'package:cyanzone_mobile/src/app.dart';
import 'package:cyanzone_mobile/src/app_dependencies.dart';
import 'package:cyanzone_mobile/src/core/widgets/cyanzone_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_gateway.dart';
import 'support/fake_content_moderation_gateway.dart';
import 'support/fake_pending_registration_store.dart';

void main() {
  testWidgets('authentication uses the local Pacifico brand treatment',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authGateway = FakeAuthGateway();
    addTearDown(authGateway.dispose);

    await tester.pumpWidget(
      CyanZoneApp(
        dependencies: AppDependencies(
          authGateway: authGateway,
          pendingRegistrationStore: FakePendingRegistrationStore(),
          contentModerationGateway: FakeContentModerationGateway(),
        ),
      ),
    );
    await tester.pump();

    final wordmarkText = tester.widget<Text>(find.text('CyanZone'));
    final wordmark = tester.widget<CyanZoneWordmark>(
      find.byType(CyanZoneWordmark),
    );
    final slogan = tester.widget<Text>(
      find.text('Beyond the Blue, Inside the Zone.'),
    );
    expect(wordmarkText.style?.fontFamily, 'Pacifico');
    expect(wordmark.fontSize, 36);
    expect(slogan.style?.fontFamily, 'Pacifico');

    final logo = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('cyanzone_logo'),
      ),
    );
    expect(
      (logo.image as AssetImage).assetName,
      'assets/images/cyanzone_logo_white_transparent.png',
    );
    expect(logo.width, 136);
    expect(logo.height, 136);
    final logoRect = tester.getRect(find.byWidget(logo));
    final wordmarkRect = tester.getRect(find.byType(CyanZoneWordmark));
    expect(wordmarkRect.top - logoRect.bottom, lessThanOrEqualTo(4));
  });

  test('home header uses the reusable text wordmark', () {
    final source = File(
      'lib/src/features/shell/presentation/main_shell.dart',
    ).readAsStringSync();

    expect(source, contains('CyanZoneWordmark('));
    expect(source, isNot(contains("'assets/images/logo.png'")));
  });

  test('Android launch screen uses only the CyanZone logo', () {
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final launchBackgroundV21 = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final android12Styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    );
    final android12NightStyles = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    );

    expect(
      launchBackground,
      contains('@drawable/cyanzone_splash_logo'),
    );
    expect(
      launchBackgroundV21,
      contains('@drawable/cyanzone_splash_logo'),
    );
    expect(
      launchBackground,
      isNot(contains('cyanzone_splash_wordmark')),
    );
    expect(
      launchBackgroundV21,
      isNot(contains('cyanzone_splash_wordmark')),
    );
    expect(
      pubspec,
      contains(
        'image_path: "assets/images/cyanzone_app_icon.png"',
      ),
    );
    expect(
      pubspec,
      contains(
        'adaptive_icon_background: '
        '"assets/images/cyanzone_app_icon_background.png"',
      ),
    );
    expect(
      pubspec,
      contains(
        'adaptive_icon_foreground: '
        '"assets/images/cyanzone_app_icon_foreground.png"',
      ),
    );
    expect(android12Styles.existsSync(), isTrue);
    expect(
      android12Styles.readAsStringSync(),
      contains('@drawable/cyanzone_splash_logo'),
    );
    expect(
      android12Styles.readAsStringSync(),
      isNot(contains('android:windowSplashScreenBrandingImage')),
    );
    expect(android12NightStyles.existsSync(), isTrue);
    expect(
      android12NightStyles.readAsStringSync(),
      contains('@drawable/cyanzone_splash_logo'),
    );
    expect(
      android12NightStyles.readAsStringSync(),
      isNot(contains('android:windowSplashScreenBrandingImage')),
    );
    expect(
      File(
        'android/app/src/main/res/drawable/'
        'cyanzone_splash_wordmark.xml',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'android/app/src/main/res/drawable-xxxhdpi/'
        'cyanzone_splash_wordmark.png',
      ).existsSync(),
      isFalse,
    );
    expect(
      android12Styles.readAsStringSync(),
      isNot(contains('android:postSplashScreenTheme')),
    );
    expect(
      android12NightStyles.readAsStringSync(),
      isNot(contains('android:postSplashScreenTheme')),
    );
  });

  test('launcher uses a light high-contrast mint-to-blue gradient', () {
    final background = img.decodePng(
      File(
        'assets/images/cyanzone_app_icon_background.png',
      ).readAsBytesSync(),
    )!;
    final foreground = img.decodePng(
      File(
        'assets/images/cyanzone_app_icon_foreground.png',
      ).readAsBytesSync(),
    )!;

    final upperColor = background.getPixel(
      background.width ~/ 2,
      8,
    );
    final lowerColor = background.getPixel(
      background.width ~/ 2,
      background.height - 8,
    );
    expect(
      upperColor.g.toInt() - lowerColor.g.toInt(),
      greaterThanOrEqualTo(95),
    );
    expect(lowerColor.g.toInt(), greaterThanOrEqualTo(100));
    expect(lowerColor.b.toInt(), greaterThanOrEqualTo(145));

    final bounds = _opaqueBounds(foreground);
    expect(bounds.width, inInclusiveRange(650, 690));
    expect(bounds.minimumMargin, greaterThanOrEqualTo(160));
  });

  test('native splash uses a prominent logo without a wordmark', () {
    final logo = img.decodePng(
      File(
        'android/app/src/main/res/drawable-xxxhdpi/'
        'cyanzone_splash_logo.png',
      ).readAsBytesSync(),
    )!;
    final logoBounds = _opaqueBounds(logo);

    expect(logoBounds.width, inInclusiveRange(580, 610));
    expect(logoBounds.minimumMargin, greaterThanOrEqualTo(190));
    expect(
      File(
        'android/app/src/main/res/drawable/cyanzone_splash_wordmark.xml',
      ).existsSync(),
      isFalse,
    );
  });
}

({int width, int height, int minimumMargin}) _opaqueBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y += 1) {
    for (var x = 0; x < image.width; x += 1) {
      if (image.getPixel(x, y).a.toInt() == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  return (
    width: maxX - minX + 1,
    height: maxY - minY + 1,
    minimumMargin: [
      minX,
      minY,
      image.width - 1 - maxX,
      image.height - 1 - maxY,
    ].reduce((left, right) => left < right ? left : right),
  );
}
