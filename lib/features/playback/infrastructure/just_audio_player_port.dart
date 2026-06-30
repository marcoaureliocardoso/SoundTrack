import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../application/player_port.dart';

abstract interface class JustAudioBackend {
  Stream<Duration> get positionStream;

  Stream<Duration?> get durationStream;

  Stream<ProcessingState> get processingStateStream;

  Stream<PlayerException> get errorStream;

  Future<Duration?> setAudioSource(AudioSource source);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setLoopMode(LoopMode mode);

  Future<void> dispose();
}

final class JustAudioPlayerPort implements PlayerPort {
  JustAudioPlayerPort({JustAudioBackend? backend})
    : _backend = backend ?? _createProductionBackend() {
    _processingStateSubscription = _backend.processingStateStream.listen(
      (state) {
        if (state == ProcessingState.completed && !_disposed) {
          _completedController.add(null);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _emitError('Unable to observe playback state', error);
      },
    );
    _backendErrorSubscription = _backend.errorStream.listen(
      (error) => _emitError('Audio player failure', error),
      onError: (Object error, StackTrace stackTrace) {
        _emitError('Unable to observe audio player errors', error);
      },
    );
  }

  final JustAudioBackend _backend;
  final _completedController = StreamController<void>.broadcast();
  final _errorsController = StreamController<PlayerPortError>.broadcast();

  late final StreamSubscription<ProcessingState> _processingStateSubscription;
  late final StreamSubscription<PlayerException> _backendErrorSubscription;

  Completer<void>? _loadCancellation;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  static JustAudioBackend _createProductionBackend() {
    return _AudioPlayerBackend(
      AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: true,
        androidAudioOffloadPreferences: const AndroidAudioOffloadPreferences(
          audioOffloadMode: AndroidAudioOffloadMode.disabled,
        ),
      ),
    );
  }

  @override
  Stream<Duration> get position => _backend.positionStream;

  @override
  Stream<Duration?> get duration => _backend.durationStream;

  @override
  Stream<void> get completed => _completedController.stream;

  @override
  Stream<PlayerPortError> get errors => _errorsController.stream;

  @override
  Future<void> load(Uri source) async {
    final cancellation = Completer<void>();
    _loadCancellation = cancellation;
    final backendLoad = _backend
        .setAudioSource(AudioSource.uri(source))
        .then(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (!cancellation.isCompleted) {
              throw _emitError('Unable to load audio source', error);
            }
          },
        );

    try {
      await Future.any([backendLoad, cancellation.future]);
    } finally {
      if (identical(_loadCancellation, cancellation)) {
        _loadCancellation = null;
      }
    }
  }

  @override
  void play() {
    unawaited(
      _backend.play().catchError((Object error, StackTrace stackTrace) {
        _emitError('Unable to play audio', error);
      }),
    );
  }

  @override
  Future<void> pause() => _run('Unable to pause audio', _backend.pause);

  @override
  Future<void> stop() async {
    final cancellation = _loadCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.completeError(
        _emitError(
          'Audio load canceled by stop',
          StateError('Audio load canceled by stop'),
        ),
      );
    }
    await _run('Unable to stop audio', _backend.stop);
  }

  @override
  Future<void> seek(Duration position) =>
      _run('Unable to seek audio', () => _backend.seek(position));

  @override
  Future<void> setVolume(double volume) {
    return _run(
      'Unable to set audio volume',
      () => _backend.setVolume(volume.clamp(0.0, 1.0)),
    );
  }

  @override
  Future<void> setLooping(bool looping) {
    return _run(
      'Unable to set audio loop mode',
      () => _backend.setLoopMode(looping ? LoopMode.one : LoopMode.off),
    );
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final cancellation = _loadCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.completeError(
        const PlayerPortError('Audio player disposed during load'),
      );
    }

    Object? disposeError;
    StackTrace? disposeStackTrace;
    try {
      await Future.wait([
        _processingStateSubscription.cancel(),
        _backendErrorSubscription.cancel(),
      ]);
      await _backend.dispose();
    } catch (error, stackTrace) {
      disposeError = error;
      disposeStackTrace = stackTrace;
    } finally {
      await Future.wait([
        _completedController.close(),
        _errorsController.close(),
      ]);
    }
    if (disposeError != null) {
      Error.throwWithStackTrace(
        PlayerPortError('Unable to dispose audio player', cause: disposeError),
        disposeStackTrace!,
      );
    }
  }

  Future<void> _run(String message, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_emitError(message, error), stackTrace);
    }
  }

  PlayerPortError _emitError(String message, Object error) {
    final typedError = error is PlayerPortError
        ? error
        : PlayerPortError(message, cause: error);
    if (!_disposed) {
      _errorsController.add(typedError);
    }
    return typedError;
  }
}

final class _AudioPlayerBackend implements JustAudioBackend {
  const _AudioPlayerBackend(this._player);

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  @override
  Stream<PlayerException> get errorStream => _player.errorStream;

  @override
  Future<Duration?> setAudioSource(AudioSource source) =>
      _player.setAudioSource(source);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setLoopMode(LoopMode mode) => _player.setLoopMode(mode);

  @override
  Future<void> dispose() => _player.dispose();
}
