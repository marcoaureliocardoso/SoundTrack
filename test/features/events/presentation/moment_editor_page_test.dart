import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/events/presentation/moment_editor_page.dart';

import '../../../support/accessibility_test_harness.dart';

void main() {
  for (final testCase in accessibilityTestCases) {
    testWidgets(
      'keeps audio and controls reachable at ${accessibilityTestCaseLabel(testCase)}',
      (tester) async {
        await pumpAccessibleApp(
          tester,
          viewport: testCase.viewport,
          textScale: testCase.textScale,
          home: MomentEditorPage(
            moment: _momentWithLongAudio(),
            onSave: (_) {},
            onDelete: () {},
          ),
        );

        expect(find.text('Salvar'), findsOneWidget);
        expect(find.text('Concluir'), findsNothing);
        expect(find.text('Conteúdo'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.byKey(momentAudioActionKey),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        final actionRect = tester.getRect(find.byKey(momentAudioActionKey));
        expect(actionRect.right, lessThanOrEqualTo(testCase.viewport.width));
        expect(actionRect.height, greaterThanOrEqualTo(48));
        await tester.scrollUntilVisible(
          find.text('Repetir em loop'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byIcon(Icons.loop), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Volume da faixa'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Volume da faixa'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('uses the approved narration vocabulary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MomentEditorPage(moment: _momentWithLongAudio(), onSave: (_) {}),
      ),
    );

    expect(find.text('Disponibilizar Narração'), findsOneWidget);
    expect(
      find.text('Mostra o botão Narração no Dashboard deste momento'),
      findsOneWidget,
    );
  });

  testWidgets('saves a trimmed draft and returns once', (tester) async {
    EventMoment? saved;
    await _openEditor(
      tester,
      moment: EventMoment.create(id: 'moment-1', position: 0, name: 'Entrada'),
      onSave: (moment) => saved = moment,
    );

    await tester.enterText(find.byKey(momentEditorNameFieldKey), '  Brinde  ');
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(saved?.name, 'Brinde');
    expect(find.byType(MomentEditorPage), findsNothing);
    expect(find.text('Estrutura host'), findsOneWidget);
  });

  testWidgets('prevents audio picker reentry and reports failure', (
    tester,
  ) async {
    final selection = Completer<AudioReference?>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MomentEditorPage(
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
    );

    await tester.tap(find.byKey(momentAudioActionKey));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(momentAudioActionKey), warnIfMissed: false);
    expect(calls, 1);

    selection.completeError(StateError('picker unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível selecionar o áudio'), findsOneWidget);
  });

  testWidgets('saves exclusive end behavior, narration and track volume', (
    tester,
  ) async {
    EventMoment? saved;
    await _openEditor(
      tester,
      moment: EventMoment.create(id: 'moment-1', position: 0, name: 'Entrada'),
      onSave: (moment) => saved = moment,
    );

    await tester.tap(find.text('Parar'));
    await tester.tap(find.byType(Switch));
    final gainSlider = tester.widget<Slider>(find.byKey(momentGainSliderKey));
    gainSlider.onChanged!(6);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(saved?.endBehavior, EndBehavior.stop);
    expect(saved?.narrationEnabled, isTrue);
    expect(saved!.gainDb, greaterThan(0));
  });

  testWidgets('deletes only after confirmation and explains file retention', (
    tester,
  ) async {
    var deletes = 0;
    await _openEditor(
      tester,
      moment: _momentWithLongAudio(),
      onSave: (_) {},
      onDelete: () => deletes++,
    );
    await tester.scrollUntilVisible(
      find.byKey(deleteMomentKey),
      220,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(deleteMomentKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('arquivo no dispositivo não será excluído'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deletes, 0);
    expect(find.byType(MomentEditorPage), findsOneWidget);

    await tester.tap(find.byKey(deleteMomentKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byType(MomentEditorPage), findsNothing);
  });

  testWidgets('new moment draft does not expose deletion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MomentEditorPage(
          moment: EventMoment.create(id: 'moment-new', position: 0, name: ''),
          onSave: (_) {},
        ),
      ),
    );

    expect(find.byKey(deleteMomentKey), findsNothing);
  });
}

EventMoment _momentWithLongAudio() {
  return EventMoment.create(
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
}

Future<void> _openEditor(
  WidgetTester tester, {
  required EventMoment moment,
  required ValueChanged<EventMoment> onSave,
  VoidCallback? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MomentEditorPage(
                  moment: moment,
                  onSave: onSave,
                  onDelete: onDelete,
                ),
              ),
            ),
            child: const Text('Estrutura host'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Estrutura host'));
  await tester.pumpAndSettle();
}
