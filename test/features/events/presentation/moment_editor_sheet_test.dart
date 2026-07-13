import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/presentation/moment_editor_sheet.dart';

import '../../../support/accessibility_test_harness.dart';

void main() {
  testWidgets('keeps long audio and controls reachable at 200 percent', (
    tester,
  ) async {
    final moment =
        EventMoment.create(
          id: 'moment-1',
          position: 0,
          name: 'Entrada',
        ).copyWith(
          audio: const AudioReference(
            uri: 'content://track',
            displayName:
                'arquivo-de-musica-com-um-nome-extremamente-longo-para-evento.mp3',
            pending: false,
            artist: null,
            duration: null,
          ),
        );

    await pumpAccessibleApp(
      tester,
      viewport: accessibilityViewports.first,
      textScale: 2,
      home: Scaffold(
        body: MomentEditorSheet(moment: moment, onSave: (_) {}),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Concluir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports audio selection failure and prevents reentry', (
    tester,
  ) async {
    final selection = Completer<Never>();
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentEditorSheet(
            moment: EventMoment.create(
              id: 'moment-1',
              position: 0,
              name: 'Entrada',
            ),
            onSelectAudio: () {
              calls++;
              return selection.future;
            },
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Selecionar áudio'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(OutlinedButton));
    expect(calls, 1);

    selection.completeError(StateError('picker unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível selecionar o áudio'), findsOneWidget);
  });
}
