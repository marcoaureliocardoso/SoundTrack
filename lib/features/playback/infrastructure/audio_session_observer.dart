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
          (_) => unawaited(_dispatch(const PlaybackRouteChanged())),
          onError: _ignoreStreamError,
        ),
      )
      ..add(
        _backend.devicesChangedEventStream.listen(
          (_) => unawaited(_dispatch(const PlaybackRouteChanged())),
          onError: _ignoreStreamError,
        ),
      );
  }

  void _handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      unawaited(_dispatch(PlaybackInterruptionStarted(event.type)));
      return;
    }
    unawaited(_finishInterruption(event.type));
  }

  Future<void> _finishInterruption(AudioInterruptionType type) async {
    var focusGranted = false;
    try {
      focusGranted = await _backend.setActive(true);
    } on Object {
      // The coordinator receives a denied result and publishes a typed alert.
    }
    await _dispatch(
      PlaybackInterruptionEnded(type, focusGranted: focusGranted),
    );
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
    try {
      await _startFuture;
    } on Object {
      // Startup owns and reports configuration failures.
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
