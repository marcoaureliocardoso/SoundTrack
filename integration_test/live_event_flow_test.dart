import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/widgets/event_card.dart';
import 'package:soundtrack/features/live/application/active_live_session_store.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/live/presentation/preflight_page.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';
import 'package:soundtrack/platform/system/system_status_gateway.dart';

import '../test/support/fake_live_playback_port.dart';
import '../test/support/in_memory_event_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'runs live mode, backgrounds safely, stops, exports and imports',
    (tester) async {
      final event = _event();
      final repository = InMemoryEventRepository([event]);
      final playback = FakeLivePlaybackPort();
      final gateway = _LiveFlowGateway();
      final activeSessionStore = MemoryActiveLiveSessionStore();
      _connectPlaybackSnapshots(playback);

      await tester.pumpWidget(
        SoundTrackApp(
          dependencies: AppDependencies(
            eventRepository: repository,
            newEventId: () => 'imported-event',
            newMomentId: () => 'unused',
            playback: playback,
            documentGateway: gateway,
            preflightRecords: _Records(),
            systemStatus: _SystemStatus(),
            activeLiveSessionStore: activeSessionStore,
            clock: () => DateTime.utc(2026, 7, 10),
          ),
        ),
      );
      await _pumpFlow(tester);

      expect(find.byType(EventLibraryPage), findsOneWidget);
      await tester.tap(find.byType(EventCard));
      await _pumpFlow(tester);
      await tester.tap(find.text('Modo Evento'));
      await _pumpFlow(tester);

      expect(find.byType(PreflightPage), findsOneWidget);
      expect(find.text('Entrar mesmo assim'), findsOneWidget);
      await tester.tap(find.text('Entrar mesmo assim'));
      await _pumpFlow(tester);
      await tester.tap(find.text('Entrar no Modo Evento'));
      await _pumpFlow(tester);

      expect(find.byType(LiveDashboardPage), findsOneWidget);
      expect(await activeSessionStore.readEventId(), event.id);

      await tester.tap(find.byKey(liveMomentKey('moment-1')));
      await _pumpFlow(tester);
      expect(playback.requests.last.momentId, 'moment-1');
      expect(playback.snapshot.value.activeMomentId, 'moment-1');

      await tester.tap(find.byKey(liveMomentKey('moment-2')));
      await _pumpFlow(tester);
      expect(playback.requests.last.momentId, 'moment-2');
      expect(playback.requests.last.loop, isFalse);
      expect(playback.requests.last.narrationEnabled, isTrue);
      expect(playback.requests.last.fadeIn, const Duration(seconds: 1));

      final requestCountBeforePending = playback.requests.length;
      await tester.ensureVisible(find.byKey(liveMomentKey('moment-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(liveMomentKey('moment-3')));
      await _pumpFlow(tester);
      expect(playback.requests, hasLength(requestCountBeforePending));
      expect(playback.snapshot.value.activeMomentId, 'moment-2');

      await tester.scrollUntilVisible(
        find.byKey(narrationKey),
        300,
        scrollable: _dashboardScrollable(),
        maxScrolls: 20,
      );
      await tester.tap(find.byKey(narrationKey));
      await _pumpFlow(tester);
      expect(playback.snapshot.value.narrationActive, isTrue);

      await tester.tap(find.byKey(narrationKey));
      await _pumpFlow(tester);
      expect(playback.snapshot.value.narrationActive, isFalse);

      await tester.ensureVisible(find.byKey(emergencyVolumesKey));
      await tester.tap(find.byKey(emergencyVolumesKey));
      await _pumpFlow(tester);
      final masterSlider = tester.widget<Slider>(find.byType(Slider).first);
      masterSlider.onChanged!(40);
      await _pumpFlow(tester);
      expect(playback.sessionVolumes.last.master, 0.4);

      await tester.ensureVisible(find.text('Restaurar predefinições'));
      await tester.tap(find.text('Restaurar predefinições'));
      await _pumpFlow(tester);
      expect(playback.restoreCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(playback.pauseCalls, 0);
      expect(playback.stopCalls, 0);
      expect(playback.snapshot.value.activeMomentId, 'moment-2');

      await tester.ensureVisible(find.byKey(stopPlaybackKey));
      await tester.tap(find.byKey(stopPlaybackKey));
      await _pumpFlow(tester);
      await tester.tap(find.text('Parar reprodução'));
      await _pumpFlow(tester);
      expect(playback.stopCalls, 1);
      expect(await activeSessionStore.readEventId(), event.id);

      await tester.binding.handlePopRoute();
      await _pumpFlow(tester);
      await tester.tap(find.text('Sair'));
      await _pumpFlow(tester);
      expect(await activeSessionStore.readEventId(), isNull);
      await tester.binding.handlePopRoute();
      await _pumpFlow(tester);
      await tester.binding.handlePopRoute();
      await _pumpFlow(tester);

      await tester.tap(find.byType(PopupMenuButton<EventCardAction>));
      await _pumpFlow(tester);
      await tester.tap(find.text('Exportar'));
      await _pumpFlow(tester);
      expect(gateway.exportedContents, isNotNull);

      await tester.tap(find.text('Importar'));
      await _pumpFlow(tester);
      expect(find.text('Localizar músicas'), findsOneWidget);
      expect(find.text('Nenhuma música selecionada'), findsWidgets);

      await tester.tap(find.text('Escolher música').first);
      await _pumpFlow(tester);
      expect(gateway.pickAudioCalls, 1);
    },
  );
}

Finder _dashboardScrollable() => find.descendant(
  of: find.byKey(liveDashboardScrollKey),
  matching: find.byType(Scrollable),
);

void _connectPlaybackSnapshots(FakeLivePlaybackPort playback) {
  playback.onStartMoment = (request) async {
    playback.snapshotNotifier.value = PlaybackSnapshot(
      phase: PlaybackPhase.playing,
      playing: true,
      position: Duration.zero,
      duration: const Duration(minutes: 3),
      narrationActive: false,
      masterVolume: playback.snapshot.value.masterVolume,
      musicVolume: playback.snapshot.value.musicVolume,
      narrationVolume: playback.snapshot.value.narrationVolume,
      activeMomentId: request.momentId,
    );
  };
  playback.onSetNarration = (active) async {
    playback.snapshotNotifier.value = playback.snapshot.value.copyWith(
      narrationActive: active,
    );
  };
  playback.onStop = () async {
    playback.snapshotNotifier.value = const PlaybackSnapshot(
      phase: PlaybackPhase.stopped,
      playing: false,
      position: Duration.zero,
      duration: null,
      narrationActive: false,
      masterVolume: 0.8,
      musicVolume: 1,
      narrationVolume: 0.25,
    );
  };
}

Future<void> _pumpFlow(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

SoundTrackEvent _event() {
  return SoundTrackEvent.create(id: 'event-1', name: 'Formatura MVP').copyWith(
    moments: [
      EventMoment.create(
        id: 'moment-1',
        position: 0,
        name: 'Entrada',
      ).copyWith(audio: _audio('content://entrada', 'entrada.mp3')),
      EventMoment.create(
        id: 'moment-2',
        position: 1,
        name: 'Discurso',
      ).copyWith(
        audio: _audio('content://discurso', 'discurso.mp3'),
        endBehavior: EndBehavior.stop,
        narrationEnabled: true,
        fadeIn: const Duration(seconds: 1),
      ),
      EventMoment.create(id: 'moment-3', position: 2, name: 'Sem áudio'),
    ],
  );
}

AudioReference _audio(String uri, String displayName) {
  return AudioReference(
    uri: uri,
    displayName: displayName,
    pending: false,
    artist: 'Banda Local',
    duration: const Duration(minutes: 3),
  );
}

final class _LiveFlowGateway implements DocumentGateway {
  String? exportedContents;
  var pickAudioCalls = 0;

  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async {
    exportedContents = contents;
    return true;
  }

  @override
  Future<String?> openEventJson() async => exportedContents;

  @override
  Future<bool> canRead(String uri) async => uri.startsWith('content://');

  @override
  Future<PickedDocument?> pickAudio() async {
    pickAudioCalls++;
    return const PickedDocument(
      uri: 'content://replacement',
      displayName: 'religada.mp3',
    );
  }

  @override
  Future<AudioProbeResult> probeAudio(String uri) async =>
      const AudioProbeResult(
        playable: true,
        artist: 'Banda Local',
        duration: Duration(minutes: 3),
      );
}

final class _Records implements PreflightRecordRepository {
  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<PreflightRecord>> findAll() async => const [];

  @override
  Future<PreflightRecord?> findByEventId(String eventId) async => null;

  @override
  Future<void> save(PreflightRecord record) async {}
}

final class _SystemStatus implements SystemStatusGateway {
  @override
  Future<int> batteryPercent() async => 100;

  @override
  Future<bool> charging() async => true;

  @override
  Future<bool?> doNotDisturbEnabled() async => true;

  @override
  Future<double> mediaVolume() async => 1;

  @override
  Future<String> outputRouteLabel() async => 'Emulador';

  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
}
