import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../features/events/application/event_library_controller.dart';
import '../features/events/application/event_transfer_controller.dart';
import '../features/events/domain/soundtrack_event.dart';
import '../features/events/presentation/event_library_page.dart';
import '../features/live/presentation/live_dashboard_page.dart';
import '../features/live/presentation/preflight_page.dart';
import '../features/playback/domain/playback_snapshot.dart';
import '../features/playback/presentation/audio_engine_lab_page.dart';
import 'app_dependencies.dart';
import 'theme/soundtrack_theme.dart';

class SoundTrackApp extends StatefulWidget {
  const SoundTrackApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<SoundTrackApp> createState() => _SoundTrackAppState();
}

class _SoundTrackAppState extends State<SoundTrackApp> {
  late final EventLibraryController _libraryController;
  late final EventTransferController _transferController;
  late Future<SoundTrackEvent?> _activeEvent;

  @override
  void initState() {
    super.initState();
    _libraryController = widget.dependencies.createLibraryController();
    _transferController = widget.dependencies.createTransferController();
    _activeEvent = _loadActiveEvent();
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
      theme: buildSoundTrackTheme(),
      routes: routes,
      home: FutureBuilder<SoundTrackEvent?>(
        future: _activeEvent,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final activeEvent = snapshot.data;
          if (activeEvent != null) {
            return _buildLiveDashboard(activeEvent);
          }
          return _buildLibraryPage(routes);
        },
      ),
    );
  }

  Future<SoundTrackEvent?> _loadActiveEvent() async {
    final store = widget.dependencies.activeLiveSessionStore;
    if (store == null) {
      return null;
    }
    final eventId = await store.readEventId();
    if (eventId == null) {
      return null;
    }
    final playback = widget.dependencies.playback.snapshot.value;
    final inactive =
        playback.phase == PlaybackPhase.idle ||
        playback.phase == PlaybackPhase.stopped ||
        playback.activeMomentId == null;
    if (inactive) {
      await store.clear();
      return null;
    }
    final event = await widget.dependencies.eventRepository.findById(eventId);
    if (event == null) {
      await store.clear();
      return null;
    }
    return event;
  }

  Widget _buildLibraryPage(Map<String, WidgetBuilder> routes) {
    return EventLibraryPage(
      controller: _libraryController,
      createEditorController: widget.dependencies.createEditorController,
      onExport: _transferController.exportEvent,
      onImport: _transferController.importEvent,
      transferController: _transferController,
      onSelectAudio: _transferController.selectAudio,
      buildLiveEntryPage: (event) => PreflightPage(
        event: event,
        preflightService: widget.dependencies.createPreflightService(),
        dashboardBuilder: _buildDashboardFromPreflight,
      ),
      audioEngineLabRoute: routes.containsKey(debugAudioEngineLabRoute)
          ? debugAudioEngineLabRoute
          : null,
    );
  }

  Widget _buildLiveDashboard(SoundTrackEvent event) {
    return LiveDashboardPage(
      controller: widget.dependencies.createLiveEventController(event),
      onSessionExit: _leaveRestoredSession,
      readOutputRoute: widget.dependencies.systemStatus.outputRouteLabel,
      systemStatus: widget.dependencies.systemStatus,
    );
  }

  Future<void> _leaveRestoredSession() async {
    if (!mounted) return;
    setState(() {
      _activeEvent = Future<SoundTrackEvent?>.value();
    });
  }

  Widget _buildDashboardFromPreflight(
    BuildContext context,
    SoundTrackEvent checkedEvent,
    String outputRouteLabel,
  ) {
    return LiveDashboardPage(
      controller: widget.dependencies.createLiveEventController(checkedEvent),
      outputRouteLabel: outputRouteLabel,
      readOutputRoute: widget.dependencies.systemStatus.outputRouteLabel,
      systemStatus: widget.dependencies.systemStatus,
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
