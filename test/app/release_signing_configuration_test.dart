import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release signing never falls back to the debug key', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final ignore = File('android/.gitignore').readAsStringSync();

    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('validateReleaseSigning'));
    expect(gradle, contains('Release signing is not configured'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('**/*.jks'));
  });
}
