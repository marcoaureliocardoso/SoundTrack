import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../../events/domain/event_audio_settings.dart';
import '../application/fade_driver.dart';
import '../application/live_playback_port.dart';
import '../application/playback_coordinator.dart';
import '../application/player_port.dart';
import '../domain/playback_alert.dart';
import '../domain/playback_snapshot.dart';
import 'audio_session_observer.dart';
import 'just_audio_player_port.dart';
import 'soundtrack_audio_handler.dart';

final class AudioEngineFactory {
  AudioEngineFactory({
    PlayerPort Function()? createPlayer,
    Future<AudioSessionBackend> Function()? loadAudioSession,
    SoundTrackAudioHandler Function(LivePlaybackPort coordinator)?
    createHandler,
  }) : _createPlayer = createPlayer ?? JustAudioPlayerPort.new,
       _loadAudioSession = loadAudioSession ?? _loadPlatformAudioSession,
       _createHandler =
           createHandler ??
           ((coordinator) => SoundTrackAudioHandler(coordinator: coordinator));

  final PlayerPort Function() _createPlayer;
  final Future<AudioSessionBackend> Function() _loadAudioSession;
  final SoundTrackAudioHandler Function(LivePlaybackPort coordinator)
  _createHandler;

  static Future<AudioSessionBackend> _loadPlatformAudioSession() async {
    return PlatformAudioSessionBackend(await AudioSession.instance);
  }

  Future<SoundTrackAudioHandler> prepareHandler() async {
    PlayerPort? playerA;
    PlayerPort? playerB;
    PlaybackCoordinator? coordinator;
    AudioSessionObserver? observer;
    _ObservedPlaybackPort? ownedPlayback;
    try {
      playerA = _createPlayer();
      playerB = _createPlayer();
      coordinator = PlaybackCoordinator(
        playerA: playerA,
        playerB: playerB,
        outgoingFade: FadeDriver(scheduler: const TimerFadeScheduler()),
        incomingFade: FadeDriver(scheduler: const TimerFadeScheduler()),
        presetVolumes: const EventAudioSettings.defaults(),
      );
      observer = AudioSessionObserver(
        await _loadAudioSession(),
        coordinator.handleAudioSessionEvent,
      );
      await observer.start();
      ownedPlayback = _ObservedPlaybackPort(
        coordinator: coordinator,
        observer: observer,
      );
      return _createHandler(ownedPlayback);
    } on Object {
      if (ownedPlayback != null) {
        await _disposeBestEffort(ownedPlayback.dispose);
      } else {
        if (observer != null) {
          await _disposeBestEffort(observer.dispose);
        }
        if (coordinator != null) {
          await _disposeBestEffort(coordinator.dispose);
        } else {
          if (playerA != null) {
            await _disposeBestEffort(playerA.dispose);
          }
          if (playerB != null) {
            await _disposeBestEffort(playerB.dispose);
          }
        }
      }
      rethrow;
    }
  }

  Future<void> _disposeBestEffort(Future<void> Function() dispose) async {
    try {
      await dispose();
    } on Object {
      // Preserve the construction failure.
    }
  }
}

final class _ObservedPlaybackPort implements LivePlaybackPort {
  _ObservedPlaybackPort({required this._coordinator, required this._observer});

  final PlaybackCoordinator _coordinator;
  final AudioSessionObserver _observer;
  Future<void>? _disposeFuture;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => _coordinator.snapshot;

  @override
  Stream<PlaybackAlert> get alerts => _coordinator.alerts;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) =>
      _coordinator.startMoment(request);

  @override
  Future<void> pause() => _coordinator.pause();

  @override
  Future<void> resume() => _coordinator.resume();

  @override
  Future<void> stop() => _coordinator.stop();

  @override
  Future<void> setNarration(bool active) => _coordinator.setNarration(active);

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) => _coordinator.setSessionVolumes(
    masterVolume: masterVolume,
    musicVolume: musicVolume,
    narrationVolume: narrationVolume,
  );

  @override
  Future<void> restorePresetVolumes() => _coordinator.restorePresetVolumes();

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    await _observer.dispose();
    await _coordinator.dispose();
  }
}
