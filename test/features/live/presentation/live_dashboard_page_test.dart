import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/live/presentation/widgets/emergency_volume_panel.dart';
import 'package:soundtrack/features/live/presentation/widgets/moment_action_button.dart';
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
    final releasePause = Completer<void>();
    harness.playback.onPause = () => releasePause.future;
    harness.playback.snapshotNotifier.value = const PlaybackSnapshot.idle()
        .copyWith(
          phase: PlaybackPhase.playing,
          playing: true,
          activeMomentId: 'ready',
        );
    await tester.pump();

    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.pump();
    expect(harness.playback.pauseCalls, 1);
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(pausePlaybackKey),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    releasePause.complete();
    await tester.pump();

    final releaseResume = Completer<void>();
    harness.playback.onResume = () => releaseResume.future;
    harness.playback.snapshotNotifier.value = harness
        .playback
        .snapshotNotifier
        .value
        .copyWith(phase: PlaybackPhase.paused, playing: false);
    await tester.pump();
    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.tap(find.byKey(pausePlaybackKey));
    await tester.pump();
    expect(harness.playback.resumeCalls, 1);
    releaseResume.complete();
    await tester.pump();

    final releaseNarration = Completer<void>();
    harness.playback.onSetNarration = (_) => releaseNarration.future;
    expect(find.text('Narração inativa'), findsOneWidget);
    await tester.tap(find.byKey(narrationKey));
    await tester.tap(find.byKey(narrationKey));
    await tester.pump();
    expect(harness.playback.commands.last, 'narration:true');
    expect(
      tester.widget<FilterChip>(find.byKey(narrationKey)).onSelected,
      isNull,
    );
    releaseNarration.complete();
    await tester.pump();
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

    final releaseFirstVolumes = Completer<void>();
    var volumeCalls = 0;
    harness.playback.onSetSessionVolumes = (_, _, _) {
      volumeCalls++;
      return volumeCalls == 1 ? releaseFirstVolumes.future : Future.value();
    };
    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    sliders[0].onChanged!(25);
    sliders[1].onChanged!(60);
    sliders[0].onChanged!(30);
    sliders[0].onChanged!(35);
    sliders[0].onChanged!(40);
    await tester.pump();
    expect(find.text('Master — 40%'), findsOneWidget);
    expect(find.text('Música — 60%'), findsOneWidget);
    expect(harness.playback.sessionVolumes, hasLength(1));
    expect(harness.playback.sessionVolumes.last.master, .25);
    expect(harness.playback.sessionVolumes.last.music, 1);
    expect(harness.playback.sessionVolumes.last.narration, .25);

    harness.playback.snapshotNotifier.value = harness
        .playback
        .snapshotNotifier
        .value
        .copyWith(masterVolume: .3);
    await tester.pump();
    expect(find.text('Master — 40%'), findsOneWidget);
    expect(find.text('Música — 60%'), findsOneWidget);

    releaseFirstVolumes.complete();
    await tester.pumpAndSettle();
    expect(harness.playback.sessionVolumes, hasLength(2));
    expect(harness.playback.sessionVolumes.last.master, .4);
    expect(harness.playback.sessionVolumes.last.music, .6);
    expect(harness.playback.sessionVolumes.last.narration, .25);

    final releaseRestore = Completer<void>();
    harness.playback.onRestorePresetVolumes = () => releaseRestore.future;
    await tester.ensureVisible(find.text('Restaurar predefinições'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar predefinições'));
    await tester.pump();
    expect(harness.playback.restoreCalls, 1);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Restaurar predefinições'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    releaseRestore.complete();
    await tester.pump();

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

  testWidgets('failed volume command rolls UI back to authoritative snapshot', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.playback.onSetSessionVolumes = (_, _, _) =>
        Future<void>.error(StateError('volume rejected'));

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(emergencyVolumesKey));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider).first).onChanged!(20);
    await tester.pump();
    await tester.pump();

    expect(find.text('Master — 80%'), findsOneWidget);
    expect(find.text('Música — 100%'), findsOneWidget);
    expect(find.text('Narração — 25%'), findsOneWidget);
    expect(find.text('Não foi possível ajustar os volumes.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await harness.dispose(tester);
  });

  testWidgets(
    'restore cancels queued volumes and runs after in-flight volume',
    (tester) async {
      final harness = await _pumpDashboard(tester);
      final releaseFirst = Completer<void>();
      harness.playback.onSetSessionVolumes = (_, _, _) => releaseFirst.future;

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(emergencyVolumesKey));
      await tester.pumpAndSettle();
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      sliders[0].onChanged!(20);
      sliders[1].onChanged!(40);
      await tester.pump();
      await tester.ensureVisible(find.text('Restaurar predefinições'));
      await tester.tap(find.text('Restaurar predefinições'));
      await tester.pump();

      expect(harness.playback.commands, ['volumes']);
      expect(
        tester
            .widgetList<Slider>(find.byType(Slider))
            .every((slider) => slider.onChanged == null),
        isTrue,
      );

      releaseFirst.complete();
      await tester.pumpAndSettle();

      expect(harness.playback.commands, ['volumes', 'restore']);
      expect(harness.playback.sessionVolumes, hasLength(1));

      harness.playback.snapshotNotifier.value = harness
          .playback
          .snapshotNotifier
          .value
          .copyWith(masterVolume: .8, musicVolume: 1, narrationVolume: .25);
      await tester.pump();
      expect(find.text('Master — 80%'), findsOneWidget);
      expect(find.text('Música — 100%'), findsOneWidget);
      expect(find.text('Narração — 25%'), findsOneWidget);

      await harness.dispose(tester);
    },
  );

  testWidgets('failed restore rolls back and reenables emergency controls', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.playback.onRestorePresetVolumes = () =>
        Future<void>.error(StateError('restore rejected'));

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(emergencyVolumesKey));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider).first).onChanged!(20);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar predefinições'));
    await tester.tap(find.text('Restaurar predefinições'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Master — 80%'), findsOneWidget);
    expect(
      tester
          .widgetList<Slider>(find.byType(Slider))
          .every((slider) => slider.onChanged != null),
      isTrue,
    );
    expect(find.text('Não foi possível restaurar os volumes.'), findsOneWidget);
    expect(tester.takeException(), isNull);

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

  testWidgets('command failures become banners without unhandled UI errors', (
    tester,
  ) async {
    final harness = await _pumpDashboard(tester);
    harness.playback.onStartMoment = (_) =>
        Future<void>.error(StateError('start failed'));

    await tester.tap(find.byKey(liveMomentKey('ready')));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Não foi possível iniciar o áudio deste momento.'),
      findsOneWidget,
    );

    await harness.dispose(tester);
  });

  testWidgets('pending moment command blocks only its own repeated taps', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    final release = Completer<void>();
    playback.onStartMoment = (_) => release.future;
    final controller = LiveEventController(
      event: _largeEvent(2),
      playback: playback,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LiveDashboardPage(
          controller: controller,
          outputRouteLabel: 'Alto-falante',
        ),
      ),
    );
    final first = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(liveMomentKey('moment-0')),
        matching: find.byType(FilledButton),
      ),
    );
    final second = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(liveMomentKey('moment-1')),
        matching: find.byType(FilledButton),
      ),
    );

    first.onPressed!();
    first.onPressed!();
    second.onPressed!();
    await tester.pump();

    expect(playback.requests.map((request) => request.momentId), [
      'moment-0',
      'moment-1',
    ]);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(liveMomentKey('moment-0')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(liveMomentKey('moment-1')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    release.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'route alerts refresh single-flight and keep only latest result',
    (tester) async {
      final playback = FakeLivePlaybackPort();
      final controller = LiveEventController(
        event: _event(),
        playback: playback,
      );
      final firstRead = Completer<String>();
      var reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LiveDashboardPage(
            controller: controller,
            outputRouteLabel: 'Bluetooth JBL',
            readOutputRoute: () {
              reads++;
              return reads == 1
                  ? firstRead.future
                  : Future.value('USB Focusrite');
            },
          ),
        ),
      );

      playback.alertController.add(
        const PlaybackAlert(PlaybackAlertCode.routeChanged, 'Rota 1'),
      );
      await tester.pump();
      playback.alertController.add(
        const PlaybackAlert(PlaybackAlertCode.routeChanged, 'Rota 2'),
      );
      await tester.pump();
      expect(reads, 1);

      firstRead.complete('Rota obsoleta');
      await tester.pumpAndSettle();

      expect(reads, 2);
      expect(find.text('USB Focusrite'), findsOneWidget);
      expect(find.text('Rota obsoleta'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('route refresh failure shows a clear fallback', (tester) async {
    final playback = FakeLivePlaybackPort();
    final controller = LiveEventController(event: _event(), playback: playback);
    await tester.pumpWidget(
      MaterialApp(
        home: LiveDashboardPage(
          controller: controller,
          outputRouteLabel: 'Bluetooth JBL',
          readOutputRoute: () => Future<String>.error(StateError('route')),
        ),
      ),
    );

    playback.alertController.add(
      const PlaybackAlert(PlaybackAlertCode.routeChanged, 'Rota mudou'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saída não confirmada'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('position ticks do not rebuild moment cards or volume panel', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
      activeMomentId: 'ready',
      phase: PlaybackPhase.playing,
      playing: true,
    );
    final controller = LiveEventController(event: _event(), playback: playback);
    var momentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveDashboardPage(
          controller: controller,
          outputRouteLabel: 'Bluetooth JBL',
          momentBuilder: (context, number, moment, status, onStart) {
            momentBuilds++;
            return MomentActionButton(
              key: liveMomentKey(moment.id),
              number: number,
              moment: moment,
              status: status,
              onPressed: onStart,
            );
          },
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final panelBefore = tester.widget(find.byType(EmergencyVolumePanel));
    final buildsBefore = momentBuilds;

    playback.snapshotNotifier.value = playback.snapshotNotifier.value.copyWith(
      position: const Duration(seconds: 30),
    );
    await tester.pump();

    expect(momentBuilds, buildsBefore);
    expect(
      identical(tester.widget(find.byType(EmergencyVolumePanel)), panelBefore),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large event builds only moment cards near the viewport', (
    tester,
  ) async {
    final playback = FakeLivePlaybackPort();
    final controller = LiveEventController(
      event: _largeEvent(100),
      playback: playback,
    );
    var momentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LiveDashboardPage(
          controller: controller,
          outputRouteLabel: 'Alto-falante',
          momentBuilder: (context, number, moment, status, onStart) {
            momentBuilds++;
            return MomentActionButton(
              key: liveMomentKey(moment.id),
              number: number,
              moment: moment,
              status: status,
              onPressed: onStart,
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(momentBuilds, greaterThan(0));
    expect(momentBuilds, lessThan(20));
    expect(find.byKey(pausePlaybackKey), findsOneWidget);
    expect(find.byKey(emergencyVolumesKey), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(pausePlaybackKey)).dy, lessThan(600));
    expect(
      tester.getTopLeft(find.byKey(emergencyVolumesKey)).dy,
      lessThan(600),
    );
    await tester.pumpWidget(const SizedBox());
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

SoundTrackEvent _largeEvent(int count) {
  var event = SoundTrackEvent.create(id: 'large', name: 'Evento grande');
  for (var index = 0; index < count; index++) {
    event = event.addMoment(
      EventMoment.create(
        id: 'moment-$index',
        position: index,
        name: 'Momento $index',
      ).copyWith(
        audio: AudioReference(
          uri: 'content://moment-$index',
          displayName: 'track-$index.mp3',
          pending: false,
          artist: null,
          duration: const Duration(minutes: 3),
        ),
      ),
    );
  }
  return event;
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
