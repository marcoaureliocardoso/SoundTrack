import 'dart:async';

import 'package:soundtrack/features/playback/application/player_port.dart';

final class FakePlayerPort implements PlayerPort {
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration?>.broadcast();
  final completedController = StreamController<void>.broadcast();
  final errorController = StreamController<PlayerPortError>.broadcast();
  final operations = <String>[];
  final volumes = <double>[];
  final loadedSources = <Uri>[];
  final _controlledLoads = <Completer<void>>[];

  Completer<void>? controlledLoad;
  Object? loadError;
  Object? nextVolumeError;
  Object? nextStopError;
  bool playing = false;
  bool looping = false;
  Duration lastSeek = Duration.zero;
  int disposeCalls = 0;

  Completer<void> holdNextLoad() {
    final completer = Completer<void>();
    _controlledLoads.add(completer);
    return completer;
  }

  @override
  Stream<Duration> get position => positionController.stream;

  @override
  Stream<Duration?> get duration => durationController.stream;

  @override
  Stream<void> get completed => completedController.stream;

  @override
  Stream<PlayerPortError> get errors => errorController.stream;

  @override
  Future<void> load(Uri source) async {
    operations.add('load:$source');
    loadedSources.add(source);
    final error = loadError;
    if (error != null) {
      throw error;
    }
    final controlled = _controlledLoads.isEmpty
        ? controlledLoad
        : _controlledLoads.removeAt(0);
    await controlled?.future;
  }

  @override
  void play() {
    operations.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    operations.add('pause');
    playing = false;
  }

  @override
  Future<void> stop() async {
    operations.add('stop');
    playing = false;
    final error = nextStopError;
    nextStopError = null;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    operations.add('seek:${position.inMilliseconds}');
    lastSeek = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    operations.add('volume:$volume');
    volumes.add(volume);
    final error = nextVolumeError;
    nextVolumeError = null;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> setLooping(bool looping) async {
    operations.add('loop:$looping');
    this.looping = looping;
  }

  @override
  Future<void> dispose() async {
    operations.add('dispose');
    disposeCalls++;
    await Future.wait([
      positionController.close(),
      durationController.close(),
      completedController.close(),
      errorController.close(),
    ]);
  }
}
