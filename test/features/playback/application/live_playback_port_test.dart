import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  test('startMoment accepts an immutable playback request', () async {
    final port = _FakeLivePlaybackPort();
    final request = MomentPlaybackRequest(
      momentId: 'moment-1',
      uri: Uri.parse('file:///music.mp3'),
      loop: true,
      narrationEnabled: true,
      gainDb: -3,
      fadeIn: const Duration(seconds: 1),
      fadeOut: const Duration(seconds: 2),
    );

    await port.startMoment(request);

    expect(port.request, same(request));
    expect(request.momentId, 'moment-1');
    expect(request.uri, Uri.parse('file:///music.mp3'));
    expect(request.loop, isTrue);
    expect(request.narrationEnabled, isTrue);
    expect(request.gainDb, -3);
    expect(request.fadeIn, const Duration(seconds: 1));
    expect(request.fadeOut, const Duration(seconds: 2));
  });
}

final class _FakeLivePlaybackPort implements LivePlaybackPort {
  @override
  final ValueNotifier<PlaybackSnapshot> snapshot = ValueNotifier(
    const PlaybackSnapshot.idle(),
  );

  @override
  final Stream<PlaybackAlert> alerts = const Stream.empty();

  MomentPlaybackRequest? request;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) async {
    this.request = request;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setNarration(bool active) async {}

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) async {}

  @override
  Future<void> restorePresetVolumes() async {}

  @override
  Future<void> dispose() async {
    snapshot.dispose();
  }
}
