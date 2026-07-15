import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/application/event_transfer_controller.dart';
import 'package:soundtrack/features/events/data/event_export_codec.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/widgets/event_list_row.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

import '../../../support/in_memory_event_repository.dart';
import '../../../support/accessibility_test_harness.dart';

void main() {
  for (final testCase in accessibilityTestCases) {
    testWidgets(
      'keeps library actions usable at ${accessibilityTestCaseLabel(testCase)}',
      (tester) async {
        final controller = EventLibraryController(
          repository: InMemoryEventRepository([
            SoundTrackEvent.create(
              id: 'event-1',
              name: 'Evento com um nome muito longo para a biblioteca',
            ),
          ]),
          newId: () => 'event-2',
        );

        await pumpAccessibleApp(
          tester,
          viewport: testCase.viewport,
          textScale: testCase.textScale,
          home: EventLibraryPage(
            controller: controller,
            createEditorController: (_) => throw UnimplementedError(),
            onImport: () async => null,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(addEventKey), findsOneWidget);
        expect(find.byKey(eventSortKey), findsOneWidget);
        expect(find.byKey(libraryMenuKey), findsOneWidget);
        expect(find.text('Importar evento'), findsNothing);
        for (final row in tester.widgetList<EventListRow>(
          find.byType(EventListRow),
        )) {
          expect(
            tester.getSize(find.byWidget(row)).height,
            greaterThanOrEqualTo(64),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shows approved library chrome and sorts visible events', (
    tester,
  ) async {
    final alfa = SoundTrackEvent.create(
      id: 'alfa',
      name: 'Alfa',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 14));
    final zeta = SoundTrackEvent.create(
      id: 'zeta',
      name: 'Zeta',
    ).copyWith(updatedAt: DateTime.utc(2026, 7, 15));
    final controller = EventLibraryController(
      repository: InMemoryEventRepository([alfa, zeta]),
      newId: () => 'novo',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
          onImport: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Sua biblioteca SoundTrack'), findsNothing);
    expect(find.byKey(addEventKey), findsOneWidget);
    expect(find.byKey(eventSortKey), findsOneWidget);
    expect(find.byKey(libraryMenuKey), findsOneWidget);
    expect(find.text('Importar evento'), findsNothing);
    expect(_visibleEventNames(tester), ['Zeta', 'Alfa']);

    await tester.tap(find.byKey(libraryMenuKey));
    await tester.pumpAndSettle();
    expect(find.text('Importar evento'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventSortKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nome: A–Z'));
    await tester.pumpAndSettle();

    expect(_visibleEventNames(tester), ['Alfa', 'Zeta']);
  });

  testWidgets('keeps empty message away from edges at 200 percent', (
    tester,
  ) async {
    final controller = EventLibraryController(
      repository: InMemoryEventRepository(),
      newId: () => 'event-1',
    );
    await pumpAccessibleApp(
      tester,
      viewport: accessibilityViewports.first,
      textScale: 2,
      home: EventLibraryPage(
        controller: controller,
        createEditorController: (_) => throw UnimplementedError(),
      ),
    );
    await tester.pumpAndSettle();

    final message = tester.getRect(find.text('Nenhum evento ainda'));
    expect(message.left, greaterThanOrEqualTo(16));
    expect(message.right, lessThanOrEqualTo(304));
  });

  testWidgets('creates an event from the library', (tester) async {
    final controller = EventLibraryController(
      repository: InMemoryEventRepository(),
      newId: () => 'event-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(addEventKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(eventNameFieldKey), 'Formatura');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(find.byType(EventListRow), findsOneWidget);
    expect(find.text('Formatura'), findsOneWidget);
  });

  testWidgets('keeps events visible and reports a refresh failure', (
    tester,
  ) async {
    final repository = InMemoryEventRepository([
      SoundTrackEvent.create(id: 'event-1', name: 'Formatura'),
    ]);
    final controller = EventLibraryController(
      repository: repository,
      newId: () => 'event-2',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.findAllError = StateError('offline');

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(find.text('Formatura'), findsOneWidget);
    expect(find.text('Não foi possível atualizar os eventos'), findsOneWidget);
  });

  testWidgets('offers import and reports cancellation', (tester) async {
    final controller = EventLibraryController(
      repository: InMemoryEventRepository(),
      newId: () => 'event-1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
          onImport: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapImport(tester);
    await tester.pumpAndSettle();
    expect(find.text('Importação cancelada'), findsOneWidget);
  });

  testWidgets('routes imported moment without audio to relink', (tester) async {
    final imported = SoundTrackEvent(
      id: 'imported',
      name: 'Imported',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      audioSettings: const EventAudioSettings.defaults(),
      moments: [EventMoment.create(id: 'moment', position: 0, name: 'Opening')],
    );
    final repository = InMemoryEventRepository([imported]);
    final controller = EventLibraryController(
      repository: repository,
      newId: () => 'event-1',
    );
    final transfer = EventTransferController(
      gateway: _Gateway(),
      codec: const EventExportCodec(),
      repository: repository,
      newId: () => 'event-2',
      clock: DateTime.now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
          onImport: () async => imported,
          transferController: transfer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapImport(tester);
    await tester.pumpAndSettle();
    expect(find.text('Localizar músicas'), findsOneWidget);
    expect(find.text('Nenhuma música selecionada'), findsOneWidget);
  });

  testWidgets('running import disables global actions and ignores reentry', (
    tester,
  ) async {
    final repository = InMemoryEventRepository([
      SoundTrackEvent.create(id: 'event-1', name: 'Party'),
    ]);
    final controller = EventLibraryController(
      repository: repository,
      newId: () => 'event-2',
    );
    final imported = Completer<SoundTrackEvent?>();
    var importCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (event) => EventEditorController(
            repository: repository,
            initial: event,
            newId: () => 'moment',
          ),
          onImport: () {
            importCalls++;
            return imported.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapImport(tester);
    await tester.pump();
    expect(importCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byKey(addEventKey)).onPressed,
      isNull,
    );
    final menu = tester.widget(find.byKey(libraryMenuKey)) as PopupMenuButton;
    expect(menu.enabled, isFalse);
    await tester.tap(find.byKey(addEventKey));
    await tester.pump();
    expect(find.text('Novo evento'), findsNothing);
    await tester.tap(find.byType(EventListRow), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Editar evento'), findsNothing);
    expect((await repository.findAll()).length, 1);
    imported.complete(null);
    await tester.pumpAndSettle();
  });

  test('maps typed document failures to actionable Portuguese', () {
    expect(
      eventDocumentErrorMessage(EventImportException.invalidJson),
      contains('Arquivo inválido'),
    );
    expect(
      eventDocumentErrorMessage(EventImportException.unsupportedFormat),
      contains('Formato não reconhecido'),
    );
    expect(
      eventDocumentErrorMessage(EventImportException.unsupportedVersion),
      contains('Versão do arquivo não suportada'),
    );
    expect(
      eventDocumentErrorMessage(
        const DocumentGatewayException('picker_busy', null),
      ),
      contains('seletor de arquivos aberto'),
    );
    expect(
      eventDocumentErrorMessage(
        const DocumentGatewayException('io_error', null),
      ),
      contains('acessar o arquivo'),
    );
  });

  testWidgets('shows the persisted preflight status on each event card', (
    tester,
  ) async {
    final ready = SoundTrackEvent.create(id: 'ready', name: 'Ready');
    final errors = SoundTrackEvent.create(id: 'errors', name: 'Errors');
    final records = _MemoryPreflightRecords([
      PreflightRecord(
        eventId: ready.id,
        checkedAt: DateTime.utc(2026, 7, 1),
        eventUpdatedAt: ready.updatedAt,
        sourceSignature: preflightSourceSignature(ready),
        errorCount: 0,
        warningCount: 0,
      ),
      PreflightRecord(
        eventId: errors.id,
        checkedAt: DateTime.utc(2026, 7, 1),
        eventUpdatedAt: errors.updatedAt,
        sourceSignature: preflightSourceSignature(errors),
        errorCount: 2,
        warningCount: 0,
      ),
    ]);
    final controller = EventLibraryController(
      repository: InMemoryEventRepository([ready, errors]),
      newId: () => 'unused',
      preflightRecords: records,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pronto'), findsOneWidget);
    expect(find.textContaining('Erros'), findsOneWidget);
  });
}

class _Gateway implements DocumentGateway {
  @override
  Future<bool> canRead(String uri) async => true;
  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async => true;
  @override
  Future<String?> openEventJson() async => null;
  @override
  Future<PickedDocument?> pickAudio() async => null;
  @override
  Future<AudioProbeResult> probeAudio(String uri) async =>
      const AudioProbeResult(playable: true);
}

class _MemoryPreflightRecords implements PreflightRecordRepository {
  _MemoryPreflightRecords(Iterable<PreflightRecord> initial)
    : _records = {for (final record in initial) record.eventId: record};

  final Map<String, PreflightRecord> _records;

  @override
  Future<void> delete(String eventId) async => _records.remove(eventId);

  @override
  Future<List<PreflightRecord>> findAll() async =>
      List.unmodifiable(_records.values);

  @override
  Future<PreflightRecord?> findByEventId(String eventId) async =>
      _records[eventId];

  @override
  Future<void> save(PreflightRecord record) async {
    _records[record.eventId] = record;
  }
}

List<String> _visibleEventNames(WidgetTester tester) {
  return tester
      .widgetList<EventListRow>(find.byType(EventListRow))
      .map((row) => row.event.name)
      .toList();
}

Future<void> _tapImport(WidgetTester tester) async {
  await tester.tap(find.byKey(libraryMenuKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Importar evento'));
  await tester.pump(const Duration(milliseconds: 300));
}
