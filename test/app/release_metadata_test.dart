import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development metadata uses next patch version and Android identity', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('version: 1.0.1+3'));
    expect(pubspec, isNot(contains('version: 1.0.0+2')));
    expect(
      pubspec,
      contains(
        'description: "Trilha sonora contínua e controlada para eventos."',
      ),
    );
    expect(gradle, contains('namespace = "br.com.marcocardoso.soundtrack"'));
    expect(
      gradle,
      contains('applicationId = "br.com.marcocardoso.soundtrack"'),
    );
    expect(manifest, contains('android:label="SoundTrack"'));
  });
}
