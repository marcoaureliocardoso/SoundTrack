import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundtrack/app/app_dependencies.dart';
import 'package:soundtrack/app/soundtrack_app.dart';
import 'package:soundtrack/features/events/presentation/event_editor_page.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/moment_editor_page.dart';
import 'package:soundtrack/features/events/presentation/event_overview_page.dart';
import 'package:soundtrack/features/events/presentation/widgets/event_list_row.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

import '../test/support/in_memory_event_repository.dart';
import '../test/support/fake_live_playback_port.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates, exports, imports and relinks through composed UI', (
    tester,
  ) async {
    final gateway = _FlowGateway();
    var eventId = 0;
    var momentId = 0;
    await tester.pumpWidget(
      SoundTrackApp(
        dependencies: AppDependencies(
          eventRepository: InMemoryEventRepository(),
          newEventId: () => 'event-${++eventId}',
          newMomentId: () => 'moment-${++momentId}',
          playback: FakeLivePlaybackPort(),
          documentGateway: gateway,
          clock: () => DateTime.utc(2026, 6, 29),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(addEventKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(eventNameFieldKey), 'Casamento');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EventListRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(editEventStructureKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(momentEditorNameFieldKey), 'Entrada');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(eventOverviewMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar'));
    await tester.pumpAndSettle();
    expect(gateway.exportedContents, isNotNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(libraryMenuKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar evento'));
    await tester.pumpAndSettle();
    expect(find.text('Áudios pendentes'), findsOneWidget);
    expect(find.text('Nenhum arquivo selecionado'), findsOneWidget);

    await tester.tap(find.text('Selecionar'));
    await tester.pumpAndSettle();
    expect(find.text('Todas as músicas foram localizadas.'), findsOneWidget);
    expect(find.text('Voltar ao evento'), findsOneWidget);
  });
}

class _FlowGateway implements DocumentGateway {
  String? exportedContents;

  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async {
    exportedContents = contents;
    return true;
  }

  @override
  Future<String?> openEventJson() async => exportedContents;

  @override
  Future<bool> canRead(String uri) async => false;

  @override
  Future<PickedDocument?> pickAudio() async => const PickedDocument(
    uri: 'content://replacement',
    displayName: 'entrada.mp3',
  );

  @override
  Future<AudioProbeResult> probeAudio(String uri) async =>
      const AudioProbeResult(
        playable: true,
        artist: 'Local Band',
        duration: Duration(minutes: 4),
      );
}
