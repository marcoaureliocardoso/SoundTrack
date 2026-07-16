import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_keys.dart';
import 'package:soundtrack/features/live/presentation/widgets/playback_controls.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  testWidgets(
    'renders three non-overlapping zones with 48 dp targets at 200%',
    (tester) async {
      await tester.pumpWidget(_controls(textScale: 2));

      final keys = [pausePlaybackKey, stopPlaybackKey, narrationKey];
      for (final key in keys) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(find.byKey(volumesToggleKey), findsNothing);
      final pause = tester.getRect(find.byKey(pausePlaybackKey));
      final stop = tester.getRect(find.byKey(stopPlaybackKey));
      final narration = tester.getRect(find.byKey(narrationKey));
      expect(narration.width, greaterThan(pause.width));
      expect(pause.overlaps(stop), isFalse);
      expect(stop.overlaps(narration), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _controls({double textScale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 320,
            child: PlaybackControls(
              playback: const PlaybackSnapshot.idle(),
              narrationAvailable: false,
              onPause: _noop,
              onResume: _noop,
              onStop: _noop,
              onNarrationChanged: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _noop() async {}
