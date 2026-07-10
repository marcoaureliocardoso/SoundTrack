import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/live/application/active_live_session_store.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';
import 'package:soundtrack/platform/system/system_status_gateway.dart';

import '../../../support/fake_live_playback_port.dart';
import '../../../support/in_memory_event_repository.dart';

void main() {
  testWidgets('background lifecycle states never pause or stop playback', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    final systemStatus = _SystemStatus();
    final controller = LiveEventController(
      event: SoundTrackEvent.create(id: 'event-1', name: 'Evento'),
      playback: playback,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LiveDashboardPage(
          controller: controller,
          systemStatus: systemStatus,
        ),
      ),
    );

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }

    expect(playback.pauseCalls, 0);
    expect(playback.stopCalls, 0);
    expect(systemStatus.keepScreenCalls, [true, false, false, false]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('confirmed stop clears the active live session', (tester) async {
    final playback = FakeLivePlaybackPort();
    playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
      phase: PlaybackPhase.playing,
      playing: true,
      activeMomentId: 'moment-1',
    );
    final store = MemoryActiveLiveSessionStore();
    final controller = LiveEventController(
      event: _event(),
      playback: playback,
      activeSessionStore: store,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveDashboardPage(
          controller: controller,
          systemStatus: _SystemStatus(),
        ),
      ),
    );
    await tester.pump();
    expect(await store.readEventId(), 'event-1');

    await tester.tap(find.byKey(stopPlaybackKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parar reprodução'));
    await tester.pumpAndSettle();

    expect(playback.stopCalls, 1);
    expect(await store.readEventId(), isNull);
  });

  testWidgets(
    'opens the active live dashboard when stored session is not idle',
    (tester) async {
      final event = _event();
      final playback = FakeLivePlaybackPort();
      playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
        phase: PlaybackPhase.playing,
        playing: true,
        activeMomentId: 'moment-1',
      );
      final store = MemoryActiveLiveSessionStore();
      await store.saveEventId(event.id);

      await tester.pumpWidget(
        SoundTrackApp(
          dependencies: AppDependencies(
            eventRepository: InMemoryEventRepository([event]),
            newEventId: () => 'unused',
            newMomentId: () => 'unused',
            playback: playback,
            activeLiveSessionStore: store,
            systemStatus: _SystemStatus(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LiveDashboardPage), findsOneWidget);
      expect(find.text('Formatura'), findsOneWidget);
      expect(find.byType(EventLibraryPage), findsNothing);
      expect(await store.readEventId(), event.id);
    },
  );

  testWidgets('clears stale active session when playback is idle', (
    tester,
  ) async {
    final event = _event();
    final playback = FakeLivePlaybackPort();
    final store = MemoryActiveLiveSessionStore();
    await store.saveEventId(event.id);

    await tester.pumpWidget(
      SoundTrackApp(
        dependencies: AppDependencies(
          eventRepository: InMemoryEventRepository([event]),
          newEventId: () => 'unused',
          newMomentId: () => 'unused',
          playback: playback,
          activeLiveSessionStore: store,
          systemStatus: _SystemStatus(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(EventLibraryPage), findsOneWidget);
    expect(find.byType(LiveDashboardPage), findsNothing);
    expect(await store.readEventId(), isNull);
  });
}

final class _SystemStatus implements SystemStatusGateway {
  final keepScreenCalls = <bool>[];

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
  Future<void> setKeepScreenOn(bool enabled) async {
    keepScreenCalls.add(enabled);
  }
}

SoundTrackEvent _event() {
  return SoundTrackEvent.create(id: 'event-1', name: 'Formatura').addMoment(
    EventMoment.create(id: 'moment-1', position: 0, name: 'Entrada').copyWith(
      audio: const AudioReference(
        uri: 'file:///entrada.mp3',
        displayName: 'Entrada.mp3',
        pending: false,
        artist: null,
        duration: Duration(minutes: 3),
      ),
    ),
  );
}
