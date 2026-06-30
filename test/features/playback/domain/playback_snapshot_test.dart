import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  test('idle snapshot has no active moment and zero position', () {
    const snapshot = PlaybackSnapshot.idle();

    expect(snapshot.activeMomentId, isNull);
    expect(snapshot.position, Duration.zero);
    expect(snapshot.playing, isFalse);
    expect(snapshot.narrationActive, isFalse);
  });

  test('direct snapshot does not require an active moment', () {
    const snapshot = PlaybackSnapshot(
      phase: PlaybackPhase.idle,
      playing: false,
      position: Duration.zero,
      duration: null,
      narrationActive: false,
      masterVolume: 0.8,
      musicVolume: 1,
      narrationVolume: 0.25,
    );

    expect(snapshot.activeMomentId, isNull);
  });
}
