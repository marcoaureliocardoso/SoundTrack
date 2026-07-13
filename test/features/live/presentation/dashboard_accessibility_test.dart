import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/live/presentation/widgets/live_alert_banner.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

import '../../../support/fake_live_playback_port.dart';
import '../../../support/accessibility_test_harness.dart';

void main() {
  testWidgets('keeps transport and expanded volumes usable at 200 percent', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
      phase: PlaybackPhase.playing,
      playing: true,
      activeMomentId: 'moment-0',
    );
    final controller = LiveEventController(
      event: _manyMomentsEvent(),
      playback: playback,
    );
    addTearDown(controller.dispose);

    await pumpAccessibleApp(
      tester,
      viewport: accessibilityViewports.first,
      textScale: 2,
      home: LiveDashboardPage(
        controller: controller,
        outputRouteLabel: 'Bluetooth com nome de rota muito longo',
      ),
    );

    final dashboardScroll = find.descendant(
      of: find.byKey(liveDashboardScrollKey),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(pausePlaybackKey),
      320,
      scrollable: dashboardScroll,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(pausePlaybackKey)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(stopPlaybackKey)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(narrationKey)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.scrollUntilVisible(
      find.byKey(emergencyVolumesKey),
      320,
      scrollable: dashboardScroll,
    );
    await tester.tap(find.byKey(emergencyVolumesKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(nowPlayingPanelKey)).height,
      greaterThan(48),
    );
    expect(
      intersects(
        tester,
        find.byKey(nowPlayingPanelKey),
        find.byKey(pausePlaybackKey),
      ),
      isFalse,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();
    expect(find.text('Restaurar predefinições'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps now playing separated from moments at 200 percent', (
    tester,
  ) async {
    final controller = LiveEventController(
      event: _manyMomentsEvent(),
      playback: FakeLivePlaybackPort(),
    );
    addTearDown(controller.dispose);

    await pumpAccessibleApp(
      tester,
      viewport: const Size(320, 800),
      textScale: accessibilityTextScales.last,
      home: LiveDashboardPage(
        controller: controller,
        outputRouteLabel: 'Rota não confirmada',
      ),
    );

    final nowPlaying = tester.getRect(find.byKey(nowPlayingPanelKey));
    final moments = tester.getRect(find.text('MOMENTOS — TOQUE PARA INICIAR'));
    expect(moments.top - nowPlaying.bottom, greaterThanOrEqualTo(16));
    expect(
      intersects(
        tester,
        find.byKey(nowPlayingPanelKey),
        find.text('MOMENTOS — TOQUE PARA INICIAR'),
      ),
      isFalse,
    );
  });

  testWidgets('lays out a large alert without clipping adjacent content', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    final controller = LiveEventController(
      event: _manyMomentsEvent(),
      playback: playback,
    );
    addTearDown(controller.dispose);

    await pumpAccessibleApp(
      tester,
      viewport: accessibilityViewports.first,
      textScale: 2,
      home: LiveDashboardPage(
        controller: controller,
        outputRouteLabel: 'Rota não confirmada',
      ),
    );
    playback.alertController.add(
      const PlaybackAlert(
        PlaybackAlertCode.routeChanged,
        'A saída de áudio foi alterada durante o evento. Confirme a rota antes de continuar.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiveAlertBanner), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(LiveAlertBanner),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    expect(
      tester.getRect(find.byTooltip('Dispensar aviso')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(LiveAlertBanner)).bottom),
    );
  });

  testWidgets('remains scrollable without overflow at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playback = FakeLivePlaybackPort();
    final controller = LiveEventController(
      event: _manyMomentsEvent(),
      playback: playback,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LiveDashboardPage(
          controller: controller,
          outputRouteLabel: 'Rota não confirmada',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(liveMomentKey('moment-0')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final size = tester.getSize(find.byKey(liveMomentKey('moment-0')));
    expect(size.height, greaterThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending and current moment semantics include state and enabled',
    (tester) async {
      final playback = FakeLivePlaybackPort();
      final event = _manyMomentsEvent();
      playback.snapshotNotifier.value = playback.snapshotNotifier.value
          .copyWith(activeMomentId: 'moment-0', playing: true);
      final controller = LiveEventController(event: event, playback: playback);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: LiveDashboardPage(
            controller: controller,
            outputRouteLabel: 'Alto-falante',
          ),
        ),
      );
      await tester.pump();

      final current = tester
          .getSemantics(find.byKey(liveMomentKey('moment-0')))
          .getSemanticsData();
      expect(current.label, contains('ATUAL'));
      expect(current.flagsCollection.isEnabled, Tristate.isFalse);

      final pending = tester
          .getSemantics(find.byKey(liveMomentKey('moment-1')))
          .getSemanticsData();
      expect(pending.label, contains('ÁUDIO PENDENTE'));
      expect(pending.flagsCollection.isEnabled, Tristate.isFalse);
    },
  );

  testWidgets('expanded emergency volumes fit a short landscape viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playback = FakeLivePlaybackPort();
    playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
      phase: PlaybackPhase.playing,
      playing: true,
      activeMomentId: 'moment-0',
    );
    final controller = LiveEventController(
      event: _manyMomentsEvent(),
      playback: playback,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: LiveDashboardPage(
          controller: controller,
          outputRouteLabel: 'Bluetooth',
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(emergencyVolumesKey),
      240,
      scrollable: find.descendant(
        of: find.byKey(liveDashboardScrollKey),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.descendant(
        of: find.byKey(liveDashboardScrollKey),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -48),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(emergencyVolumesKey));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(nowPlayingPanelKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(nowPlayingPanelKey)).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.byKey(pausePlaybackKey), findsOneWidget);
    expect(find.byKey(stopPlaybackKey), findsOneWidget);
    expect(find.byKey(narrationKey), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(narrationKey)).getSemanticsData().label,
      'Narração inativa',
    );
    expect(
      tester.getSize(find.byKey(pausePlaybackKey)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(stopPlaybackKey)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(narrationKey)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(stopPlaybackKey),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.widget<InkWell>(find.byKey(narrationKey)).onTap, isNotNull);
    await tester.ensureVisible(find.byKey(pausePlaybackKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.pump();
    expect(playback.pauseCalls, 1);

    expect(find.byType(Slider), findsNWidgets(3));
    await tester.ensureVisible(find.text('Restaurar predefinições'));
    await tester.pumpAndSettle();
    expect(find.text('Restaurar predefinições'), findsOneWidget);
    await tester.tap(find.text('Restaurar predefinições'));
    await tester.pump();
    expect(playback.restoreCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

SoundTrackEvent _manyMomentsEvent() {
  var event = SoundTrackEvent.create(id: 'event', name: 'Evento muito longo');
  for (var index = 0; index < 8; index++) {
    event = event.addMoment(
      EventMoment.create(
        id: 'moment-$index',
        position: index,
        name: 'Momento com um nome suficientemente longo $index',
      ).copyWith(
        narrationEnabled: index == 0,
        audio: AudioReference(
          uri: index == 1 ? null : 'content://track-$index',
          displayName: 'faixa-com-nome-longo-$index.mp3',
          pending: index == 1,
          artist: null,
          duration: const Duration(minutes: 4),
        ),
      ),
    );
  }
  return event;
}
