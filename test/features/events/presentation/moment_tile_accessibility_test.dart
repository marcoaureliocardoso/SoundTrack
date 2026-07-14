import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/presentation/widgets/moment_tile.dart';

void main() {
  testWidgets('keeps file and playback metadata in separate bounded lines', (
    tester,
  ) async {
    const fileName =
        'arquivo-de-musica-com-um-nome-extremamente-longo-para-evento.mp3';
    final moment =
        EventMoment.create(
          id: 'moment',
          position: 0,
          name: 'Entrada dos formandos',
        ).copyWith(
          narrationEnabled: true,
          audio: const AudioReference(
            uri: 'content://track',
            displayName: fileName,
            pending: false,
            artist: null,
            duration: null,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentTile(moment: moment, onEdit: () {}, onDelete: () {}),
        ),
      ),
    );

    final fileText = tester.widget<Text>(find.text(fileName));
    expect(fileText.maxLines, 1);
    expect(fileText.overflow, TextOverflow.ellipsis);
    expect(find.text('Loop • Narração'), findsOneWidget);
  });
}
