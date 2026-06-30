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

  EventAudioSettings _volumes;
  PlayerPort? _active;
  late PlayerPort _standby;
  MomentPlaybackRequest? _activeRequest;
  Future<void> _requestTail = Future<void>.value();
  var _requestGeneration = 0;
  var _disposed = false;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => _snapshot;

  @override
  Stream<PlaybackAlert> get alerts => _alerts.stream;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) {
    if (_disposed || _activeRequest?.momentId == request.momentId) {
      return Future<void>.value();
    }
    final generation = ++_requestGeneration;
    _incomingFade.cancel();
    _outgoingFade.cancel();
    final operation = _requestTail.then(
      (_) => _startMoment(request, generation),
    );
    _requestTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _startMoment(
    MomentPlaybackRequest request,
    int generation,
  ) async {
    if (!_isCurrent(generation)) {
      return;
    }
    final snapshotBeforeRequest = _snapshot.value;
    final target = _standby;
    _positions[target] = Duration.zero;
    _durations[target] = null;
    _publish(phase: PlaybackPhase.loading, playing: _active != null);
    try {
      await target.setVolume(0);
      await target.load(request.uri);
      if (!_isCurrent(generation)) {
        await _cleanUpStaleTarget(target);
        return;
      }
      await target.setLooping(request.loop);
      target.play();
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
      if (!_isCurrent(generation)) {
        await _cleanUpStaleTarget(target);
        return;
      }
      await oldActive?.stop();
      _active = target;
      _activeRequest = request;
      _standby = identical(target, _playerA) ? _playerB : _playerA;
      _publish(
        phase: PlaybackPhase.playing,
        playing: true,
        position: _positions[target] ?? Duration.zero,
        duration: _durations[target],
        clearDuration: _durations[target] == null,
        activeMomentId: request.momentId,
        narrationActive: false,
      );
    } on Object catch (_) {
      if (_disposed) {
        return;
      }
      await _bestEffort(target.stop);
      if (_isCurrent(generation)) {
        _publish(
          phase: snapshotBeforeRequest.phase,
          playing: snapshotBeforeRequest.playing,
          narrationActive: snapshotBeforeRequest.narrationActive,
        );
        await _bestEffort(_restoreActiveVolume);
        _emitAlert(
          PlaybackAlert(
            PlaybackAlertCode.sourceFailed,
            'Não foi possível reproduzir ${request.audioDisplayName}.',
            momentId: request.momentId,
          ),
        );
      }
    }
  }

  @override
  Future<void> pause() async {
    final active = _active;
    if (_disposed || active == null) {
      return;
    }
    await active.pause();
    _publish(phase: PlaybackPhase.paused, playing: false);
  }

  @override
  Future<void> resume() async {
    final active = _active;
    if (_disposed || active == null) {
      return;
    }
    active.play();
    _publish(phase: PlaybackPhase.playing, playing: true);
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _requestGeneration++;
    _incomingFade.cancel();
    _outgoingFade.cancel();
    await _active?.stop();
    _active = null;
    _activeRequest = null;
    _publish(
      phase: PlaybackPhase.stopped,
      playing: false,
      position: Duration.zero,
      clearDuration: true,
      clearActiveMoment: true,
      narrationActive: false,
    );
  }

  @override
  Future<void> setNarration(bool active) async {
    if (_disposed) {
      return;
    }
    final request = _activeRequest;
    final player = _active;
    if (request == null || player == null || !request.narrationEnabled) {
      return;
    }
    await player.setVolume(_effectiveVolume(request, narration: active));
    _publish(narrationActive: active);
  }

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) async {
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
  }

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
      _effectiveVolume(request, narration: _snapshot.value.narrationActive),
    );
  }

  Future<void> _restoreActiveVolume() async {
    if (_disposed) {
      return;
    }
    await _applyActiveVolume();
  }

  Future<void> _cleanUpStaleTarget(PlayerPort target) async {
    if (_disposed) {
      return;
    }
    await _bestEffort(target.stop);
    await _bestEffort(_restoreActiveVolume);
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      // The original playback failure remains the actionable alert.
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
          if (identical(player, _active)) {
            _publish(
              phase: PlaybackPhase.stopped,
              playing: false,
              position: Duration.zero,
            );
          }
        }),
      )
      ..add(
        player.errors.listen((error) {
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

  bool _isCurrent(int generation) =>
      !_disposed && generation == _requestGeneration;

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
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _requestGeneration++;
    _incomingFade.cancel();
    _outgoingFade.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await Future.wait([_playerA.dispose(), _playerB.dispose()]);
    await _alerts.close();
    _snapshot.dispose();
  }
}
