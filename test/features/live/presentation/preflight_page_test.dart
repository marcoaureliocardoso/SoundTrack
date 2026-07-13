import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/live/application/live_event_controller.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';
import 'package:soundtrack/features/live/application/preflight_service.dart';
import 'package:soundtrack/features/live/domain/preflight_result.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_page.dart';
import 'package:soundtrack/features/live/presentation/preflight_page.dart';
import 'package:soundtrack/platform/system/system_status_gateway.dart';

import '../../../support/fake_live_playback_port.dart';
import '../../../support/accessibility_test_harness.dart';

void main() {
  testWidgets('keeps preflight content reachable at 200 percent', (
    tester,
  ) async {
    final service = _ScriptedPreflightService([Future.value(_errorResult())]);

    await pumpAccessibleApp(
      tester,
      viewport: accessibilityViewports.first,
      textScale: 2,
      home: PreflightPage(
        event: _event(),
        preflightService: service,
        dashboardBuilder: (_, _, _) => const Scaffold(body: Text('Dashboard')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Entrar mesmo assim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows progress then groups errors warnings and information', (
    tester,
  ) async {
    final check = Completer<PreflightResult>();
    final service = _ScriptedPreflightService([check.future]);

    await tester.pumpWidget(_app(service: service));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    check.complete(
      PreflightResult(
        items: const [
          PreflightItem(
            code: PreflightCode.audioUnreadable,
            severity: PreflightSeverity.error,
            message: 'O áudio de “Entrada” não pode ser lido.',
            momentId: 'moment-1',
          ),
          PreflightItem(
            code: PreflightCode.lowBattery,
            severity: PreflightSeverity.warning,
            message: 'Bateria em 10% e fora do carregador.',
          ),
          PreflightItem(
            code: PreflightCode.outputRoute,
            severity: PreflightSeverity.info,
            message: 'Saída de áudio: Alto-falante.',
          ),
        ],
        readyMomentIds: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Erros'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Informações'), findsOneWidget);
    expect(find.textContaining('Entrada'), findsOneWidget);
    expect(find.text('Saída de áudio: Alto-falante.'), findsOneWidget);
    expect(find.text('Entrar mesmo assim'), findsOneWidget);
  });

  testWidgets('ignores a check result after disposal', (tester) async {
    final first = Completer<PreflightResult>();
    final service = _ScriptedPreflightService([first.future]);

    await tester.pumpWidget(_app(service: service));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    first.complete(_errorResult());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('serializes checks and persists each completed run once', (
    tester,
  ) async {
    final firstRead = Completer<bool>();
    final records = _Records();
    var readCalls = 0;
    final service = PreflightService(
      canRead: (_) {
        readCalls++;
        return readCalls == 1 ? firstRead.future : Future.value(true);
      },
      canPrepare: (_) async => true,
      systemStatus: _SystemStatus(),
      records: records,
    );

    await tester.pumpWidget(_app(service: service));
    final checkingButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Reverificar'),
    );
    expect(checkingButton.onPressed, isNull);
    expect(readCalls, 1);
    expect(records.saveCalls, 0);

    firstRead.complete(true);
    await tester.pumpAndSettle();
    expect(records.saveCalls, 1);

    await tester.tap(find.text('Reverificar'));
    await tester.pumpAndSettle();
    expect(readCalls, 2);
    expect(records.saveCalls, 2);
  });

  testWidgets('errors require explicit confirmation and preserve snapshot', (
    tester,
  ) async {
    final event = _event();
    SoundTrackEvent? enteredEvent;
    var dashboardBuilds = 0;
    final playback = FakeLivePlaybackPort();
    final service = _ScriptedPreflightService([Future.value(_errorResult())]);

    await tester.pumpWidget(
      _app(
        event: event,
        service: service,
        dashboardBuilder: (context, checkedEvent, _) {
          dashboardBuilds++;
          enteredEvent = checkedEvent;
          return LiveDashboardPage(
            controller: LiveEventController(
              event: checkedEvent,
              playback: playback,
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(playback.commands, isEmpty);
    expect(playback.alertController.hasListener, isFalse);

    await tester.tap(find.text('Entrar mesmo assim'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar entrada'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveDashboardPage), findsNothing);
    expect(dashboardBuilds, 0);
    expect(playback.commands, isEmpty);

    await tester.tap(find.text('Entrar mesmo assim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar no Modo Evento'));
    await tester.pumpAndSettle();

    expect(find.byType(LiveDashboardPage), findsOneWidget);
    expect(identical(enteredEvent, event), isTrue);
    expect(dashboardBuilds, 1);
    expect(playback.commands, isEmpty);
    expect(playback.alertController.hasListener, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Sair do Modo Evento?'), findsOneWidget);
    expect(playback.alertController.hasListener, isTrue);
    expect(playback.stopCalls, 0);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(playback.alertController.hasListener, isFalse);
    expect(playback.stopCalls, 1);
  });

  testWidgets('clean result enters directly and warnings do not block', (
    tester,
  ) async {
    final event = _event();
    final service = _ScriptedPreflightService([
      Future.value(
        PreflightResult(
          items: const [
            PreflightItem(
              code: PreflightCode.lowSystemVolume,
              severity: PreflightSeverity.warning,
              message: 'Volume baixo.',
            ),
            PreflightItem(
              code: PreflightCode.outputRoute,
              severity: PreflightSeverity.info,
              message: 'Saída de áudio: Alto-falante.',
            ),
          ],
          readyMomentIds: const {'moment-1'},
        ),
      ),
    ]);

    await tester.pumpWidget(
      _app(
        event: event,
        service: service,
        dashboardBuilder: (_, checkedEvent, outputRouteLabel) {
          expect(identical(checkedEvent, event), isTrue);
          expect(outputRouteLabel, 'Alto-falante');
          return const Scaffold(body: Text('Ao vivo'));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar Modo Evento'));
    await tester.pumpAndSettle();

    expect(find.text('Ao vivo'), findsOneWidget);
    expect(find.text('Confirmar entrada'), findsNothing);
  });

  testWidgets('serializes entry until dashboard returns', (tester) async {
    var dashboardBuilds = 0;
    final service = _ScriptedPreflightService([Future.value(_cleanResult())]);
    await tester.pumpWidget(
      _app(
        service: service,
        dashboardBuilder: (_, _, _) {
          dashboardBuilds++;
          return const Scaffold(body: Text('Ao vivo único'));
        },
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Iniciar Modo Evento'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(dashboardBuilds, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final returnedButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Iniciar Modo Evento'),
    );
    expect(returnedButton.onPressed, isNotNull);
    await tester.tap(find.text('Iniciar Modo Evento'));
    await tester.pumpAndSettle();
    expect(dashboardBuilds, 2);
  });

  testWidgets('serializes error dialog and double confirmation', (
    tester,
  ) async {
    var dashboardBuilds = 0;
    final service = _ScriptedPreflightService([Future.value(_errorResult())]);
    await tester.pumpWidget(
      _app(
        service: service,
        dashboardBuilder: (_, _, _) {
          dashboardBuilds++;
          return const Scaffold(body: Text('Dashboard confirmado'));
        },
      ),
    );
    await tester.pumpAndSettle();

    final entryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Entrar mesmo assim'),
    );
    entryButton.onPressed!();
    entryButton.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Confirmar entrada'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Entrar mesmo assim'),
          )
          .onPressed,
      isNull,
    );

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Entrar no Modo Evento'),
    );
    confirmButton.onPressed!();
    confirmButton.onPressed!();
    await tester.pumpAndSettle();
    expect(dashboardBuilds, 1);
    expect(find.text('Dashboard confirmado'), findsOneWidget);
  });

  testWidgets('check failure shows retry and recovers without crashing', (
    tester,
  ) async {
    final failedCheck = Completer<PreflightResult>();
    final service = _ScriptedPreflightService([
      failedCheck.future,
      Future.value(_cleanResult()),
    ]);

    await tester.pumpWidget(_app(service: service));
    failedCheck.completeError(StateError('storage failed'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível concluir a verificação.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar Modo Evento'), findsOneWidget);
  });
}

Widget _app({
  SoundTrackEvent? event,
  required PreflightService service,
  LiveDashboardBuilder? dashboardBuilder,
}) {
  return MaterialApp(
    home: PreflightPage(
      event: event ?? _event(),
      preflightService: service,
      dashboardBuilder:
          dashboardBuilder ??
          (_, _, _) => const Scaffold(body: Text('Dashboard')),
    ),
  );
}

PreflightResult _cleanResult() => PreflightResult(
  items: const [
    PreflightItem(
      code: PreflightCode.outputRoute,
      severity: PreflightSeverity.info,
      message: 'Saída de áudio: Alto-falante.',
    ),
  ],
  readyMomentIds: const {'moment-1'},
);

PreflightResult _errorResult() => PreflightResult(
  items: const [
    PreflightItem(
      code: PreflightCode.audioUnreadable,
      severity: PreflightSeverity.error,
      message: 'O áudio de “Entrada” não pode ser lido.',
      momentId: 'moment-1',
    ),
  ],
  readyMomentIds: const [],
);

SoundTrackEvent _event() {
  return SoundTrackEvent.create(id: 'event-1', name: 'Formatura').addMoment(
    EventMoment.create(id: 'moment-1', position: 0, name: 'Entrada').copyWith(
      audio: const AudioReference(
        uri: 'content://entrada',
        displayName: 'Entrada.mp3',
        pending: false,
        artist: null,
        duration: null,
      ),
    ),
  );
}

final class _ScriptedPreflightService extends PreflightService {
  _ScriptedPreflightService(this.results)
    : super(
        canRead: (_) async => true,
        canPrepare: (_) async => true,
        systemStatus: _SystemStatus(),
        records: _Records(),
      );

  final List<Future<PreflightResult>> results;
  var calls = 0;

  @override
  Future<PreflightResult> check(SoundTrackEvent event) => results[calls++];
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
  var saveCalls = 0;

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<PreflightRecord>> findAll() async => const [];

  @override
  Future<PreflightRecord?> findByEventId(String eventId) async => null;

  @override
  Future<void> save(PreflightRecord record) async {
    saveCalls++;
  }
}
