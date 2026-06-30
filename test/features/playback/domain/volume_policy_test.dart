import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/domain/volume_policy.dart';

void main() {
  group('effectiveVolume', () {
    test('multiplies master and mode volumes at zero decibels', () {
      expect(
        effectiveVolume(master: 0.8, modeVolume: 0.5, gainDb: 0),
        closeTo(0.4, 0.000001),
      );
    });

    test('clamps amplified volume to one', () {
      expect(effectiveVolume(master: 1, modeVolume: 1, gainDb: 6), 1);
    });
  });
}
