import 'dart:async';
import 'dart:io';

import 'package:cyanzone_mobile/src/bootstrap/cyanzone_startup_error_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initialization finishes before Flutter draws its first application',
      () {
    final source = File('lib/main.dart').readAsStringSync();
    final initialization = source.indexOf('await _initializeProductionApp()');
    final firstRunApp = source.indexOf('runApp(');

    expect(source, isNot(contains('CyanZoneBootstrap')));
    expect(initialization, greaterThanOrEqualTo(0));
    expect(firstRunApp, greaterThan(initialization));
    expect(
      File('lib/src/bootstrap/cyanzone_bootstrap.dart').existsSync(),
      isFalse,
    );
  });

  testWidgets('startup failure remains safe and retryable', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CyanZoneStartupErrorPage(
          onRetry: () async => retries += 1,
        ),
      ),
    );

    expect(find.text('CyanZone could not start.'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('startup retry stays single-flight while initialization runs',
      (tester) async {
    final retryCompleter = Completer<void>();
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CyanZoneStartupErrorPage(
          onRetry: () async {
            retries += 1;
            await retryCompleter.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    expect(retries, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    retryCompleter.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
