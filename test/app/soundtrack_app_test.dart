import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';
import 'package:soundtrack/app/widgets/editorial_components.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/event_overview_page.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/live/presentation/preflight_page.dart';
import 'package:soundtrack/platform/system/system_status_gateway.dart';

import '../support/in_memory_event_repository.dart';
import '../support/fake_live_playback_port.dart';

void main() {
  testWidgets('opens the event library', (tester) async {
    await tester.pumpWidget(
      SoundTrackApp(
        dependencies: AppDependencies(
          eventRepository: InMemoryEventRepository(),
          newEventId: () => 'event-1',
          newMomentId: () => 'moment-1',
          playback: FakeLivePlaybackPort(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final eventLibraryContext = tester.element(find.text('Eventos'));

    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(Theme.of(eventLibraryContext).brightness, Brightness.dark);
    expect(
      appBar.title,
      isA<Text>().having((title) => title.data, 'data', 'Eventos'),
    );
    expect(find.text('Eventos'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester.widget<TextButton>(find.byKey(addEventKey)).onPressed,
      isNotNull,
    );
    expect(find.byKey(libraryMenuKey), findsOneWidget);
    await tester.tap(find.byKey(libraryMenuKey));
    await tester.pumpAndSettle();
    expect(find.byKey(openAudioEngineLabKey), findsOneWidget);
  });

  test('release navigation does not register the audio engine lab', () {
    final dependencies = AppDependencies(
      eventRepository: InMemoryEventRepository(),
      newEventId: () => 'event-1',
      newMomentId: () => 'moment-1',
      playback: FakeLivePlaybackPort(),
    );

    expect(
      buildSoundTrackRoutes(dependencies: dependencies, debugMode: false),
      isEmpty,
    );
    expect(
      buildSoundTrackRoutes(dependencies: dependencies, debugMode: true),
      contains(debugAudioEngineLabRoute),
    );
  });

  testWidgets('navigates event context to preflight to live dashboard', (
    tester,
  ) async {
    final event = SoundTrackEvent.create(id: 'event-1', name: 'Formatura');
    final playback = FakeLivePlaybackPort();
    await tester.pumpWidget(
      SoundTrackApp(
        dependencies: AppDependencies(
          eventRepository: InMemoryEventRepository([event]),
          newEventId: () => 'unused',
          newMomentId: () => 'unused',
          playback: playback,
          preflightRecords: _Records(),
          systemStatus: _SystemStatus(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Formatura'));
    await tester.pumpAndSettle();
    expect(find.byType(EventOverviewPage), findsOneWidget);
    await tester.tap(find.byKey(prepareLiveEventKey));
    await tester.pumpAndSettle();

    expect(find.byType(PreflightPage), findsOneWidget);
    expect(playback.commands, isEmpty);
    await tester.tap(find.text('Iniciar Modo Evento'));
    await tester.pumpAndSettle();

    expect(find.byType(LiveDashboardPage), findsOneWidget);
    expect(find.text('Formatura'), findsOneWidget);
    expect(playback.commands, isEmpty);
  });

  testWidgets('serializes repeated live entry from the event context', (
    tester,
  ) async {
    final event = SoundTrackEvent.create(id: 'event-1', name: 'Formatura');
    await tester.pumpWidget(
      SoundTrackApp(
        dependencies: AppDependencies(
          eventRepository: InMemoryEventRepository([event]),
          newEventId: () => 'unused',
          newMomentId: () => 'unused',
          playback: FakeLivePlaybackPort(),
          preflightRecords: _Records(),
          systemStatus: _SystemStatus(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formatura'));
    await tester.pumpAndSettle();

    final liveAction = tester.widget<OperationalActionRow>(
      find.byKey(prepareLiveEventKey),
    );
    liveAction.onTap!();
    liveAction.onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(PreflightPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PreflightPage), findsNothing);
    expect(find.byType(EventOverviewPage), findsOneWidget);
  });
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
  Future<String> outputRouteLabel() async => 'Alto-falante';

  @override
  Future<void> setKeepScreenOn(bool enabled) async {}
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
