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

void main() {
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

  testWidgets('recheck ignores a stale asynchronous result', (tester) async {
    final first = Completer<PreflightResult>();
    final second = Completer<PreflightResult>();
    final service = _ScriptedPreflightService([first.future, second.future]);

    await tester.pumpWidget(_app(service: service));
    await tester.tap(find.text('Reverificar'));
    await tester.pump();

    second.complete(_cleanResult());
    await tester.pumpAndSettle();
    expect(find.text('Iniciar Modo Evento'), findsOneWidget);

    first.complete(_errorResult());
    await tester.pumpAndSettle();
    expect(find.text('Iniciar Modo Evento'), findsOneWidget);
    expect(find.text('Entrar mesmo assim'), findsNothing);
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
        dashboardBuilder: (context, checkedEvent) {
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

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(playback.alertController.hasListener, isFalse);
    expect(playback.stopCalls, 0);
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
          ],
          readyMomentIds: const {'moment-1'},
        ),
      ),
    ]);

    await tester.pumpWidget(
      _app(
        event: event,
        service: service,
        dashboardBuilder: (_, checkedEvent) {
          expect(identical(checkedEvent, event), isTrue);
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
          dashboardBuilder ?? (_, _) => const Scaffold(body: Text('Dashboard')),
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
  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<PreflightRecord>> findAll() async => const [];

  @override
  Future<PreflightRecord?> findByEventId(String eventId) async => null;

  @override
  Future<void> save(PreflightRecord record) async {}
}
