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
import 'package:soundtrack/features/events/presentation/widgets/event_card.dart';
import 'package:soundtrack/features/live/application/preflight_record_repository.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
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

    expect(find.byType(EventCard), findsOneWidget);
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
    await tester.tap(find.text('Importar'));
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
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Localizar músicas'), findsOneWidget);
    expect(find.text('Nenhuma música selecionada'), findsOneWidget);
  });

  testWidgets('document operation blocks import and export reentry', (
    tester,
  ) async {
    final repository = InMemoryEventRepository([
      SoundTrackEvent.create(id: 'event-1', name: 'Party'),
    ]);
    final controller = EventLibraryController(
      repository: repository,
      newId: () => 'event-2',
    );
    final export = Completer<bool>();
    var importCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: controller,
          createEditorController: (_) => throw UnimplementedError(),
          onExport: (_) => export.future,
          onImport: () async {
            importCalls++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<EventCardAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final importButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Importar'),
    );
    expect(importButton.onPressed, isNull);
    expect(importCalls, 0);

    export.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Evento exportado'), findsOneWidget);
  });

  testWidgets('running import disables export and ignores import reentry', (
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
          onExport: (_) async => true,
          onImport: () {
            importCalls++;
            return imported.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pump();
    expect(importCalls, 1);
    expect(
      tester.widget<EventCard>(find.byType(EventCard)).exportEnabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Importar'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(addEventKey));
    await tester.pump();
    expect(find.text('Novo evento'), findsNothing);
    await tester.tap(find.byType(EventCard), warnIfMissed: false);
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
        errorCount: 0,
        warningCount: 0,
      ),
      PreflightRecord(
        eventId: errors.id,
        checkedAt: DateTime.utc(2026, 7, 1),
        eventUpdatedAt: errors.updatedAt,
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
