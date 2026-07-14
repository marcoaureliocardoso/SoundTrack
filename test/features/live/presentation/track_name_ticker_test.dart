import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/live/presentation/widgets/track_name_ticker.dart';

void main() {
  const longTrack =
      'Abertura oficial - versão instrumental definitiva para a solenidade.mp3';

  testWidgets('short track stays at the start without animation', (
    tester,
  ) async {
    await tester.pumpWidget(_ticker(text: 'entrada.mp3'));

    await tester.pump(const Duration(seconds: 10));

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.controller!.offset, 0);
    expect(tester.takeException(), isNull);
    await _disposeTicker(tester);
  });

  testWidgets(
    'long track pauses, scrolls, then resets without reverse travel',
    (tester) async {
      await tester.pumpWidget(_ticker(text: longTrack));
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      await tester.pump(const Duration(milliseconds: 1990));
      expect(scroll.controller!.offset, 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(scroll.controller!.offset, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.controller!.offset, greaterThan(0));
      final fullScrollDuration = Duration(
        milliseconds: scroll.controller!.position.maxScrollExtent.ceil(),
      );
      await tester.pump(fullScrollDuration);
      expect(scroll.controller!.offset, greaterThan(0));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.controller!.offset, 0);

      await _disposeTicker(tester);
    },
  );

  testWidgets('reduced animations keep overflow static with ellipsis', (
    tester,
  ) async {
    await tester.pumpWidget(_ticker(text: longTrack, disableAnimations: true));

    await tester.pump(const Duration(seconds: 10));

    expect(find.byType(SingleChildScrollView), findsNothing);
    final text = tester.widget<Text>(find.text(longTrack));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    await _disposeTicker(tester);
  });

  testWidgets('long track exposes one complete semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_ticker(text: longTrack));

    expect(find.bySemanticsLabel(longTrack), findsOneWidget);

    await _disposeTicker(tester);
    semantics.dispose();
  });
}

Widget _ticker({required String text, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(
        child: SizedBox(
          width: 180,
          child: TrackNameTicker(
            text: text,
            initialPause: const Duration(seconds: 2),
            endPause: const Duration(seconds: 1),
            startHold: const Duration(seconds: 3),
            resetFade: const Duration(milliseconds: 100),
            pixelsPerSecond: 1000,
          ),
        ),
      ),
    ),
  );
}

Future<void> _disposeTicker(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
