class EventAudioSettings {
  const EventAudioSettings({
    required this.masterVolume,
    required this.musicVolume,
    required this.narrationVolume,
    required this.fadeIn,
    required this.fadeOut,
  });

  const EventAudioSettings.defaults()
    : masterVolume = 0.80,
      musicVolume = 1.0,
      narrationVolume = 0.25,
      fadeIn = const Duration(seconds: 2),
      fadeOut = const Duration(seconds: 2);

  final double masterVolume;
  final double musicVolume;
  final double narrationVolume;
  final Duration fadeIn;
  final Duration fadeOut;

  factory EventAudioSettings.fromJson(Map<String, Object?> json) {
    return EventAudioSettings(
      masterVolume: (json['masterVolume'] as num).toDouble(),
      musicVolume: (json['musicVolume'] as num).toDouble(),
      narrationVolume: (json['narrationVolume'] as num).toDouble(),
      fadeIn: Duration(milliseconds: json['fadeInMs'] as int),
      fadeOut: Duration(milliseconds: json['fadeOutMs'] as int),
    );
  }

  Map<String, Object> toJson() {
    return {
      'masterVolume': masterVolume,
      'musicVolume': musicVolume,
      'narrationVolume': narrationVolume,
      'fadeInMs': fadeIn.inMilliseconds,
      'fadeOutMs': fadeOut.inMilliseconds,
    };
  }

  EventAudioSettings copyWith({
    double? masterVolume,
    double? musicVolume,
    double? narrationVolume,
    Duration? fadeIn,
    Duration? fadeOut,
  }) {
    return EventAudioSettings(
      masterVolume: (masterVolume ?? this.masterVolume).clamp(0.0, 1.0),
      musicVolume: (musicVolume ?? this.musicVolume).clamp(0.0, 1.0),
      narrationVolume: (narrationVolume ?? this.narrationVolume).clamp(
        0.0,
        1.0,
      ),
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EventAudioSettings &&
            masterVolume == other.masterVolume &&
            musicVolume == other.musicVolume &&
            narrationVolume == other.narrationVolume &&
            fadeIn == other.fadeIn &&
            fadeOut == other.fadeOut;
  }

  @override
  int get hashCode =>
      Object.hash(masterVolume, musicVolume, narrationVolume, fadeIn, fadeOut);
}
