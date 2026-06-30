import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../events/domain/event_audio_settings.dart';
import '../domain/playback_alert.dart';
import '../domain/playback_snapshot.dart';
import '../domain/volume_policy.dart';
import 'fade_driver.dart';
import 'live_playback_port.dart';
import 'player_port.dart';

final class PlaybackCoordinator implements LivePlaybackPort {
  factory PlaybackCoordinator({
    required PlayerPort playerA,
    required PlayerPort playerB,
    required FadeDriver outgoingFade,
    required FadeDriver incomingFade,
    required EventAudioSettings presetVolumes,
  }) {
    return PlaybackCoordinator._(
      playerA,
      playerB,
      outgoingFade,
      incomingFade,
      presetVolumes,
    );
  }

  PlaybackCoordinator._(
    this._playerA,
    this._playerB,
    this._outgoingFade,
    this._incomingFade,
    this._presetVolumes,
  ) : _standby = _playerA,
      _volumes = _presetVolumes,
      _snapshot = ValueNotifier<PlaybackSnapshot>(
        PlaybackSnapshot(
          phase: PlaybackPhase.idle,
          playing: false,
          position: Duration.zero,
          duration: null,
          narrationActive: false,
          masterVolume: _presetVolumes.masterVolume,
          musicVolume: _presetVolumes.musicVolume,
          narrationVolume: _presetVolumes.narrationVolume,
        ),
      ) {
    _subscribe(_playerA);
    _subscribe(_playerB);
  }

  final PlayerPort _playerA;
  final PlayerPort _playerB;
  final FadeDriver _outgoingFade;
  final FadeDriver _incomingFade;
  final EventAudioSettings _presetVolumes;
  final ValueNotifier<PlaybackSnapshot> _snapshot;
  final _alerts = StreamController<PlaybackAlert>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _positions = <PlayerPort, Duration>{};
  final _durations = <PlayerPort, Duration?>{};
  final _standbyErrors = <int, PlayerPortError>{};

  EventAudioSettings _volumes;
  PlayerPort? _active;
  late PlayerPort _standby;
  MomentPlaybackRequest? _activeRequest;
  PlayerPort? _ownedStandby;
  int? _standbyOwnerGeneration;
  int? _standbyListeningGeneration;
  PlayerPort? _completingPlayer;
  Future<void> _commandTail = Future<void>.value();
  var _requestGeneration = 0;
  var _activeNarration = false;
  var _pendingStops = 0;
  var _disposed = false;
  Future<void>? _disposeFuture;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => _snapshot;

