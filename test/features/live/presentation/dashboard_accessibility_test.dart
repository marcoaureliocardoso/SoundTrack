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

import '../../../support/accessibility_test_harness.dart';
import '../../../support/fake_live_playback_port.dart';

void main() {
  for (final testCase in accessibilityTestCases) {
    testWidgets(
      'keeps fixed regions usable at ${accessibilityTestCaseLabel(testCase)}',
      (tester) async {
        final playback = FakeLivePlaybackPort();
        playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
            .copyWith(
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
          viewport: testCase.viewport,
          textScale: testCase.textScale,
          home: LiveDashboardPage(
            controller: controller,
            outputRouteLabel: 'Bluetooth com nome de rota muito longo',
          ),
        );

        expect(tester.takeException(), isNull);
        final nowBefore = tester.getRect(find.byKey(nowPlayingPanelKey));
        final centerBefore = tester.getRect(find.byKey(liveDashboardCenterKey));
        final footerBefore = tester.getRect(find.byKey(playbackFooterKey));
        final momentsTitle = tester.getRect(find.byKey(momentsSectionTitleKey));
        expect(centerBefore.height, greaterThan(0));
        expect(centerBefore.top, greaterThanOrEqualTo(nowBefore.bottom));
        expect(centerBefore.bottom, lessThanOrEqualTo(footerBefore.top));
        expect(momentsTitle.top - nowBefore.bottom, greaterThanOrEqualTo(16));

        for (final key in [
          pausePlaybackKey,
          stopPlaybackKey,
          narrationKey,
          volumesToggleKey,
        ]) {
          final size = tester.getSize(find.byKey(key));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        await tester.drag(
          find.byKey(liveDashboardScrollKey),
          const Offset(0, -160),
        );
        await tester.pump();
        expect(tester.getRect(find.byKey(nowPlayingPanelKey)), nowBefore);
        expect(tester.getRect(find.byKey(playbackFooterKey)), footerBefore);

        await tester.tap(find.byKey(volumesToggleKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Slider), findsNWidgets(3));
        expect(tester.getRect(find.byKey(nowPlayingPanelKey)), nowBefore);
        expect(
          tester.getRect(find.byKey(liveDashboardCenterKey)),
          centerBefore,
        );
        expect(tester.getRect(find.byKey(playbackFooterKey)), footerBefore);

        await tester.ensureVisible(find.text('Restaurar predefinições'));
        await tester.pump();
        expect(find.text('Restaurar predefinições'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keeps a compact alert fixed without clipping at 200 percent', (
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
      viewport: const Size(320, 480),
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

    expect(tester.takeException(), isNull);
    expect(find.byType(LiveAlertBanner), findsOneWidget);
    final now = tester.getRect(find.byKey(nowPlayingPanelKey));
    final alert = tester.getRect(find.byType(LiveAlertBanner));
    final center = tester.getRect(find.byKey(liveDashboardCenterKey));
    final footer = tester.getRect(find.byKey(playbackFooterKey));
    expect(alert.top, greaterThanOrEqualTo(now.bottom));
    expect(alert.bottom, lessThanOrEqualTo(center.top));
    expect(center.bottom, lessThanOrEqualTo(footer.top));
    expect(
      tester.getRect(find.byTooltip('Dispensar aviso')).bottom,
      lessThanOrEqualTo(alert.bottom),
    );
  });

  testWidgets('reduced motion swaps the center without an active transition', (
    tester,
  ) async {
    final controller = LiveEventController(
      event: _manyMomentsEvent(),
      playback: FakeLivePlaybackPort(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            disableAnimations: true,
          ),
          child: LiveDashboardPage(
            controller: controller,
            outputRouteLabel: 'Alto-falante',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(volumesToggleKey));
    await tester.pump();

    final curtain = tester.widget<AnimatedSlide>(
      find.byKey(emergencyVolumesCurtainKey),
    );
    expect(curtain.duration, Duration.zero);
    expect(curtain.offset, Offset.zero);
    expect(controller.state.value.controlsExpanded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending and current moments retain complete semantics', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    final event = _manyMomentsEvent();
    playback.snapshotNotifier.value = playback.snapshotNotifier.value.copyWith(
      activeMomentId: 'moment-0',
      playing: true,
    );
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
