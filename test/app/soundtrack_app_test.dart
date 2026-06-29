import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/soundtrack_app.dart';

void main() {
  testWidgets('opens the event library', (tester) async {
    await tester.pumpWidget(const SoundTrackApp());

    expect(find.text('SoundTrack'), findsOneWidget);
    expect(find.text('Meus Eventos'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
