import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:soundtrack/features/playback/application/live_playback_port.dart';
import 'package:soundtrack/features/playback/domain/playback_alert.dart';
import 'package:soundtrack/features/playback/domain/playback_snapshot.dart';
import 'package:soundtrack/features/playback/infrastructure/audio_engine_factory.dart';
import 'package:soundtrack/features/playback/infrastructure/soundtrack_audio_handler.dart';
import 'package:soundtrack/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Directory? fixtureDirectory;
  late File audioA;
  late File audioB;
  SoundTrackAudioHandler? playbackOwner;

  setUpAll(() async {
    fixtureDirectory = await Directory(
      '${(await getTemporaryDirectory()).path}'
      '${Platform.pathSeparator}audio-engine-flow',
    ).create(recursive: true);
    audioA = await _writeWave(
      File('${fixtureDirectory!.path}${Platform.pathSeparator}a.wav'),
      frequencyHz: 440,
    );
    audioB = await _writeWave(
      File('${fixtureDirectory!.path}${Platform.pathSeparator}b.wav'),
      frequencyHz: 660,
    );
    final prepared = await AudioEngineFactory().prepareHandler();
    try {
      playbackOwner = await AudioService.init<SoundTrackAudioHandler>(
        builder: () => prepared,
        config: soundTrackAudioServiceConfig,
      );
    } on Object {
      await prepared.dispose();
      rethrow;
    }
  });

  tearDown(() async {
    await playbackOwner?.stop();
  });

  tearDownAll(() async {
    try {
      await playbackOwner?.stop();
      await playbackOwner?.dispose();
    } finally {
      final directory = fixtureDirectory;
      if (directory != null && directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    }
  });

  testWidgets(
    'real engine plays first source, crossfades, preserves active on failure, '
    'toggles narration and stops',
    (_) async {
      final playback = playbackOwner!;
      final observed = <PlaybackSnapshot>[];
      final alerts = <PlaybackAlert>[];
      void recordSnapshot() => observed.add(playback.snapshot.value);

      playback.snapshot.addListener(recordSnapshot);
      final alertSubscription = playback.alerts.listen(alerts.add);
      try {
        await playback.startMoment(_request('a', audioA.uri));
        expect(playback.snapshot.value.phase, PlaybackPhase.playing);
        expect(playback.snapshot.value.activeMomentId, 'a');

        observed.clear();
        await playback.startMoment(_request('b', audioB.uri));
        final loading = observed.indexWhere(
          (snapshot) => snapshot.phase == PlaybackPhase.loading,
        );
        final transitioning = observed.indexWhere(
          (snapshot) => snapshot.phase == PlaybackPhase.transitioning,
        );
        final endpoint = observed.lastIndexWhere(
          (snapshot) =>
              snapshot.phase == PlaybackPhase.playing &&
              snapshot.activeMomentId == 'b',
        );
        expect(loading, greaterThanOrEqualTo(0));
        expect(transitioning, greaterThan(loading));
        expect(observed[transitioning].activeMomentId, 'a');
        expect(endpoint, greaterThan(transitioning));

        final missing = File(
          '${fixtureDirectory!.path}${Platform.pathSeparator}missing.wav',
        );
        await playback.startMoment(_request('missing', missing.uri));
        expect(playback.snapshot.value.activeMomentId, 'b');
        expect(playback.snapshot.value.playing, isTrue);
        await _waitUntil(
          () => alerts.any(
            (alert) =>
                alert.code == PlaybackAlertCode.sourceFailed &&
                alert.momentId == 'missing',
          ),
        );

        final deleted = await _writeWave(
          File('${fixtureDirectory!.path}${Platform.pathSeparator}deleted.wav'),
          frequencyHz: 880,
        );
        final deletedUri = deleted.uri;
        await deleted.delete();
        await playback.startMoment(_request('deleted', deletedUri));
        expect(playback.snapshot.value.activeMomentId, 'b');
        expect(playback.snapshot.value.playing, isTrue);
        await _waitUntil(
          () => alerts.any(
            (alert) =>
                alert.code == PlaybackAlertCode.sourceFailed &&
                alert.momentId == 'deleted',
          ),
        );

        await playback.setSessionVolumes(
          masterVolume: 0,
          musicVolume: 1,
          narrationVolume: 1,
        );
        expect(playback.snapshot.value.masterVolume, 0);
        expect(playback.snapshot.value.musicVolume, 1);
        expect(playback.snapshot.value.narrationVolume, 1);

        await playback.setSessionVolumes(
          masterVolume: 1,
          musicVolume: 0,
          narrationVolume: 0,
        );
        expect(playback.snapshot.value.masterVolume, 1);
        expect(playback.snapshot.value.musicVolume, 0);
        expect(playback.snapshot.value.narrationVolume, 0);

        await playback.setNarration(true);
        expect(playback.snapshot.value.narrationActive, isTrue);
        expect(playback.snapshot.value.narrationVolume, 0);
        await playback.setNarration(false);
        expect(playback.snapshot.value.narrationActive, isFalse);

        await playback.stop();
        expect(playback.snapshot.value.phase, PlaybackPhase.stopped);
        expect(playback.snapshot.value.activeMomentId, isNull);
        expect(playback.snapshot.value.playing, isFalse);
      } finally {
        playback.snapshot.removeListener(recordSnapshot);
        await alertSubscription.cancel();
      }
    },
  );

  testWidgets('real engine survives 50 crossfades and rapid taps', (_) async {
    final playback = playbackOwner!;
    const stressFade = Duration(milliseconds: 15);
    expect(
      stressFade,
      isNot(Duration.zero),
      reason: 'stress transitions must exercise real non-zero fades',
    );
    final stressSnapshots = <PlaybackSnapshot>[];
    Completer<void>? rapidTransitionStarted;
    void recordStressSnapshot() {
      final snapshot = playback.snapshot.value;
      stressSnapshots.add(snapshot);
      final barrier = rapidTransitionStarted;
      if (barrier != null &&
          !barrier.isCompleted &&
          snapshot.phase == PlaybackPhase.transitioning) {
        barrier.complete();
      }
    }

    playback.snapshot.addListener(recordStressSnapshot);
    try {
      await playback.startMoment(_request('a', audioA.uri, fade: stressFade));

      for (var index = 0; index < 50; index++) {
        final useA = index.isOdd;
        await playback.startMoment(
          _request(
            useA ? 'a' : 'b',
            useA ? audioA.uri : audioB.uri,
            fade: stressFade,
          ),
        );
        expect(playback.snapshot.value.activeMomentId, useA ? 'a' : 'b');
      }
      expect(
        stressSnapshots.any(
          (snapshot) => snapshot.phase == PlaybackPhase.transitioning,
        ),
        isTrue,
      );
      expect(playback.snapshot.value.activeMomentId, 'a');

      rapidTransitionStarted = Completer<void>();
      final initialRapidTransition = playback.startMoment(
        _request(
          'rapid-primer',
          audioB.uri,
          fade: const Duration(milliseconds: 250),
        ),
      );
      await rapidTransitionStarted.future.timeout(const Duration(seconds: 8));
      expect(playback.snapshot.value.phase, PlaybackPhase.transitioning);

      final rapidRequests = <Future<void>>[];
      for (var index = 0; index < 12; index++) {
        final useA = index.isEven;
        rapidRequests.add(
          playback.startMoment(
            _request(
              useA ? 'rapid-a' : 'rapid-b',
              useA ? audioA.uri : audioB.uri,
              fade: const Duration(milliseconds: 100),
            ),
          ),
        );
      }
      await Future.wait([initialRapidTransition, ...rapidRequests]);
      await _waitUntil(
        () => playback.snapshot.value.activeMomentId == 'rapid-b',
      );
      expect(playback.snapshot.value.phase, PlaybackPhase.playing);
      expect(playback.snapshot.value.activeMomentId, 'rapid-b');
    } finally {
      playback.snapshot.removeListener(recordStressSnapshot);
    }
  });
}

