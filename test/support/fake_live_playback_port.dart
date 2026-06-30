import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

final class FakeLivePlaybackPort implements LivePlaybackPort {
  final snapshotNotifier = ValueNotifier<PlaybackSnapshot>(
    const PlaybackSnapshot.idle(),
  );
  final alertController = StreamController<PlaybackAlert>.broadcast();
  var disposeCalls = 0;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => snapshotNotifier;

  @override
  Stream<PlaybackAlert> get alerts => alertController.stream;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) async {}

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
  Future<void> dispose() async => disposeCalls++;
}
