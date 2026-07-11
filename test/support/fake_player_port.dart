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
  final _activeControlledLoads = <Completer<void>>{};
  final _controlledPauses = <Completer<void>>[];
  final _controlledVolumes = <Completer<void>>[];

  Completer<void>? controlledLoad;
  Completer<void>? controlledStop;
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

  Completer<void> holdNextPause() {
    final completer = Completer<void>();
    _controlledPauses.add(completer);
    return completer;
  }

  Completer<void> holdNextVolume() {
    final completer = Completer<void>();
    _controlledVolumes.add(completer);
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
    if (controlled == null) {
      return;
    }
    _activeControlledLoads.add(controlled);
    try {
      await controlled.future;
    } finally {
      _activeControlledLoads.remove(controlled);
    }
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
    if (_controlledPauses.isNotEmpty) {
      await _controlledPauses.removeAt(0).future;
    }
  }

  @override
  Future<void> stop() async {
    operations.add('stop');
    playing = false;
    for (final load in _activeControlledLoads.toList()) {
      if (!load.isCompleted) {
        load.completeError(StateError('load canceled by stop'));
      }
    }
    await controlledStop?.future;
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
    if (_controlledVolumes.isNotEmpty) {
      await _controlledVolumes.removeAt(0).future;
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
