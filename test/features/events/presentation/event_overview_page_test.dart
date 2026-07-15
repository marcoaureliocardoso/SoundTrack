import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_editor_page.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/event_overview_page.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
  testWidgets('event row opens context instead of editor', (tester) async {
    final fixture = await _fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: EventLibraryPage(
          controller: fixture.controller,
          createEditorController: (event) => EventEditorController(
            repository: fixture.repository,
            initial: event,
            newId: () => 'moment-new',
          ),
          buildLiveEntryPage: (event) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jaleco'));
    await tester.pumpAndSettle();

    expect(find.byType(EventOverviewPage), findsOneWidget);
    expect(find.text('Jaleco'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Editar estrutura'), findsOneWidget);
    expect(find.text('Preparar Modo Evento'), findsOneWidget);
    expect(find.text('Editar evento'), findsNothing);
    expect(find.text('Evento'), findsNothing);
  });

  testWidgets('exports, renames and duplicates the current event snapshot', (
    tester,
  ) async {
    final fixture = await _fixture();
    SoundTrackEvent? exported;
    await _openOverview(
      tester,
      fixture,
      onExport: (event) async {
        exported = event;
        return true;
      },
    );

    await _selectOverviewAction(tester, 'Exportar');
    expect(exported?.name, 'Jaleco');
    expect(find.text('Evento exportado'), findsOneWidget);

    await _selectOverviewAction(tester, 'Renomear');
    await tester.enterText(find.byKey(eventOverviewNameFieldKey), 'Formatura');
    await tester.tap(find.widgetWithText(FilledButton, 'Renomear'));
    await tester.pumpAndSettle();
    expect(find.text('Formatura'), findsOneWidget);
    expect(find.text('Jaleco'), findsNothing);

    await _selectOverviewAction(tester, 'Duplicar');
    await tester.pumpAndSettle();
    expect(fixture.controller.events, hasLength(2));
    expect(find.byType(EventOverviewPage), findsOneWidget);
  });

  testWidgets('delete only pops the context after explicit confirmation', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _openOverview(tester, fixture);

    await _selectOverviewAction(tester, 'Excluir');
    expect(find.byType(EventOverviewPage), findsOneWidget);
    expect(find.text('Excluir evento?'), findsOneWidget);
    expect(find.textContaining('“Jaleco”'), findsOneWidget);
    expect(find.textContaining('estrutura será removida'), findsOneWidget);
    expect(await fixture.repository.findById(fixture.event.id), isNotNull);

    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.byType(EventOverviewPage), findsNothing);
    expect(find.text('Biblioteca host'), findsOneWidget);
    expect(await fixture.repository.findById(fixture.event.id), isNull);
  });

  testWidgets('prepare mode pushes verification without starting a moment', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _openOverview(
      tester,
      fixture,
      buildLiveEntryPage: (event) =>
          Scaffold(body: Text('Verificação de ${event.name}')),
    );

    await tester.tap(find.byKey(prepareLiveEventKey));
    await tester.pumpAndSettle();

    expect(find.text('Verificação de Jaleco'), findsOneWidget);
  });

  testWidgets('audio adjustment opens structure positioned at event audio', (
    tester,
  ) async {
    final fixture = await _fixture();
    await _openOverview(tester, fixture);
    await tester.scrollUntilVisible(
      find.byKey(adjustEventAudioKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(adjustEventAudioKey));
    await tester.pumpAndSettle();

    expect(find.byType(EventEditorPage), findsOneWidget);
    expect(find.byKey(eventAudioSectionKey), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(eventAudioSectionKey)).dy,
      lessThan(180),
    );
  });
}

typedef _Fixture = ({
  InMemoryEventRepository repository,
  EventLibraryController controller,
  SoundTrackEvent event,
});

Future<_Fixture> _fixture() async {
  final event = SoundTrackEvent.create(id: 'event-1', name: 'Jaleco').copyWith(
    updatedAt: DateTime.utc(2026, 7, 15),
    moments: [EventMoment.create(id: 'moment-1', position: 0, name: 'Entrada')],
  );
  final repository = InMemoryEventRepository([event]);
  final controller = EventLibraryController(
    repository: repository,
    newId: () => 'event-copy',
  );
  await controller.load();
  return (repository: repository, controller: controller, event: event);
}

Future<void> _openOverview(
  WidgetTester tester,
  _Fixture fixture, {
  Future<bool> Function(SoundTrackEvent event)? onExport,
  Widget Function(SoundTrackEvent event)? buildLiveEntryPage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open-overview'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => EventOverviewPage(
                  eventId: fixture.event.id,
                  libraryController: fixture.controller,
                  createEditorController: (event) => EventEditorController(
                    repository: fixture.repository,
                    initial: event,
                    newId: () => 'moment-new',
                  ),
                  onExport: onExport,
                  buildLiveEntryPage: buildLiveEntryPage,
                ),
              ),
            ),
            child: const Text('Biblioteca host'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-overview')));
  await tester.pumpAndSettle();
}

Future<void> _selectOverviewAction(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(eventOverviewMenuKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
