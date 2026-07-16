import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/events/domain/audio_reference.dart';
import 'package:soundtrack/features/events/domain/event_moment.dart';
import 'package:soundtrack/features/live/application/live_event_state.dart';
import 'package:soundtrack/features/live/presentation/widgets/moment_action_button.dart';

import '../../../support/color_contrast.dart';

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
    expect(find.byType(FilledButton), findsNothing);
    expect(
      tester.getSize(find.byType(MomentActionButton)).height,
      greaterThanOrEqualTo(64),
    );
    expect(
      tester.getSemantics(find.byType(MomentActionButton)).label,
      contains(fileName),
    );
  });

  testWidgets('whole ready row is tappable and unavailable rows are disabled', (
    tester,
  ) async {
    final moment = _momentWithAudio();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentActionButton(
            number: 1,
            moment: moment,
            status: MomentStatus.ready,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MomentActionButton));
    expect(taps, 1);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MomentActionButton(
            number: 1,
            moment: moment,
            status: MomentStatus.pending,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });

  testWidgets('current row exposes selection and an accessible accent', (
    tester,
  ) async {
    final theme = _darkTheme();
    final moment = _momentWithAudio();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MomentActionButton(
            number: 1,
            moment: moment,
            status: MomentStatus.current,
            onPressed: () {},
          ),
        ),
      ),
    );

    final semantics = tester
        .getSemantics(find.byType(MomentActionButton))
        .getSemanticsData();
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    final stripe = tester.widget<DecoratedBox>(
      find.byKey(momentStatusStripeKey(moment.id)),
    );
    final border = (stripe.decoration as BoxDecoration).border! as Border;
    expect(border.left.width, greaterThanOrEqualTo(3));
    expect(
      contrastRatio(
        theme.colorScheme.primary,
        theme.colorScheme.surfaceContainerHigh,
      ),
      greaterThanOrEqualTo(3),
    );
  });
}

ThemeData _darkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}

EventMoment _momentWithAudio() {
  return EventMoment.create(
    id: 'moment',
    position: 0,
    name: 'Momento',
  ).copyWith(
    audio: const AudioReference(
      uri: 'content://track',
      displayName: 'faixa.mp3',
      pending: false,
      artist: null,
      duration: null,
    ),
  );
}