MomentPlaybackRequest _request(
  String id,
  Uri uri, {
  Duration fade = const Duration(milliseconds: 200),
}) {
  return MomentPlaybackRequest(
    momentId: id,
    momentName: 'Integration $id',
    uri: uri,
    audioDisplayName: '$id.wav',
    loop: true,
    narrationEnabled: true,
    gainDb: 0,
    fadeIn: fade,
    fadeOut: fade,
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for audio engine state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

Future<File> _writeWave(File file, {required double frequencyHz}) async {
  const sampleRate = 44100;
  const seconds = 3;
  const channels = 1;
  const bitsPerSample = 16;
  const bytesPerSample = bitsPerSample ~/ 8;
  const frameCount = sampleRate * seconds;
  const dataLength = frameCount * channels * bytesPerSample;
  final bytes = ByteData(44 + dataLength);

  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  bytes.setUint16(32, channels * bytesPerSample, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);

  for (var frame = 0; frame < frameCount; frame++) {
    // Integer phase keeps fixture generation deterministic across runs.
    final phase = (frame * frequencyHz * 2 * 3.141592653589793) / sampleRate;
    final sample = (math.sin(phase) * 8000).round();
    bytes.setInt16(44 + (frame * bytesPerSample), sample, Endian.little);
  }
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file;
}
