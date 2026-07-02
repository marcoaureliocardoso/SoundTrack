import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

import '../../../support/fake_live_playback_port.dart';

void main() {
  testWidgets('shows confirmed route and information-only now playing', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);

    expect(find.text('Formatura'), findsOneWidget);
    expect(find.text('Modo Evento'), findsOneWidget);
    expect(find.text('Bluetooth JBL'), findsOneWidget);
    expect(find.byKey(nowPlayingPanelKey), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(nowPlayingPanelKey))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(
      tester
          .getSemantics(find.byKey(nowPlayingPanelKey))
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isFalse,
    );

    await harness.dispose(tester);
  });

  testWidgets('moment buttons expose track and textual status and start once', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);

    expect(find.text('MOMENTOS — TOQUE PARA INICIAR'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('entrada.mp3'), findsOneWidget);
    expect(find.text('TOQUE PARA INICIAR'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Brinde'), findsOneWidget);
    expect(find.text('brinde.mp3'), findsOneWidget);
    expect(find.text('ÁUDIO PENDENTE'), findsOneWidget);

    await tester.tap(find.byKey(liveMomentKey('ready')));
    await tester.pump();
    expect(harness.playback.commands, ['start:ready']);

    final pending = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(liveMomentKey('pending')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(pending.onPressed, isNull);

    harness.playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
        .copyWith(
          phase: PlaybackPhase.playing,
          playing: true,
          activeMomentId: 'ready',
          position: Duration(seconds: 12),
          duration: Duration(minutes: 3),
        );
    await tester.pump();
    expect(find.text('ATUAL'), findsOneWidget);
    expect(find.text('Reproduzindo'), findsOneWidget);
    expect(find.text('0:12 / 3:00'), findsOneWidget);
    final active = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(liveMomentKey('ready')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(active.onPressed, isNull);

    await harness.dispose(tester);
  });

  testWidgets('pause resume narration and volume controls map commands', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
        .copyWith(
          phase: PlaybackPhase.playing,
          playing: true,
          activeMomentId: 'ready',
        );
    await tester.pump();

    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.pump();
    expect(harness.playback.pauseCalls, 1);

    harness.playback.snapshotNotifier.value = harness
        .playback
        .snapshotNotifier
        .value
        .copyWith(phase: PlaybackPhase.paused, playing: false);
    await tester.pump();
    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.pump();
    expect(harness.playback.resumeCalls, 1);

    expect(find.text('Narração inativa'), findsOneWidget);
    await tester.tap(find.byKey(narrationKey));
    await tester.pump();
    expect(harness.playback.commands.last, 'narration:true');
    harness.playback.snapshotNotifier.value = harness
        .playback
        .snapshotNotifier
        .value
        .copyWith(narrationActive: true);
    await tester.pump();
    expect(find.text('Narração ativa'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(emergencyVolumesKey));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.textContaining('Master'), findsOneWidget);
    expect(find.textContaining('Música'), findsOneWidget);
    expect(find.textContaining('Narração'), findsWidgets);

    tester.widget<Slider>(find.byType(Slider).at(0)).onChanged!(25);
    await tester.pump();
    expect(harness.playback.sessionVolumes.last.master, .25);
    expect(harness.playback.sessionVolumes.last.music, 1);
    expect(harness.playback.sessionVolumes.last.narration, .25);

    tester.widget<Slider>(find.byType(Slider).at(1)).onChanged!(60);
    await tester.pump();
    expect(harness.playback.sessionVolumes.last.master, .8);
    expect(harness.playback.sessionVolumes.last.music, .6);
    expect(harness.playback.sessionVolumes.last.narration, .25);

    tester.widget<Slider>(find.byType(Slider).at(2)).onChanged!(40);
    await tester.pump();
    expect(harness.playback.sessionVolumes.last.master, .8);
    expect(harness.playback.sessionVolumes.last.music, 1);
    expect(harness.playback.sessionVolumes.last.narration, .4);

    await tester.ensureVisible(find.text('Restaurar predefinições'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar predefinições'));
    await tester.pump();
    expect(harness.playback.restoreCalls, 1);

    await harness.dispose(tester);
  });

  testWidgets('stop confirmation names current moment and is single flight', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
        .copyWith(activeMomentId: 'ready');
    await tester.pump();

    final stop = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(stopPlaybackKey),
        matching: find.byType(IconButton),
      ),
    );
    stop.onPressed!();
    stop.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Parar “Entrada”?'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(harness.playback.stopCalls, 0);

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Parar reprodução'),
    );
    confirm.onPressed!();
    confirm.onPressed!();
    await tester.pumpAndSettle();
    expect(harness.playback.stopCalls, 1);

    await harness.dispose(tester);
  });

  testWidgets('back requires confirmation and never stops playback', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    late LiveEventController controller;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                controller = LiveEventController(
                  event: _event(),
                  playback: playback,
                );
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveDashboardPage(
                      controller: controller,
                      outputRouteLabel: 'Bluetooth JBL',
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Sair do Modo Evento?'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(playback.stopCalls, 0);
    await tester.tap(find.text('Continuar no evento'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveDashboardPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveDashboardPage), findsNothing);
    expect(playback.stopCalls, 0);
    expect(playback.disposeCalls, 0);
    expect(playback.alertController.hasListener, isFalse);
  });

  testWidgets('alert is dismissible without blocking moment actions', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.playback.alertController.add(
      const PlaybackAlert(PlaybackAlertCode.routeChanged, 'Saída alterada.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Saída alterada.'), findsOneWidget);

    await tester.tap(find.byKey(liveMomentKey('ready')));
    await tester.pump();
    expect(harness.playback.requests, hasLength(1));
    await tester.tap(find.byTooltip('Dispensar aviso'));
    await tester.pump();
    expect(find.text('Saída alterada.'), findsNothing);

    await harness.dispose(tester);
  });
}

Future<_Harness> _pumpDashboard(WidgetTester tester) async {
  final playback = FakeLivePlaybackPort();
  final controller = LiveEventController(event: _event(), playback: playback);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      home: LiveDashboardPage(
        controller: controller,
        outputRouteLabel: 'Bluetooth JBL',
      ),
    ),
  );
  await tester.pump();
  return _Harness(playback: playback, controller: controller);
}

SoundTrackEvent _event() {
  final ready = EventMoment.create(id: 'ready', position: 0, name: 'Entrada')
      .copyWith(
        narrationEnabled: true,
        audio: const AudioReference(
          uri: 'content://entrada',
          displayName: 'entrada.mp3',
          pending: false,
          artist: 'Orquestra',
          duration: Duration(minutes: 3),
        ),
      );
  final pending = EventMoment.create(id: 'pending', position: 1, name: 'Brinde')
      .copyWith(
        audio: const AudioReference(
          uri: null,
          displayName: 'brinde.mp3',
          pending: true,
          artist: null,
          duration: null,
        ),
      );
  return SoundTrackEvent.create(
    id: 'event',
    name: 'Formatura',
  ).addMoment(ready).addMoment(pending);
}

final class _Harness {
  const _Harness({required this.playback, required this.controller});

  final FakeLivePlaybackPort playback;
  final LiveEventController controller;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }
}
