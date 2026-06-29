import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/application/event_library_controller.dart';
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
}
