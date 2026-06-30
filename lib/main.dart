import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';
import 'package:soundtrack/features/playback/infrastructure/audio_engine_factory.dart';

const soundTrackAudioServiceConfig = AudioServiceConfig(
  androidNotificationChannelId: 'com.soundtrack.playback',
  androidNotificationChannelName: 'Evento em execução',
  androidNotificationClickStartsActivity: true,
  androidNotificationOngoing: true,
  // audio_service 0.18.19 requires this when the notification is ongoing.
  androidStopForegroundOnPause: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioHandler = await AudioService.init(
    builder: AudioEngineFactory.buildHandler,
    config: soundTrackAudioServiceConfig,
  );
  final dependencies = await AppDependencies.create(playback: audioHandler);
  runApp(SoundTrackApp(dependencies: dependencies));
}
