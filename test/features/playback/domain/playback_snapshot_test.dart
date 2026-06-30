import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  test('idle snapshot has no active playback or narration', () {
    final snapshot = PlaybackSnapshot.idle();

    expect(snapshot.activeMomentId, isNull);
    expect(snapshot.position, Duration.zero);
    expect(snapshot.playing, isFalse);
    expect(snapshot.narrationActive, isFalse);
  });
}
