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
    expect(
      tester.getSemantics(find.byType(MomentActionButton)).label,
      contains(fileName),
    );
  });

  testWidgets('uses one accessible foreground for every ready moment label', (
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
            status: MomentStatus.ready,
            onPressed: () {},
          ),
        ),
      ),
    );

    for (final label in [
      '1',
      moment.name,
      moment.audio!.displayName,
      'TOQUE PARA INICIAR',
    ]) {
      expect(
        tester.widget<Text>(find.text(label)).style?.color,
        theme.colorScheme.onPrimary,
      );
    }
    expect(
      contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('uses accessible colors for every unavailable moment state', (
    tester,
  ) async {
    final theme = _darkTheme();
    final colors = theme.colorScheme;
    final moment = _momentWithAudio();
    final cases = [
      (
        status: MomentStatus.current,
        commandEnabled: true,
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
        statusText: 'ATUAL',
      ),
      (
        status: MomentStatus.pending,
        commandEnabled: true,
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
        statusText: 'ÁUDIO PENDENTE',
      ),
      (
        status: MomentStatus.error,
        commandEnabled: true,
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
        statusText: 'ERRO NO ÁUDIO',
      ),
      (
        status: MomentStatus.ready,
        commandEnabled: false,
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
        statusText: 'TOQUE PARA INICIAR',
      ),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: MomentActionButton(
              number: 1,
              moment: moment,
              status: testCase.status,
              commandEnabled: testCase.commandEnabled,
              onPressed: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.style?.backgroundColor?.resolve({WidgetState.disabled}),
        testCase.background,
      );
      expect(
        button.style?.foregroundColor?.resolve({WidgetState.disabled}),
        testCase.foreground,
      );
      for (final label in [
        '1',
        moment.name,
        moment.audio!.displayName,
        testCase.statusText,
      ]) {
        expect(
          tester.widget<Text>(find.text(label)).style?.color,
          testCase.foreground,
        );
      }
      expect(
        contrastRatio(testCase.foreground, testCase.background),
        greaterThanOrEqualTo(4.5),
      );
    }
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
