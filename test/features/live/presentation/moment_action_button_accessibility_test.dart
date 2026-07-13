import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/live/application/live_event_state.dart';
import 'package:soundtrack/features/live/presentation/widgets/moment_action_button.dart';

void main() {
  testWidgets('bounds long moment and file names without losing semantics', (
    tester,
  ) async {
    const fileName =
        'arquivo-de-musica-com-um-nome-extremamente-longo-para-evento.mp3';
    const momentName =
        'Momento com um nome principal muito longo para ocupar duas linhas';
    final moment =
        EventMoment.create(
          id: 'moment',
          position: 0,
          name: momentName,
        ).copyWith(
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
          body: MomentActionButton(
            number: 1,
            moment: moment,
            status: MomentStatus.ready,
            onPressed: () {},
          ),
        ),
      ),
    );

    final momentText = tester.widget<Text>(find.text(momentName));
    final fileText = tester.widget<Text>(find.text(fileName));
    expect(momentText.maxLines, 2);
    expect(momentText.overflow, TextOverflow.ellipsis);
    expect(fileText.maxLines, 1);
    expect(fileText.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSemantics(find.byType(MomentActionButton)).label,
      contains(fileName),
    );
  });
}