  @override
  Stream<PlaybackAlert> get alerts => _alerts.stream;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) {
    if (_disposed) {
      return Future<void>.value();
    }
    final target = _standby;
    final hadInFlightStandby = identical(_ownedStandby, target);
    if (_activeRequest?.momentId == request.momentId &&
        !hadInFlightStandby &&
        _pendingStops == 0) {
      return Future<void>.value();
    }
    final generation = ++_requestGeneration;
    _incomingFade.cancel();
    _outgoingFade.cancel();
    final releasePrevious = hadInFlightStandby
        ? _bestEffort(target.stop)
        : Future<void>.value();

    if (_activeRequest?.momentId == request.momentId && _pendingStops == 0) {
      _ownedStandby = target;
      _standbyOwnerGeneration = generation;
      _standbyListeningGeneration = null;
      return _enqueue(() async {
        await releasePrevious;
        await _cancelStandbyAndRestoreActive(target, generation);
      });
    }

    // Ownership moves synchronously, before stop releases an older load.
    _ownedStandby = target;
    _standbyOwnerGeneration = generation;
    _standbyListeningGeneration = null;
    return _enqueue(() async {
      await releasePrevious;
      await _startMoment(request, generation, target);
    });
  }

  Future<void> _startMoment(
    MomentPlaybackRequest request,
    int generation,
    PlayerPort target,
  ) async {
    if (!_ownsStandby(target, generation)) {
      return;
    }
    _standbyListeningGeneration = generation;
    final snapshotBeforeRequest = _snapshot.value;
    _positions[target] = Duration.zero;
    _durations[target] = null;
    _publish(phase: PlaybackPhase.loading, playing: _active != null);
    try {
      await target.setVolume(0);
      await target.load(request.uri);
      _throwStandbyError(generation);
      if (!_ownsStandby(target, generation)) {
        await _cleanUpOwnedTarget(target, generation);
        return;
      }
      await target.setLooping(request.loop);
      target.play();
      _throwStandbyError(generation);
      final targetVolume = _effectiveVolume(request);
      final oldActive = _active;
      final oldRequest = _activeRequest;
      if (oldActive == null || oldRequest == null) {
        await _incomingFade.run(
          from: 0,
          to: targetVolume,
          duration: request.fadeIn,
          apply: target.setVolume,
        );
      } else {
        final wasNarrating = _snapshot.value.narrationActive;
        final oldVolume = _effectiveVolume(oldRequest, narration: wasNarrating);
        _publish(
          phase: PlaybackPhase.transitioning,
          playing: true,
          narrationActive: false,
        );
        await Future.wait([
          _outgoingFade.run(
            from: oldVolume,
            to: 0,
            duration: oldRequest.fadeOut,
            apply: oldActive.setVolume,
          ),
          _incomingFade.run(
            from: 0,
            to: targetVolume,
            duration: request.fadeIn,
            apply: target.setVolume,
          ),
        ]);
      }
      _throwStandbyError(generation);
      if (!_ownsStandby(target, generation)) {
        await _cleanUpOwnedTarget(target, generation);
        return;
      }
      await oldActive?.stop();
      if (!_ownsStandby(target, generation)) {
        await _restoreActivePlayback();
        return;
      }
      _active = target;
      _activeRequest = request;
      _activeNarration = false;
      _standby = identical(target, _playerA) ? _playerB : _playerA;
      _standbyErrors.remove(generation);
      _releaseStandbyOwnership(target, generation);
      _publish(
        phase: PlaybackPhase.playing,
        playing: true,
        position: _positions[target] ?? Duration.zero,
        duration: _durations[target],
        clearDuration: _durations[target] == null,
        activeMomentId: request.momentId,
        narrationActive: false,
      );
    } on Object catch (error) {
      if (_disposed) {
        return;
      }
      if (!_ownsStandby(target, generation)) {
        return;
      }
      await _bestEffort(target.stop);
      if (_ownsStandby(target, generation)) {
        _releaseStandbyOwnership(target, generation);
        _publish(
          phase: snapshotBeforeRequest.phase,
          playing: snapshotBeforeRequest.playing,
          narrationActive: snapshotBeforeRequest.narrationActive,
        );
        await _bestEffort(_restoreActiveVolume);
        final standbyError = _standbyErrors.remove(generation);
        _emitAlert(
          PlaybackAlert(
            PlaybackAlertCode.sourceFailed,
            standbyError?.message ??
                'Não foi possível reproduzir ${request.audioDisplayName}: $error',
            momentId: request.momentId,
          ),
        );
      }
    }
  }

  @override
  Future<void> pause() => _enqueueIfAlive(() async {
    final active = _active;
    if (_disposed || active == null) {
      return;
    }
    await active.pause();
    _publish(phase: PlaybackPhase.paused, playing: false);
  });

  @override
  Future<void> resume() => _enqueueIfAlive(() async {
    final active = _active;
    if (_disposed || active == null) {
      return;
    }
    active.play();
    _publish(phase: PlaybackPhase.playing, playing: true);
  });

  @override
  Future<void> stop() {
    if (_disposed) {
      return Future<void>.value();
    }
    _requestGeneration++;
    _incomingFade.cancel();
    _outgoingFade.cancel();
    final ownedStandby = _ownedStandby;
    _releaseStandbyOwnership();
    final releaseStandby = ownedStandby == null
        ? Future<void>.value()
        : _bestEffort(ownedStandby.stop);
    _pendingStops++;
    return _enqueue(() async {
      try {
        await releaseStandby;
        if (_disposed) {
          return;
        }
        await _active?.stop();
      } finally {
        if (!_disposed) {
          _active = null;
          _activeRequest = null;
          _activeNarration = false;
          _publish(
            phase: PlaybackPhase.stopped,
            playing: false,
            position: Duration.zero,
            clearDuration: true,
            clearActiveMoment: true,
            narrationActive: false,
          );
        }
        _pendingStops--;
      }
    });
  }

  @override
  Future<void> setNarration(bool active) => _enqueueIfAlive(() async {
    if (_disposed) {
      return;
    }
    final request = _activeRequest;
    final player = _active;
    if (request == null || player == null || !request.narrationEnabled) {
      return;
    }
    await player.setVolume(_effectiveVolume(request, narration: active));
    _activeNarration = active;
    _publish(narrationActive: active);
  });

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) => _enqueueIfAlive(() async {
    if (_disposed) {
      return;
    }
    _volumes = _volumes.copyWith(
      masterVolume: masterVolume,
      musicVolume: musicVolume,
      narrationVolume: narrationVolume,
    );
    await _applyActiveVolume();
    _publish(
      masterVolume: _volumes.masterVolume,
      musicVolume: _volumes.musicVolume,
      narrationVolume: _volumes.narrationVolume,
    );
  });

  @override
  Future<void> restorePresetVolumes() => setSessionVolumes(
    masterVolume: _presetVolumes.masterVolume,
    musicVolume: _presetVolumes.musicVolume,
    narrationVolume: _presetVolumes.narrationVolume,
  );

  double _effectiveVolume(
    MomentPlaybackRequest request, {
    bool narration = false,
  }) {
    return effectiveVolume(
      master: _volumes.masterVolume,
      modeVolume: narration ? _volumes.narrationVolume : _volumes.musicVolume,
      gainDb: request.gainDb,
    );
  }

  Future<void> _applyActiveVolume() async {
    final request = _activeRequest;
    final player = _active;
    if (request == null || player == null) {
      return;
    }
    await player.setVolume(
      _effectiveVolume(request, narration: _activeNarration),
    );
  }

  Future<void> _restoreActiveVolume() async {
    if (_disposed) {
      return;
    }
    await _applyActiveVolume();
  }

  Future<void> _restoreActivePlayback() async {
    if (_disposed || _active == null) {
      return;
    }
    await _bestEffort(_restoreActiveVolume);
    _active!.play();
  }

  Future<void> _cancelStandbyAndRestoreActive(
    PlayerPort target,
    int generation,
  ) async {
    if (!_ownsStandby(target, generation)) {
      return;
    }
    _releaseStandbyOwnership(target, generation);
    await _restoreActivePlayback();
    _publish(
      phase: PlaybackPhase.playing,
      playing: true,
      narrationActive: _activeNarration,
    );
  }

  Future<void> _cleanUpOwnedTarget(PlayerPort target, int generation) async {
    if (!_ownsStandby(target, generation)) {
      return;
    }
    await _bestEffort(target.stop);
    if (_ownsStandby(target, generation)) {
      _releaseStandbyOwnership(target, generation);
      await _bestEffort(_restoreActiveVolume);
    }
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      // The original playback failure remains the actionable alert.
    }
  }

  Future<void> _enqueue(Future<void> Function() command) {
    final result = _commandTail.then((_) => command());
    _commandTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _enqueueIfAlive(Future<void> Function() command) {
    return _disposed ? Future<void>.value() : _enqueue(command);
  }

  void _throwStandbyError(int generation) {
    final error = _standbyErrors[generation];
    if (error != null) {
      throw error;
    }
  }

  void _subscribe(PlayerPort player) {
    _subscriptions
      ..add(
        player.position.listen((position) {
          _positions[player] = position;
          if (identical(player, _active)) {
            _publish(position: position);
          }
        }),
      )
      ..add(
        player.duration.listen((duration) {
          _durations[player] = duration;
          if (identical(player, _active)) {
            _publish(duration: duration, clearDuration: duration == null);
          }
        }),
      )
      ..add(
        player.completed.listen((_) {
          unawaited(_enqueue(() => _handleCompletion(player)));
        }),
      )
      ..add(
        player.errors.listen((error) {
          final generation = _standbyOwnerGeneration;
          if (generation != null &&
              _standbyListeningGeneration == generation &&
              identical(player, _ownedStandby)) {
            _standbyErrors[generation] = error;
            _incomingFade.cancel();
            _outgoingFade.cancel();
            unawaited(_bestEffort(player.stop));
            return;
          }
          if (identical(player, _active)) {
            _emitAlert(
              PlaybackAlert(
                PlaybackAlertCode.sourceFailed,
                error.message,
                momentId: _activeRequest?.momentId,
              ),
            );
          }
        }),
      );
  }

  Future<void> _handleCompletion(PlayerPort player) async {
    final request = _activeRequest;
    if (_disposed ||
        request == null ||
        request.loop ||
        !identical(player, _active) ||
        identical(_completingPlayer, player)) {
      return;
    }
    final generation = _requestGeneration;
    _completingPlayer = player;
    try {
      try {
        await _outgoingFade.run(
          from: _effectiveVolume(request, narration: _activeNarration),
          to: 0,
          duration: request.fadeOut,
          apply: player.setVolume,
        );
      } on Object {
        if (_isActiveGeneration(player, request, generation)) {
          _emitAlert(
            PlaybackAlert(
              PlaybackAlertCode.sourceFailed,
              'Não foi possível finalizar ${request.audioDisplayName}.',
              momentId: request.momentId,
            ),
          );
        }
      }
      if (!_isActiveGeneration(player, request, generation)) {
        return;
      }
      try {
        await player.stop();
      } on Object catch (error) {
        if (_isActiveGeneration(player, request, generation)) {
          _emitAlert(
            PlaybackAlert(
              PlaybackAlertCode.sourceFailed,
              'Não foi possível parar ${request.audioDisplayName}: $error',
              momentId: request.momentId,
            ),
          );
        }
      }
      if (!_isActiveGeneration(player, request, generation)) {
        return;
      }
      _active = null;
      _activeRequest = null;
      _activeNarration = false;
      _publish(
        phase: PlaybackPhase.stopped,
        playing: false,
        position: Duration.zero,
        clearDuration: true,
        clearActiveMoment: true,
        narrationActive: false,
      );
    } on Object catch (error) {
      if (_isActiveGeneration(player, request, generation)) {
        _emitAlert(
          PlaybackAlert(
            PlaybackAlertCode.sourceFailed,
            error.toString(),
            momentId: request.momentId,
          ),
        );
      }
    } finally {
      if (identical(_completingPlayer, player)) {
        _completingPlayer = null;
      }
    }
  }

  bool _isActiveGeneration(
    PlayerPort player,
    MomentPlaybackRequest request,
    int generation,
  ) {
    return _isCurrent(generation) &&
        identical(player, _active) &&
        identical(request, _activeRequest);
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _requestGeneration;

  bool _ownsStandby(PlayerPort target, int generation) {
    return _isCurrent(generation) &&
        identical(_ownedStandby, target) &&
        _standbyOwnerGeneration == generation;
  }

  void _releaseStandbyOwnership([PlayerPort? target, int? generation]) {
    if (target != null && !identical(_ownedStandby, target)) {
      return;
    }
    if (generation != null && _standbyOwnerGeneration != generation) {
      return;
    }
    _ownedStandby = null;
    _standbyOwnerGeneration = null;
    _standbyListeningGeneration = null;
  }

  void _emitAlert(PlaybackAlert alert) {
    if (!_disposed) {
      _alerts.add(alert);
    }
  }

  void _publish({
    PlaybackPhase? phase,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    bool? narrationActive,
    double? masterVolume,
    double? musicVolume,
    double? narrationVolume,
    String? activeMomentId,
    bool clearActiveMoment = false,
  }) {
    if (_disposed) {
      return;
    }
    _snapshot.value = _snapshot.value.copyWith(
      phase: phase,
      playing: playing,
      position: position,
      duration: duration,
      clearDuration: clearDuration,
      narrationActive: narrationActive,
      masterVolume: masterVolume,
      musicVolume: musicVolume,
      narrationVolume: narrationVolume,
      activeMomentId: activeMomentId,
      clearActiveMoment: clearActiveMoment,
    );
  }

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }
    final disposal = _dispose();
    _disposeFuture = disposal;
    return disposal;
  }

  Future<void> _dispose() async {
    _disposed = true;
    _requestGeneration++;
    _incomingFade.cancel();
    _outgoingFade.cancel();
    final ownedStandby = _ownedStandby;
    _releaseStandbyOwnership();
    if (ownedStandby != null) {
      await _bestEffort(ownedStandby.stop);
    }
    await _drainCommandQueue();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _drainCommandQueue();
    await Future.wait([_playerA.dispose(), _playerB.dispose()]);
    await _alerts.close();
    _snapshot.dispose();
  }

  Future<void> _drainCommandQueue() async {
    while (true) {
      final tail = _commandTail;
      await tail;
      if (identical(tail, _commandTail)) {
        return;
      }
    }
  }
}
