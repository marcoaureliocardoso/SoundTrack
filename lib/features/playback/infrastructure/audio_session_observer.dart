import 'dart:async';

import 'package:audio_session/audio_session.dart';

import '../application/playback_coordinator.dart';

abstract interface class AudioSessionBackend {
  Stream<AudioInterruptionEvent> get interruptionEventStream;
  Stream<void> get becomingNoisyEventStream;
  Stream<AudioDevicesChangedEvent> get devicesChangedEventStream;

  Future<void> configure(AudioSessionConfiguration configuration);
  Future<bool> setActive(bool active);
}

final class PlatformAudioSessionBackend implements AudioSessionBackend {
  PlatformAudioSessionBackend(this._session);

  final AudioSession _session;

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _session.interruptionEventStream;

  @override
  Stream<void> get becomingNoisyEventStream =>
      _session.becomingNoisyEventStream;

  @override
  Stream<AudioDevicesChangedEvent> get devicesChangedEventStream =>
      _session.devicesChangedEventStream;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) =>
      _session.configure(configuration);

  @override
  Future<bool> setActive(bool active) => _session.setActive(active);
}

final class AudioSessionObserver {
  AudioSessionObserver(this._backend, this._onEvent);

  static Future<AudioSessionObserver> platform({
    required Future<void> Function(PlaybackSessionEvent event) onEvent,
  }) async {
    final session = await AudioSession.instance;
    return AudioSessionObserver(PlatformAudioSessionBackend(session), onEvent);
  }

  final AudioSessionBackend _backend;
  final Future<void> Function(PlaybackSessionEvent event) _onEvent;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Future<void>? _startFuture;
  Future<void>? _disposeFuture;
  Future<void> _eventTail = Future<void>.value();
  var _disposed = false;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    if (_disposed) {
      return;
    }
    await _backend.configure(
      const AudioSessionConfiguration.music().copyWith(
        androidWillPauseWhenDucked: false,
      ),
    );
    if (_disposed) {
      return;
    }
    _subscriptions
      ..add(
        _backend.interruptionEventStream.listen(
          _handleInterruption,
          onError: _ignoreStreamError,
        ),
      )
      ..add(
        _backend.becomingNoisyEventStream.listen(
          (_) => _queueEvent(const PlaybackRouteChanged()),
          onError: _ignoreStreamError,
        ),
      )
      ..add(
        _backend.devicesChangedEventStream.listen(
          (_) => _queueEvent(const PlaybackRouteChanged()),
          onError: _ignoreStreamError,
        ),
      );
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      _queueEvent(PlaybackInterruptionStarted(event.type));
      return;
    }
    _queueEvent(
      PlaybackInterruptionEnded(
        event.type,
        requestFocus: () => _backend.setActive(true),
      ),
    );
  }

  void _queueEvent(PlaybackSessionEvent event) {
    if (_disposed) {
      return;
    }
    _eventTail = _eventTail.then((_) => _dispatch(event));
  }

  Future<void> _dispatch(PlaybackSessionEvent event) async {
    if (_disposed) {
      return;
    }
    try {
      await _onEvent(event);
    } on Object {
      // Platform streams must not produce unhandled asynchronous errors.
    }
  }

  void _ignoreStreamError(Object _, StackTrace _) {}

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _startFuture;
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    for (final subscription in _subscriptions) {
      try {
        await subscription.cancel();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    _subscriptions.clear();
    try {
      await _eventTail;
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
