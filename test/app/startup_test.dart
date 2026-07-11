import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/main.dart' as app;

import '../support/fake_live_playback_port.dart';

void main() {
  testWidgets(
    'dependency startup failure disposes audio and shows a safe error',
    (tester) async {
      final playback = FakeLivePlaybackPort();

      final root = await app.initializeSoundTrackApp(
        initializeAudio: () async => playback,
        createDependencies: (LivePlaybackPort _) async {
          throw StateError('private storage path');
        },
      );
      await tester.pumpWidget(root);

      expect(playback.disposeCalls, 1);
      expect(
        find.text('Não foi possível iniciar o SoundTrack.'),
        findsOneWidget,
      );
      expect(find.textContaining('private storage path'), findsNothing);
    },
  );

  testWidgets('audio startup failure shows the same safe error', (
    tester,
  ) async {
    final root = await app.initializeSoundTrackApp(
      initializeAudio: () async => throw StateError('platform secret'),
      createDependencies: (LivePlaybackPort _) async {
        throw UnimplementedError();
      },
    );
    await tester.pumpWidget(root);

    expect(find.text('Não foi possível iniciar o SoundTrack.'), findsOneWidget);
    expect(find.textContaining('platform secret'), findsNothing);
  });
}
