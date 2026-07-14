import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/live/presentation/widgets/emergency_volume_panel.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';

void main() {
  testWidgets('shows all emergency controls without an expansion tile', (
    tester,
  ) async {
    await tester.pumpWidget(_panel());

    expect(find.text('Volumes de emergência'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.text('Restaurar predefinições'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgets('keeps queued volume state while the panel is offstage', (
    tester,
  ) async {
    final releaseFirst = Completer<void>();
    final calls = <({double master, double music, double narration})>[];
    var visible = true;
    late StateSetter setHarnessState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHarnessState = setState;
            return Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() => visible = !visible),
                    child: const Text('Alternar'),
                  ),
                  Expanded(
                    child: Offstage(
                      offstage: !visible,
                      child: EmergencyVolumePanel(
                        key: const Key('persistent-volume-panel'),
                        playback: const PlaybackSnapshot.idle(),
                        onVolumesChanged:
                            ({
                              required masterVolume,
                              required musicVolume,
                              required narrationVolume,
                            }) {
                              calls.add((
                                master: masterVolume,
                                music: musicVolume,
                                narration: narrationVolume,
                              ));
                              return calls.length == 1
                                  ? releaseFirst.future
                                  : Future<void>.value();
                            },
                        onRestore: () async {},
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(20);
    await tester.pump();
    expect(calls, hasLength(1));

    setHarnessState(() => visible = false);
    await tester.pump();
    expect(find.byType(Slider), findsNothing);
    setHarnessState(() => visible = true);
    await tester.pump();
    tester.widgetList<Slider>(find.byType(Slider)).elementAt(1).onChanged!(40);
    await tester.pump();
    expect(calls, hasLength(1));

    releaseFirst.complete();
    await tester.pumpAndSettle();

    expect(calls, hasLength(2));
    expect(calls.last.master, .2);
    expect(calls.last.music, .4);
    expect(calls.last.narration, .25);
  });
}

Widget _panel() {
  return MaterialApp(
    home: Scaffold(
      body: EmergencyVolumePanel(
        playback: const PlaybackSnapshot.idle(),
        onVolumesChanged:
            ({
              required masterVolume,
              required musicVolume,
              required narrationVolume,
            }) async {},
        onRestore: () async {},
      ),
    ),
  );
}
