import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_editor_page.dart';

import '../../../support/in_memory_event_repository.dart';

void main() {
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

    final unavailableModeButton = find.widgetWithText(
      FilledButton,
      'Disponível após instalar o motor de áudio',
    );
    expect(unavailableModeButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(unavailableModeButton).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(momentNameFieldKey), 'Entrada');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(addMomentKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(momentNameFieldKey), 'Brinde');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(controller.draft.moments.map((moment) => moment.name), [
      'Entrada',
      'Brinde',
    ]);

    final secondMoment = find.byKey(momentTileKey('moment-2'));
    await tester.drag(
      find.byType(ReorderableListView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.drag(secondMoment, const Offset(0, -200));
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
      tester.widget<FloatingActionButton>(find.byKey(addMomentKey)).onPressed,
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
