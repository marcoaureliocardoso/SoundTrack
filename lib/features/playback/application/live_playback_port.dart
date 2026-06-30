import 'package:flutter/foundation.dart';

import '../domain/playback_alert.dart';
import '../domain/playback_snapshot.dart';

class MomentPlaybackRequest {
  const MomentPlaybackRequest({
    required this.momentId,
    required this.momentName,
    required this.uri,
    required this.audioDisplayName,
    required this.loop,
    required this.narrationEnabled,
    required this.gainDb,
    required this.fadeIn,
    required this.fadeOut,
  });

  final String momentId;
  final String momentName;
  final Uri uri;
  final String audioDisplayName;
  final bool loop;
  final bool narrationEnabled;
  final double gainDb;
  final Duration fadeIn;
  final Duration fadeOut;
}

abstract interface class LivePlaybackPort {
  ValueListenable<PlaybackSnapshot> get snapshot;

  Stream<PlaybackAlert> get alerts;

  Future<void> startMoment(MomentPlaybackRequest request);

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
