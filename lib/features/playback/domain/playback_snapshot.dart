enum PlaybackPhase { idle, loading, playing, paused, transitioning, stopped }

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.phase,
    required this.playing,
    required this.position,
    required this.duration,
    required this.narrationActive,
    required this.masterVolume,
    required this.musicVolume,
    required this.narrationVolume,
    this.activeMomentId,
  });

  const PlaybackSnapshot.idle()
    : phase = PlaybackPhase.idle,
      playing = false,
      position = Duration.zero,
      duration = null,
      narrationActive = false,
      masterVolume = 0.8,
      musicVolume = 1,
      narrationVolume = 0.25,
      activeMomentId = null;

  final PlaybackPhase phase;
  final bool playing;
  final Duration position;
  final Duration? duration;
  final bool narrationActive;
  final double masterVolume;
  final double musicVolume;
  final double narrationVolume;
  final String? activeMomentId;

  PlaybackSnapshot copyWith({
    PlaybackPhase? phase,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? narrationActive,
    double? masterVolume,
    double? musicVolume,
    double? narrationVolume,
    String? activeMomentId,
    bool clearActiveMoment = false,
  }) {
    return PlaybackSnapshot(
      phase: phase ?? this.phase,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      narrationActive: narrationActive ?? this.narrationActive,
      masterVolume: masterVolume ?? this.masterVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      narrationVolume: narrationVolume ?? this.narrationVolume,
      activeMomentId: clearActiveMoment
          ? null
          : activeMomentId ?? this.activeMomentId,
    );
  }
}
