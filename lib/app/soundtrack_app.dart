import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../features/events/application/event_library_controller.dart';
import '../features/events/application/event_transfer_controller.dart';
import '../features/events/presentation/event_library_page.dart';
import '../features/playback/presentation/audio_engine_lab_page.dart';
import 'app_dependencies.dart';

class SoundTrackApp extends StatefulWidget {
  const SoundTrackApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<SoundTrackApp> createState() => _SoundTrackAppState();
}

class _SoundTrackAppState extends State<SoundTrackApp> {
  late final EventLibraryController _libraryController;
  late final EventTransferController _transferController;

  @override
  void initState() {
    super.initState();
    _libraryController = widget.dependencies.createLibraryController();
    _transferController = widget.dependencies.createTransferController();
  }

  @override
  void dispose() {
    _libraryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routes = buildSoundTrackRoutes(
      dependencies: widget.dependencies,
      debugMode: kDebugMode,
    );
    return MaterialApp(
      title: 'SoundTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routes: routes,
      home: EventLibraryPage(
        controller: _libraryController,
        createEditorController: widget.dependencies.createEditorController,
        onExport: _transferController.exportEvent,
        onImport: _transferController.importEvent,
        transferController: _transferController,
        onSelectAudio: _transferController.selectAudio,
        audioEngineLabRoute: routes.containsKey(debugAudioEngineLabRoute)
            ? debugAudioEngineLabRoute
            : null,
      ),
    );
  }
}

const debugAudioEngineLabRoute = '/debug/audio-engine';

Map<String, WidgetBuilder> buildSoundTrackRoutes({
  required AppDependencies dependencies,
  required bool debugMode,
}) {
  if (!debugMode) {
    return const {};
  }
  return {
    debugAudioEngineLabRoute: (_) => AudioEngineLabPage(
      playback: dependencies.playback,
      documents: dependencies.documentGateway,
    ),
  };
}
