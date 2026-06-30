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
        _emitAsyncError('Unable to observe playback state', error);
      },
    );
    _backendErrorSubscription = _backend.errorStream.listen(
      (error) => _emitAsyncError('Audio player failure', error),
      onError: (Object error, StackTrace stackTrace) {
        _emitAsyncError('Unable to observe audio player errors', error);
      },
    );
  }

  final JustAudioBackend _backend;
  final _completedController = StreamController<void>.broadcast();
  final _errorsController = StreamController<PlayerPortError>.broadcast();

  late final StreamSubscription<ProcessingState> _processingStateSubscription;
  late final StreamSubscription<PlayerException> _backendErrorSubscription;

  final _activeLoads = <_LoadOperation>{};
  final _recentAsyncErrors = <Object>{};
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
    _ensureActive();
    _cancelLoads('Audio load superseded by another load');
    final operation = _LoadOperation();
    _activeLoads.add(operation);
    final backendLoad = _backend
        .setAudioSource(AudioSource.uri(source))
        .then(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (!operation.canceled) {
              Error.throwWithStackTrace(
                _toPlayerPortError('Unable to load audio source', error),
                stackTrace,
              );
            }
          },
        );

    try {
      await Future.any([backendLoad, operation.cancellation.future]);
    } finally {
      _activeLoads.remove(operation);
    }
  }

  @override
  void play() {
    _ensureActive();
    unawaited(
      _backend.play().catchError((Object error, StackTrace stackTrace) {
        _emitAsyncError('Unable to play audio', error);
      }),
    );
  }

  @override
  Future<void> pause() => _run('Unable to pause audio', _backend.pause);

  @override
  Future<void> stop() async {
    _ensureActive();
    _cancelLoads('Audio load canceled by stop');
    await _run('Unable to stop audio', _backend.stop);
  }

  @override
  Future<void> seek(Duration position) =>
      _run('Unable to seek audio', () => _backend.seek(position));

  @override
  Future<void> setVolume(double volume) {
    return _run(
      'Unable to set audio volume',
      () => _backend.setVolume(volume.isFinite ? volume.clamp(0.0, 1.0) : 0.0),
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
    _cancelLoads('Audio player disposed during load');

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
    _ensureActive();
    try {
      await operation();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_toPlayerPortError(message, error), stackTrace);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw PlayerPortError(
        'Audio player is disposing or disposed',
        cause: StateError('Audio player is disposing or disposed'),
      );
    }
  }

  void _cancelLoads(String message) {
    for (final operation in _activeLoads.toList()) {
      operation.cancel(message);
    }
  }

  PlayerPortError _toPlayerPortError(String message, Object error) {
    return error is PlayerPortError
        ? error
        : PlayerPortError(message, cause: error);
  }

  void _emitAsyncError(String message, Object error) {
    if (_disposed) {
      return;
    }
    final key = _errorKey(error);
    if (!_recentAsyncErrors.add(key)) {
      return;
    }
    _errorsController.add(_toPlayerPortError(message, error));
    scheduleMicrotask(() {
      scheduleMicrotask(() => _recentAsyncErrors.remove(key));
    });
  }

  Object _errorKey(Object error) {
    if (error case PlayerException(
      code: final code,
      message: final message,
      index: final index,
    )) {
      return (PlayerException, code, message, index);
    }
    return error;
  }
}

final class _LoadOperation {
  final cancellation = Completer<void>();
  bool canceled = false;

  void cancel(String message) {
    if (canceled) {
      return;
    }
    canceled = true;
    cancellation.completeError(
      PlayerPortError(message, cause: PlayerInterruptedException(message)),
    );
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
