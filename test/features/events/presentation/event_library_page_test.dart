import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
import 'package:soundtrack/features/events/domain/soundtrack_event.dart';
import 'package:soundtrack/features/events/presentation/event_library_page.dart';
import 'package:soundtrack/features/events/presentation/widgets/event_card.dart';

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
}
