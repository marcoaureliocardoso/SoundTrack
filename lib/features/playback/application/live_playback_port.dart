import 'package:flutter/foundation.dart';

import '../../events/domain/event_moment.dart';
import '../domain/playback_alert.dart';
import '../domain/playback_snapshot.dart';

abstract interface class LivePlaybackPort {
  ValueListenable<PlaybackSnapshot> get snapshot;

  Stream<PlaybackAlert> get alerts;

  Future<void> startMoment(EventMoment moment);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> setNarration(bool active);

  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  });

  Future<void> restorePresetVolumes();

  Future<void> dispose();
}
