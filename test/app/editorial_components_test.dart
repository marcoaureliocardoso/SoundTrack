import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/app/theme/soundtrack_theme.dart';
import 'package:soundtrack/app/widgets/editorial_components.dart';

void main() {
  testWidgets('operational row has semantics and a 48 dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSoundTrackTheme(),
        home: Scaffold(
          body: OperationalActionRow(
            icon: Icons.play_arrow,
            title: 'Preparar Modo Evento',
            description: 'Revisar áudios antes de iniciar',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(OperationalActionRow)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSemantics(find.byType(OperationalActionRow)).label,
      contains('Preparar Modo Evento'),
    );
    semantics.dispose();
  });

  testWidgets('section header keeps its action reachable at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSoundTrackTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: EditorialSectionHeader(
              title: 'Momentos do evento',
              actionLabel: 'Adicionar',
              onAction: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Adicionar')).height,
      greaterThanOrEqualTo(SoundTrackTokens.targetMinSize),
    );
  });

  testWidgets('status combines icon and label instead of color alone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSoundTrackTheme(),
        home: const Scaffold(
          body: StatusIndicator.warning(label: 'Áudio pendente'),
        ),
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Áudio pendente'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(StatusIndicator)).label,
      contains('Áudio pendente'),
    );
    semantics.dispose();
  });

  testWidgets('labeled volume control exposes context and changes value', (
    tester,
  ) async {
    double? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSoundTrackTheme(),
        home: Scaffold(
          body: LabeledVolumeControl(
            label: 'Master',
            description: 'Limite geral da saída do aplicativo',
            value: 0.5,
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    expect(find.text('Master'), findsOneWidget);
    expect(find.text('Limite geral da saída do aplicativo'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    expect(changedValue, isNotNull);
  });
}
