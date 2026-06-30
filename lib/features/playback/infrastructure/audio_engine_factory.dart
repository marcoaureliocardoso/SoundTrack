import '../../events/domain/event_audio_settings.dart';
import '../application/fade_driver.dart';
import '../application/playback_coordinator.dart';
import 'just_audio_player_port.dart';
import 'soundtrack_audio_handler.dart';

final class AudioEngineFactory {
  const AudioEngineFactory._();

  static SoundTrackAudioHandler buildHandler() {
    final playerA = JustAudioPlayerPort();
    final playerB = JustAudioPlayerPort();
    final coordinator = PlaybackCoordinator(
      playerA: playerA,
      playerB: playerB,
      outgoingFade: FadeDriver(scheduler: const TimerFadeScheduler()),
      incomingFade: FadeDriver(scheduler: const TimerFadeScheduler()),
      presetVolumes: const EventAudioSettings.defaults(),
    );
    return SoundTrackAudioHandler(coordinator: coordinator);
  }
}
