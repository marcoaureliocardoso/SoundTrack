import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:soundtrack/features/playback/application/player_port.dart';
import 'package:soundtrack/features/playback/infrastructure/just_audio_player_port.dart';

void main() {
  group('JustAudioPlayerPort', () {
    late _FakeJustAudioBackend backend;
    late JustAudioPlayerPort port;

    setUp(() {
      backend = _FakeJustAudioBackend();
      port = JustAudioPlayerPort(backend: backend);
    });

    tearDown(() async {
      await port.dispose();
      await backend.closeStreams();
    });

    test('loads content URI as an AudioSource.uri', () async {
      final uri = Uri.parse('content://media/external/audio/media/42');

      await port.load(uri);

      expect(backend.audioSources, hasLength(1));
      expect(backend.audioSources.single, isA<UriAudioSource>());
      expect((backend.audioSources.single as UriAudioSource).uri, uri);
    });

    test('maps looping to LoopMode.one and LoopMode.off', () async {
      await port.setLooping(true);
      await port.setLooping(false);

      expect(backend.loopModes, [LoopMode.one, LoopMode.off]);
    });

    test('clamps volume to the supported zero-to-one range', () async {
      await port.setVolume(-0.25);
      await port.setVolume(0.4);
      await port.setVolume(1.25);

      expect(backend.volumes, [0.0, 0.4, 1.0]);
    });

    test(
      'converts operation failures to PlayerPortError and emits them',
      () async {
        final cause = PlayerException(7, 'decoder failed', 0);
        backend.nextLoadError = cause;
        final emitted = expectLater(port.errors, emits(isA<PlayerPortError>()));

        await expectLater(
          port.load(Uri.parse('content://broken')),
          throwsA(
            isA<PlayerPortError>().having(
              (error) => error.cause,
              'cause',
              cause,
            ),
          ),
        );
        await emitted;
      },
    );

    test('converts backend error stream events to PlayerPortError', () async {
      final cause = PlayerException(9, 'stream failed', 0);
      final emitted = expectLater(
        port.errors,
        emits(
          isA<PlayerPortError>().having((error) => error.cause, 'cause', cause),
        ),
      );

      backend.errorController.add(cause);

      await emitted;
    });

    test('stop releases backend and cancels an in-progress load', () async {
      backend.loadCompleter = Completer<Duration?>();
      final load = port.load(Uri.parse('content://slow'));
      final canceled = expectLater(load, throwsA(isA<PlayerPortError>()));

      await port.stop();

      await canceled;
      expect(backend.stopCalls, 1);
      expect(backend.disposeCalls, 0);
    });

    test('dispose is final and idempotent', () async {
      await port.dispose();
      await port.dispose();

      expect(backend.disposeCalls, 1);
    });

    test(
      'play returns immediately and reports later asynchronous failure',
      () async {
        final playCompleter = Completer<void>();
        backend.playCompleter = playCompleter;
        final cause = StateError('play failed later');
        final emitted = expectLater(
          port.errors,
          emits(
            isA<PlayerPortError>().having(
              (error) => error.cause,
              'cause',
              cause,
            ),
          ),
        );

        port.play();
        expect(backend.playCalls, 1);

        playCompleter.completeError(cause);
        await emitted;
      },
    );

    test('forwards position and duration streams', () async {
      final position = expectLater(
        port.position,
        emits(const Duration(seconds: 12)),
      );
      final duration = expectLater(
        port.duration,
        emits(const Duration(minutes: 3)),
      );

      backend.positionController.add(const Duration(seconds: 12));
      backend.durationController.add(const Duration(minutes: 3));

      await Future.wait([position, duration]);
    });

    test('emits completion only for ProcessingState.completed', () async {
      var completions = 0;
      final subscription = port.completed.listen((_) => completions++);

      backend.processingStateController
        ..add(ProcessingState.loading)
        ..add(ProcessingState.ready);
      await pumpEventQueue();
      expect(completions, 0);

      backend.processingStateController.add(ProcessingState.completed);
      await pumpEventQueue();
      expect(completions, 1);

      await subscription.cancel();
    });
  });
}

final class _FakeJustAudioBackend implements JustAudioBackend {
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration?>.broadcast();
  final processingStateController =
      StreamController<ProcessingState>.broadcast();
  final errorController = StreamController<PlayerException>.broadcast();
  final audioSources = <AudioSource>[];
  final loopModes = <LoopMode>[];
  final volumes = <double>[];

  Completer<Duration?>? loadCompleter;
  Completer<void>? playCompleter;
  Object? nextLoadError;
  int playCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration?> get durationStream => durationController.stream;

  @override
  Stream<ProcessingState> get processingStateStream =>
      processingStateController.stream;

  @override
  Stream<PlayerException> get errorStream => errorController.stream;

  @override
  Future<Duration?> setAudioSource(AudioSource source) {
    audioSources.add(source);
    final error = nextLoadError;
    nextLoadError = null;
    if (error != null) {
      return Future.error(error);
    }
    return loadCompleter?.future ?? Future.value(null);
  }

  @override
  Future<void> play() {
    playCalls++;
    return playCompleter?.future ?? Future.value();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {
    loopModes.add(mode);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  Future<void> closeStreams() async {
    await Future.wait([
      positionController.close(),
      durationController.close(),
      processingStateController.close(),
      errorController.close(),
    ]);
  }
}
