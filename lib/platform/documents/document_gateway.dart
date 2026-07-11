class PickedDocument {
  const PickedDocument({
    required this.uri,
    required this.displayName,
    this.mimeType,
    this.size,
  });

  final String uri;
  final String displayName;
  final String? mimeType;
  final int? size;

  @override
  bool operator ==(Object other) {
    return other is PickedDocument &&
        other.uri == uri &&
        other.displayName == displayName &&
        other.mimeType == mimeType &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(uri, displayName, mimeType, size);
}

class AudioProbeResult {
  const AudioProbeResult({required this.playable, this.artist, this.duration});

  final bool playable;
  final String? artist;
  final Duration? duration;

  @override
  bool operator ==(Object other) {
    return other is AudioProbeResult &&
        other.playable == playable &&
        other.artist == artist &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(playable, artist, duration);
}

abstract interface class DocumentGateway {
  Future<PickedDocument?> pickAudio();

  Future<String?> openEventJson();

  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  });

  Future<bool> canRead(String uri);

  Future<AudioProbeResult> probeAudio(String uri);
}

class DocumentGatewayException implements Exception {
  const DocumentGatewayException(this.code, this.message);

  final String code;
  final String? message;

  @override
  String toString() {
    final detail = message;
    return detail == null
        ? 'DocumentGatewayException($code)'
        : 'DocumentGatewayException($code): $detail';
  }
}
