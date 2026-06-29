import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_editor_controller.dart';
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

    await tester.drag(
      find.byKey(momentTileKey('moment-2')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(controller.draft.moments.map((moment) => moment.name), [
      'Brinde',
      'Entrada',
    ]);
  });
}
