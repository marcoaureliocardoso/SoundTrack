abstract interface class PlayerPort {
  Stream<Duration> get position;

  Stream<Duration?> get duration;

  Stream<void> get completed;

  Stream<Object> get errors;

  Future<void> load(Uri source);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setLooping(bool looping);

  Future<void> dispose();
}
