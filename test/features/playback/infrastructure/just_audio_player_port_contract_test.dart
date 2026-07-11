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

    test('clamps finite volume and maps non-finite values to zero', () async {
      await port.setVolume(-0.25);
      await port.setVolume(0.4);
      await port.setVolume(1.25);
      await port.setVolume(double.nan);
      await port.setVolume(double.infinity);
      await port.setVolume(double.negativeInfinity);

      expect(backend.volumes, [0.0, 0.4, 1.0, 0.0, 0.0, 0.0]);
    });

    test(
      'uses errorStream as canonical for the same load PlayerException',
      () async {
        final cause = PlayerException(7, 'decoder failed', 0);
        backend.nextLoadError = cause;
        final errors = <PlayerPortError>[];
        final subscription = port.errors.listen(errors.add);
        final load = port.load(Uri.parse('content://broken'));
        backend.errorController.add(cause);

        await expectLater(
          load,
          throwsA(
            isA<PlayerPortError>().having(
              (error) => error.cause,
              'cause',
              cause,
            ),
          ),
        );
        await pumpEventQueue();

        expect(errors, hasLength(1));
        expect(errors.single.cause, same(cause));
        await subscription.cancel();
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

    test(
      'superseding and stopping loads cancel every wrapper without errors',
      () async {
        final firstBackendLoad = backend.holdNextLoad();
        final secondBackendLoad = backend.holdNextLoad();
        final errors = <PlayerPortError>[];
        final subscription = port.errors.listen(errors.add);

        final first = port.load(Uri.parse('content://first'));
        final firstCanceled = expectLater(
          first,
          throwsA(
            isA<PlayerPortError>().having(
              (error) => error.cause,
              'cause',
              isA<PlayerInterruptedException>(),
            ),
          ),
        );
        final second = port.load(Uri.parse('content://second'));
        final secondCanceled = expectLater(
          second,
          throwsA(
            isA<PlayerPortError>().having(
              (error) => error.cause,
              'cause',
              isA<PlayerInterruptedException>(),
            ),
          ),
        );

        await port.stop();
        await Future.wait([firstCanceled, secondCanceled]);
        firstBackendLoad.completeError(PlayerInterruptedException('first'));
        secondBackendLoad.completeError(PlayerInterruptedException('second'));
        await pumpEventQueue();

        expect(errors, isEmpty);
        expect(backend.stopCalls, 1);
        await subscription.cancel();
      },
    );

    test('dispose is final and idempotent', () async {
      await port.dispose();
      await port.dispose();

      expect(backend.disposeCalls, 1);
    });

    test(
      'disposing and disposed lifecycle rejects every player command',
      () async {
        final backendDispose = Completer<void>();
        backend.disposeCompleter = backendDispose;

        final disposing = port.dispose();
        await pumpEventQueue();
        expect(backend.disposeCalls, 1);

        Future<void> expectCommandsRejected() async {
          expect(() => port.play(), throwsA(isA<PlayerPortError>()));
          await expectLater(
            port.load(Uri.parse('content://late')),
            throwsA(isA<PlayerPortError>()),
          );
          await expectLater(port.pause(), throwsA(isA<PlayerPortError>()));
          await expectLater(port.stop(), throwsA(isA<PlayerPortError>()));
          await expectLater(
            port.seek(Duration.zero),
            throwsA(isA<PlayerPortError>()),
          );
          await expectLater(
            port.setVolume(0.5),
            throwsA(isA<PlayerPortError>()),
          );
          await expectLater(
            port.setLooping(true),
            throwsA(isA<PlayerPortError>()),
          );
        }

        await expectCommandsRejected();
        expect(backend.commandCalls, 0);

        backendDispose.complete();
        await disposing;
        await expectCommandsRejected();
        expect(backend.commandCalls, 0);
      },
    );

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

    test(
      'uses delayed errorStream after play Future as canonical PlayerException',
      () async {
        final playCompleter = Completer<void>();
        backend.playCompleter = playCompleter;
        final cause = PlayerException(11, 'play failed', 0);
        final errors = <PlayerPortError>[];
        final subscription = port.errors.listen(errors.add);

        port.play();
        playCompleter.completeError(cause);
        await pumpEventQueue(times: 4);
        expect(errors, isEmpty);

        backend.errorController.add(cause);
        await pumpEventQueue();
        expect(errors, hasLength(1));
        expect(errors.single.cause, same(cause));
        await subscription.cancel();
      },
    );

    test(
      'ignores delayed play Future after canonical PlayerException stream',
      () async {
        final playCompleter = Completer<void>();
        backend.playCompleter = playCompleter;
        final cause = PlayerException(12, 'play failed stream first', 0);
        final errors = <PlayerPortError>[];
        final subscription = port.errors.listen(errors.add);

        port.play();
        backend.errorController.add(cause);
        await pumpEventQueue(times: 4);
        expect(errors, hasLength(1));

        playCompleter.completeError(cause);
        await pumpEventQueue();
        expect(errors, hasLength(1));
        expect(errors.single.cause, same(cause));
        await subscription.cancel();
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
  final _controlledLoads = <Completer<Duration?>>[];

  Completer<Duration?>? loadCompleter;
  Completer<void>? playCompleter;
  Completer<void>? disposeCompleter;
  Object? nextLoadError;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int seekCalls = 0;
  int disposeCalls = 0;

  int get commandCalls =>
      audioSources.length +
      playCalls +
      pauseCalls +
      stopCalls +
      seekCalls +
      volumes.length +
      loopModes.length;

  Completer<Duration?> holdNextLoad() {
    final completer = Completer<Duration?>();
    _controlledLoads.add(completer);
    return completer;
  }

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
    if (_controlledLoads.isNotEmpty) {
      return _controlledLoads.removeAt(0).future;
    }
    return loadCompleter?.future ?? Future.value(null);
  }

  @override
  Future<void> play() {
    playCalls++;
    return playCompleter?.future ?? Future.value();
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls++;
  }

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
    await disposeCompleter?.future;
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
