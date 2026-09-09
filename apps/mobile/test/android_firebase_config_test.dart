import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android application uses the CyanZone Firebase identity', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/cyanzone/mobile/MainActivity.kt',
    );

    expect(gradle, contains('namespace = "com.cyanzone.mobile"'));
    expect(gradle, contains('applicationId = "com.cyanzone.mobile"'));
    expect(activity.existsSync(), isTrue);
    expect(activity.readAsStringSync(), contains('package com.cyanzone.mobile'));
  });
}
