import 'dart:async';

import '../../events/domain/event_audio_settings.dart';
import '../application/fade_driver.dart';
import '../application/live_playback_port.dart';
import '../application/playback_coordinator.dart';
import '../application/player_port.dart';
import 'just_audio_player_port.dart';
import 'soundtrack_audio_handler.dart';

final class AudioEngineFactory {
  AudioEngineFactory({
    PlayerPort Function()? createPlayer,
    SoundTrackAudioHandler Function(LivePlaybackPort coordinator)?
    createHandler,
  }) : _createPlayer = createPlayer ?? JustAudioPlayerPort.new,
       _createHandler =
           createHandler ??
           ((coordinator) => SoundTrackAudioHandler(coordinator: coordinator));

  final PlayerPort Function() _createPlayer;
  final SoundTrackAudioHandler Function(LivePlaybackPort coordinator)
  _createHandler;

  static SoundTrackAudioHandler buildHandler() {
    return AudioEngineFactory().createHandler();
  }

  SoundTrackAudioHandler createHandler() {
    PlayerPort? playerA;
    PlayerPort? playerB;
    PlaybackCoordinator? coordinator;
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
      return _createHandler(coordinator);
    } on Object {
      if (coordinator != null) {
        _disposeBestEffort(coordinator.dispose);
      } else {
        if (playerA != null) {
          _disposeBestEffort(playerA.dispose);
        }
        if (playerB != null) {
          _disposeBestEffort(playerB.dispose);
        }
      }
      rethrow;
    }
  }

  void _disposeBestEffort(Future<void> Function() dispose) {
    unawaited(Future<void>.sync(dispose).onError((Object _, StackTrace _) {}));
  }
}
