import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/soundtrack_app.dart';

void main() {
  testWidgets('opens the event library', (tester) async {
    await tester.pumpWidget(const SoundTrackApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final floatingActionButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    final eventLibraryContext = tester.element(find.text('Meus Eventos'));

    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(Theme.of(eventLibraryContext).brightness, Brightness.dark);
    expect(
      appBar.title,
      isA<Text>().having((title) => title.data, 'data', 'SoundTrack'),
    );
    expect(find.text('Meus Eventos'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(floatingActionButton.onPressed, isNull);
  });
}
