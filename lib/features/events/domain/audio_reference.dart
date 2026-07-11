class AudioReference {
  const AudioReference({
    required this.uri,
    required this.displayName,
    required this.pending,
    required this.artist,
    required this.duration,
  }) : assert(pending || (uri != null && uri != ''));

  final String? uri;
  final String displayName;
  final bool pending;
  final String? artist;
  final Duration? duration;

  factory AudioReference.fromJson(
    Map<String, Object?> json, {
    bool imported = false,
  }) {
    final uri = json['uri'] as String?;
    final durationMs = json['durationMs'] as int?;

    return AudioReference(
      uri: uri,
      displayName: json['displayName'] as String,
      pending: imported || uri == null || uri.isEmpty,
      artist: json['artist'] as String?,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'uri': uri,
      'displayName': displayName,
      'artist': artist,
      'durationMs': duration?.inMilliseconds,
      'portable': false,
    };
  }

  AudioReference relink({
    required String uri,
    required String displayName,
    String? artist,
    Duration? duration,
  }) {
    if (uri.isEmpty) {
      throw ArgumentError.value(uri, 'uri', 'must not be empty');
    }

    return AudioReference(
      uri: uri,
      displayName: displayName,
      pending: false,
      artist: artist,
      duration: duration,
    );
  }

  AudioReference markPending() {
    if (pending) {
      return this;
    }

    return AudioReference(
      uri: uri,
      displayName: displayName,
      pending: true,
      artist: artist,
      duration: duration,
    );
  }
}
