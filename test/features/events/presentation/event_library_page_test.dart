import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/application/event_transfer_controller.dart';
import 'package:soundtrack/features/events/data/event_export_codec.dart';
import 'package:soundtrack/features/events/domain/event_audio_settings.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/widgets/event_card.dart';
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
