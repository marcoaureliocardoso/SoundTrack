import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/live/presentation/live_dashboard_keys.dart';
import 'package:soundtrack/features/live/presentation/widgets/playback_controls.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  testWidgets('renders four aligned actions with 48 dp targets at 200%', (
    tester,
  ) async {
    await tester.pumpWidget(_controls(textScale: 2));

    final keys = [
      pausePlaybackKey,
      stopPlaybackKey,
      narrationKey,
      volumesToggleKey,
    ];
    for (final key in keys) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final centers = keys
        .map((key) => tester.getCenter(find.byKey(key)))
        .toList();
    expect(centers.map((center) => center.dy).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('volumes is independent and exposes selected semantics', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _controls(volumesExpanded: true, onVolumesToggle: () => toggles++),
    );

    final semantics = tester
        .getSemantics(find.byKey(volumesToggleKey))
        .getSemanticsData();
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);

    await tester.tap(find.byKey(volumesToggleKey));
    await tester.pump();

    expect(toggles, 1);
  });
}

Widget _controls({
  double textScale = 1,
  bool volumesExpanded = false,
  VoidCallback? onVolumesToggle,
}) {
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
              volumesExpanded: volumesExpanded,
              onPause: _noop,
              onResume: _noop,
              onStop: _noop,
              onNarrationChanged: (_) async {},
              onVolumesToggle: onVolumesToggle ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _noop() async {}
