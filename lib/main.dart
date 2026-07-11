import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/infrastructure/audio_engine_factory.dart';
import 'package:soundtrack/features/playback/infrastructure/soundtrack_audio_handler.dart';

const soundTrackAudioServiceConfig = AudioServiceConfig(
  androidNotificationChannelId: 'br.com.marcocardoso.soundtrack.playback',
  androidNotificationChannelName: 'Evento em execução',
  androidNotificationClickStartsActivity: true,
  // 0.18.19 rejects ongoing=true with foreground retention on pause.
  androidNotificationOngoing: false,
  androidStopForegroundOnPause: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await initializeSoundTrackApp());
}

Future<Widget> initializeSoundTrackApp({
  Future<LivePlaybackPort> Function()? initializeAudio,
  Future<AppDependencies> Function(LivePlaybackPort playback)?
  createDependencies,
}) async {
  LivePlaybackPort? playback;
  try {
    playback = await (initializeAudio ?? _initializeAudio)();
    final dependencies = await (createDependencies ?? _createDependencies)(
      playback,
    );
    return SoundTrackApp(dependencies: dependencies);
  } on Object {
    if (playback != null) {
      try {
        await playback.dispose();
      } on Object {
        // Preserve the startup error rather than exposing cleanup details.
      }
    }
    return const _StartupFailureApp();
  }
}

Future<LivePlaybackPort> _initializeAudio() async {
  final prepared = await AudioEngineFactory().prepareHandler();
  try {
    return await AudioService.init<SoundTrackAudioHandler>(
      builder: () => prepared,
      config: soundTrackAudioServiceConfig,
    );
  } on Object {
    await prepared.dispose();
    rethrow;
  }
}

Future<AppDependencies> _createDependencies(LivePlaybackPort playback) {
  return AppDependencies.create(playback: playback);
}

final class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Não foi possível iniciar o SoundTrack.')),
      ),
    );
  }
}
