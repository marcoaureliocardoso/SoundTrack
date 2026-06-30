import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';
import 'package:soundtrack/features/playback/presentation/audio_engine_lab_page.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';

void main() {
  testWidgets('selects both sources and drives playback controls', (
    tester,
  ) async {
    final playback = _RecordingPlayback();
    final gateway = _QueueGateway([
      const PickedDocument(uri: 'content://audio/a', displayName: 'a.wav'),
      const PickedDocument(uri: 'content://audio/b', displayName: 'b.wav'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AudioEngineLabPage(playback: playback, documents: gateway),
      ),
    );

    await tester.tap(find.byKey(selectAudioAKey));
    await tester.pump();
    await tester.tap(find.byKey(selectAudioBKey));
    await tester.pump();
    expect(find.textContaining('a.wav'), findsOneWidget);
    expect(find.textContaining('b.wav'), findsOneWidget);

    await tester.tap(find.byKey(loadAudioAKey));
    await tester.pump();
    expect(playback.requests.single.momentId, 'audio-lab-a');
    expect(playback.requests.single.fadeIn, Duration.zero);

    await tester.tap(find.byKey(crossfadeAToBKey));
    await tester.pump();
    expect(playback.requests.last.momentId, 'audio-lab-b');
    expect(playback.requests.last.fadeIn, const Duration(milliseconds: 600));

    await tester.ensureVisible(find.byKey(narrationToggleKey));
    await tester.tap(find.byKey(narrationToggleKey));
    await tester.pump();
    expect(playback.narrationValues, [true]);
  });

  testWidgets('shows live snapshot and last alert without owning playback', (
    tester,
  ) async {
    final playback = _RecordingPlayback();
    await tester.pumpWidget(
      MaterialApp(
        home: AudioEngineLabPage(
          playback: playback,
          documents: _QueueGateway(const []),
        ),
      ),
    );

    playback.snapshotNotifier.value = const PlaybackSnapshot.idle().copyWith(
      phase: PlaybackPhase.playing,
      playing: true,
      activeMomentId: 'audio-lab-a',
    );
    playback.alertController.add(
      const PlaybackAlert(
        PlaybackAlertCode.sourceFailed,
        'source failed',
        momentId: 'audio-lab-b',
      ),
    );
    await tester.pump();

    expect(find.textContaining('playing', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('audio-lab-a', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.textContaining('source failed', skipOffstage: false),
      findsOneWidget,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(playback.disposeCalls, 0);
    expect(playback.alertController.hasListener, isFalse);
  });
}

final class _QueueGateway implements DocumentGateway {
  _QueueGateway(this.documents);

  final List<PickedDocument> documents;
  var index = 0;

  @override
  Future<PickedDocument?> pickAudio() async => documents[index++];

  @override
  Future<bool> canRead(String uri) async => true;

  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async => true;

  @override
  Future<String?> openEventJson() async => null;

  @override
  Future<AudioProbeResult> probeAudio(String uri) async =>
      const AudioProbeResult(playable: true);
}

final class _RecordingPlayback implements LivePlaybackPort {
  final snapshotNotifier = ValueNotifier<PlaybackSnapshot>(
    const PlaybackSnapshot.idle(),
  );
  final alertController = StreamController<PlaybackAlert>.broadcast();
  final requests = <MomentPlaybackRequest>[];
  final narrationValues = <bool>[];
  var disposeCalls = 0;

  @override
  ValueListenable<PlaybackSnapshot> get snapshot => snapshotNotifier;

  @override
  Stream<PlaybackAlert> get alerts => alertController.stream;

  @override
  Future<void> startMoment(MomentPlaybackRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> setNarration(bool active) async {
    narrationValues.add(active);
  }

  @override
  Future<void> setSessionVolumes({
    required double masterVolume,
    required double musicVolume,
    required double narrationVolume,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> restorePresetVolumes() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
