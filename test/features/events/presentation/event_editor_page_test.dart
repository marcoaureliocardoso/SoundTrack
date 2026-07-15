import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_editor_page.dart';
import 'package:soundtrack/features/events/presentation/moment_editor_page.dart';

import '../../../support/in_memory_event_repository.dart';
import '../../../support/accessibility_test_harness.dart';

void main() {
  for (final testCase in accessibilityTestCases) {
    testWidgets('remains usable at ${accessibilityTestCaseLabel(testCase)}', (
      tester,
    ) async {
      final controller = EventEditorController(
        repository: InMemoryEventRepository(),
        initial: _validEvent(),
        newId: () => 'unused',
      );

      await pumpAccessibleApp(
        tester,
        viewport: testCase.viewport,
        textScale: testCase.textScale,
        home: EventEditorPage(controller: controller),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(momentTileKey('moment-1')), findsOneWidget);
      await tester.drag(
        find.byType(ReorderableListView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(eventAudioSectionKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses the approved structure hierarchy and vocabulary', (
    tester,
  ) async {
    final controller = EventEditorController(
      repository: InMemoryEventRepository(),
      initial: _validEvent(),
      newId: () => 'moment-2',
    );

    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );

    expect(find.text('Editar estrutura'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Salvar'), findsOneWidget);
    expect(find.text('Nome do evento'), findsOneWidget);
    expect(find.text('Momentos'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);
    expect(find.text('Áudio do evento'), findsOneWidget);
    expect(find.text('Master'), findsOneWidget);
    expect(find.text('Música'), findsOneWidget);
    expect(find.text('Música durante a narração'), findsOneWidget);
    expect(find.text('Fade-in'), findsOneWidget);
    expect(find.text('Fade-out'), findsOneWidget);
    expect(find.text('Identificação'), findsNothing);
    expect(find.text('Modo Evento'), findsNothing);
    expect(find.byKey(addMomentKey), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('adds a moment through the full screen editor', (tester) async {
    final controller = EventEditorController(
      repository: InMemoryEventRepository(),
      initial: SoundTrackEvent.create(id: 'event-1', name: 'Formatura'),
      newId: () => 'moment-1',
    );
    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );

    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();

    expect(find.byType(MomentEditorPage), findsOneWidget);
    expect(find.byKey(deleteMomentKey), findsNothing);
    await tester.enterText(find.byKey(momentEditorNameFieldKey), 'Entrada');
    await tester.pump();
    final saveButton = find.descendant(
      of: find.byType(MomentEditorPage),
      matching: find.widgetWithText(TextButton, 'Salvar'),
    );
    expect(tester.widget<TextButton>(saveButton).onPressed, isNotNull);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.byType(MomentEditorPage), findsNothing);
    expect(controller.draft.moments.single.name, 'Entrada');
    expect(find.byType(EventEditorPage), findsOneWidget);
  });

  testWidgets('adds and reorders moments', (tester) async {
    var nextId = 0;
    final controller = EventEditorController(
      repository: InMemoryEventRepository(),
      initial: SoundTrackEvent.create(id: 'event-1', name: 'Formatura'),
      newId: () => 'moment-${++nextId}',
    );

    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );

    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(momentEditorNameFieldKey), 'Entrada');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(momentEditorNameFieldKey), 'Brinde');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(controller.draft.moments.map((moment) => moment.name), [
      'Entrada',
      'Brinde',
    ]);

    final secondMoment = find.byKey(momentTileKey('moment-2'));
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    final secondHandle = find.descendant(
      of: secondMoment,
      matching: find.byIcon(Icons.drag_handle),
    );
    await tester.drag(secondHandle, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(controller.draft.moments.map((moment) => moment.name), [
      'Brinde',
      'Entrada',
    ]);
  });

  testWidgets('does not report a stale save as successful', (tester) async {
    final repository = _BlockingSaveRepository();
    final controller = EventEditorController(
      repository: repository,
      initial: _validEvent(),
      newId: () => 'moment-2',
    )..rename('Formatura atualizada');

    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );

    await tester.tap(find.byTooltip('Salvar'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    expect(
      tester.widget<TextButton>(find.byKey(addMomentKey)).onPressed,
      isNull,
    );

    controller.rename('Alteração concorrente');
    repository.saveCompleter.complete();
    await tester.pumpAndSettle();

    expect(controller.dirty, isTrue);
    expect(find.text('Evento salvo'), findsNothing);
  });

  testWidgets('asks before discarding a dirty event', (tester) async {
    final controller = EventEditorController(
      repository: InMemoryEventRepository(),
      initial: _validEvent(),
      newId: () => 'moment-2',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => EventEditorPage(controller: controller),
              ),
            ),
            child: const Text('Abrir editor'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    controller.rename('Rascunho');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditorPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditorPage), findsNothing);
    expect(find.text('Abrir editor'), findsOneWidget);
  });

  testWidgets('saves an incomplete draft with a moment without audio', (
    tester,
  ) async {
    final repository = InMemoryEventRepository();
    final controller = EventEditorController(
      repository: repository,
      initial: SoundTrackEvent.create(id: 'event-1', name: 'Formatura'),
      newId: () => 'moment-1',
    );

    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );
    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(momentEditorNameFieldKey), 'Entrada');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    final persisted = await repository.findById('event-1');
    expect(persisted?.moments.single.name, 'Entrada');
    expect(persisted?.moments.single.audio, isNull);
    expect(controller.dirty, isFalse);
    expect(find.text('Evento salvo'), findsOneWidget);
  });

  testWidgets('blocks saving an event with an empty name', (tester) async {
    final controller = EventEditorController(
      repository: InMemoryEventRepository(),
      initial: _validEvent(),
      newId: () => 'moment-2',
    )..rename('');

    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );

    expect(find.text('Informe o nome do evento.'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Salvar'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('shows persisted audio as pending after revalidation', (
    tester,
  ) async {
    final event = _validEvent();
    final pendingEvent = event.copyWith(
      moments: [
        event.moments.single.copyWith(
          audio: event.moments.single.audio!.markPending(),
        ),
      ],
    );
    final controller = EventEditorController(
      repository: InMemoryEventRepository([pendingEvent]),
      initial: pendingEvent,
      newId: () => 'unused',
    );

    await tester.pumpWidget(
      MaterialApp(home: EventEditorPage(controller: controller)),
    );

    expect(find.text('Áudio pendente: Entrada.mp3'), findsOneWidget);
    expect(find.text('Repetir em loop'), findsOneWidget);
    expect(find.text('Entrada.mp3 • Loop'), findsNothing);
  });
}

SoundTrackEvent _validEvent() {
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

class _BlockingSaveRepository extends InMemoryEventRepository {
  final saveCompleter = Completer<void>();

  @override
  Future<void> save(SoundTrackEvent event) => saveCompleter.future;
}
