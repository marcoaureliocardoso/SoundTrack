class PlayerPortError {
  const PlayerPortError(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final underlyingCause = cause;
    return underlyingCause == null
        ? 'PlayerPortError: $message'
        : 'PlayerPortError: $message (cause: $underlyingCause)';
  }
}

abstract interface class PlayerPort {
  Stream<Duration> get position;

  Stream<Duration?> get duration;

  Stream<void> get completed;

  Stream<PlayerPortError> get errors;

  Future<void> load(Uri source);

  void play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setLooping(bool looping);

  Future<void> dispose();
}
