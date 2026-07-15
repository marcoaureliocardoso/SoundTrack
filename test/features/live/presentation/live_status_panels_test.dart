import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/live_event_state.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_keys.dart';
import 'package:soundtrack/features/live/presentation/widgets/live_alert_banner.dart';
import 'package:soundtrack/features/live/presentation/widgets/now_playing_panel.dart';
import 'package:soundtrack/features/live/presentation/widgets/track_name_ticker.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  const longTrack =
      'Abertura oficial - versão instrumental definitiva para a solenidade.mp3';

  testWidgets('normal now playing uses the accessible track ticker', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_panel(state: _state(track: longTrack)));

    expect(find.byType(TrackNameTicker), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(nowPlayingTrackKey), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, closeTo(12 / 180, .001));
    final decoration = tester.widget<DecoratedBox>(
      find.byKey(nowPlayingAccentKey),
    );
    final border = (decoration.decoration as BoxDecoration).border! as Border;
    expect(border.left.width, greaterThanOrEqualTo(3));
    expect(find.text('AGORA'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Agora: Entrada dos formandos. Faixa: $longTrack. '
        'Reproduzindo. Tempo 0:12 / 3:00.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('normal now playing keeps natural height at 200 percent', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _panel(state: _state(track: longTrack), textScale: 2, width: 320),
    );

    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError ? exception.toStringDeep() : null,
    );
    expect(
      tester.getSize(find.byKey(nowPlayingPanelKey)).height,
      greaterThan(180),
    );
    expect(find.byType(TrackNameTicker), findsOneWidget);
    expect(find.text('Reproduzindo'), findsOneWidget);
    expect(find.text('0:12 / 3:00'), findsOneWidget);
  });

  testWidgets('compact now playing opens the complete track in a dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _panel(state: _state(track: longTrack), compact: true),
    );

    expect(find.byType(TrackNameTicker), findsNothing);
    expect(find.text('Entrada dos formandos'), findsOneWidget);
    expect(find.text('Reproduzindo'), findsOneWidget);
    expect(find.text('0:12 / 3:00'), findsOneWidget);

    await tester.tap(find.byKey(nowPlayingPanelKey));
    await tester.pumpAndSettle();

    expect(find.byKey(nowPlayingDetailsKey), findsOneWidget);
    expect(find.text(longTrack), findsOneWidget);
  });

  testWidgets('compact alert keeps details and dismiss as separate actions', (
    tester,
  ) async {
    const message =
        'A saída de áudio foi alterada e precisa ser conferida antes de continuar.';
    var dismissCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: LiveAlertBanner(
              alert: const PlaybackAlert(
                PlaybackAlertCode.routeChanged,
                message,
              ),
              onDismiss: () => dismissCalls++,
              compact: true,
            ),
          ),
        ),
      ),
    );

    final compactText = tester.widget<Text>(find.text(message));
    expect(compactText.maxLines, 1);
    expect(compactText.overflow, TextOverflow.ellipsis);
    final dismiss = tester.getSize(find.byTooltip('Dispensar aviso'));
    expect(dismiss.width, greaterThanOrEqualTo(48));
    expect(dismiss.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byKey(liveAlertBannerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(liveAlertDetailsKey), findsOneWidget);
    expect(find.text(message), findsWidgets);
    expect(dismissCalls, 0);

    await tester.tap(find.text('Dispensar aviso').last);
    await tester.pumpAndSettle();
    expect(dismissCalls, 1);
    expect(find.byKey(liveAlertDetailsKey), findsNothing);
  });
}

Widget _panel({
  required LiveEventState state,
  bool compact = false,
  double textScale = 1,
  double width = 480,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: NowPlayingPanel(
              key: nowPlayingPanelKey,
              state: state,
              compact: compact,
            ),
          ),
        ),
      ),
    ),
  );
}

LiveEventState _state({required String track}) {
  final moment =
      EventMoment.create(
        id: 'entry',
        position: 0,
        name: 'Entrada dos formandos',
      ).copyWith(
        audio: AudioReference(
          uri: 'content://entry',
          displayName: track,
          pending: false,
          artist: 'Orquestra',
          duration: const Duration(minutes: 3),
        ),
      );
  final event = SoundTrackEvent.create(
    id: 'event',
    name: 'Formatura',
  ).addMoment(moment);
  return LiveEventState(
    event: event,
    playback: const PlaybackSnapshot.idle().copyWith(
      activeMomentId: 'entry',
      phase: PlaybackPhase.playing,
      playing: true,
      position: const Duration(seconds: 12),
      duration: const Duration(minutes: 3),
    ),
    visibleAlert: null,
    controlsExpanded: false,
  );
}
