import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android application uses the CyanZone Firebase identity', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final gitignore = File('.gitignore').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/cyanzone/mobile/MainActivity.kt',
    );

    expect(gradle, contains('namespace = "com.cyanzone.mobile"'));
    expect(gradle, contains('applicationId = "com.cyanzone.mobile"'));
    expect(gradle, contains('id("com.google.gms.google-services")'));
    expect(
      gradle,
      contains('isCoreLibraryDesugaringEnabled = true'),
    );
    expect(
      gradle,
      contains('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:'),
    );
    expect(settings, contains('id("com.google.gms.google-services")'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(gitignore, contains('/android/app/google-services.json'));
    expect(activity.existsSync(), isTrue);
    expect(
        activity.readAsStringSync(), contains('package com.cyanzone.mobile'));
  });
}
