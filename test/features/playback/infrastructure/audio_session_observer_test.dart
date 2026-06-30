import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/playback_coordinator.dart';
import 'package:soundtrack/features/playback/infrastructure/audio_session_observer.dart';

void main() {
  test(
    'start configures music without pause-on-duck and is idempotent',
    () async {
      final backend = _FakeAudioSessionBackend();
      final observer = AudioSessionObserver(backend, (_) async {});

      await Future.wait([observer.start(), observer.start()]);

      expect(backend.configurations, hasLength(1));
      expect(backend.configurations.single.androidWillPauseWhenDucked, isFalse);
      expect(backend.interruptionListenCount, 1);
      expect(backend.noisyListenCount, 1);
      expect(backend.devicesListenCount, 1);
      await observer.dispose();
    },
  );

  test('end forwards lazy focus callback without requesting focus', () async {
    final backend = _FakeAudioSessionBackend();
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(
      backend,
      (event) async => events.add(event),
    );
    await observer.start();

    backend.interruptions.add(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    await _flush();

    expect(backend.activeRequests, isEmpty);
    final end = events.single as PlaybackInterruptionEnded;
    expect(await end.requestFocus(), isTrue);
    expect(backend.activeRequests, [true]);
    await observer.dispose();
  });

  test('serializes platform events in arrival order', () async {
    final backend = _FakeAudioSessionBackend();
    final releaseFirst = Completer<void>();
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(backend, (event) async {
      events.add(event);
      if (events.length == 1) {
        await releaseFirst.future;
      }
    });
    await observer.start();

    backend.interruptions.add(
      AudioInterruptionEvent(true, AudioInterruptionType.pause),
    );
    backend.noisy.add(null);
    backend.devices.add(AudioDevicesChangedEvent());
    await _flush();

    expect(events, hasLength(1));
    releaseFirst.complete();
    await _flush();
    expect(events, [
      isA<PlaybackInterruptionStarted>(),
      isA<PlaybackRouteChanged>(),
      isA<PlaybackRouteChanged>(),
    ]);
    await observer.dispose();
  });

  test('callback failure is contained and queue continues', () async {
    final backend = _FakeAudioSessionBackend();
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(backend, (event) async {
      events.add(event);
      if (events.length == 1) {
        throw StateError('consumer');
      }
    });
    await observer.start();

    backend.noisy.add(null);
    backend.devices.add(AudioDevicesChangedEvent());
    await _flush();

    expect(events, hasLength(2));
    await observer.dispose();
  });

  test('dispose waits for queued event work', () async {
    final backend = _FakeAudioSessionBackend();
    final release = Completer<void>();
    final observer = AudioSessionObserver(backend, (_) => release.future);
    await observer.start();
    backend.noisy.add(null);
    await _flush();

    var disposed = false;
    final disposal = observer.dispose()..then((_) => disposed = true);
    await _flush();
    expect(disposed, isFalse);

    release.complete();
    await disposal;
    expect(disposed, isTrue);
  });

  test('dispose attempts every cancellation and reports first error', () async {
    final backend = _FakeAudioSessionBackend(cancelFailures: {0, 2});
    final observer = AudioSessionObserver(backend, (_) async {});
    await observer.start();

    await expectLater(
      observer.dispose(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'cancel-0',
        ),
      ),
    );

    expect(backend.cancelCount, 3);
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FakeAudioSessionBackend implements AudioSessionBackend {
  _FakeAudioSessionBackend({this.cancelFailures = const {}}) {
    interruptions = _controller<AudioInterruptionEvent>(0);
    noisy = _controller<void>(1);
    devices = _controller<AudioDevicesChangedEvent>(2);
  }

  final Set<int> cancelFailures;
  late final StreamController<AudioInterruptionEvent> interruptions;
  late final StreamController<void> noisy;
  late final StreamController<AudioDevicesChangedEvent> devices;
  final configurations = <AudioSessionConfiguration>[];
  final activeRequests = <bool>[];

  var interruptionListenCount = 0;
  var noisyListenCount = 0;
  var devicesListenCount = 0;
  var cancelCount = 0;

  StreamController<T> _controller<T>(int index) {
    return StreamController<T>.broadcast(
      onListen: () {
        switch (index) {
          case 0:
            interruptionListenCount++;
          case 1:
            noisyListenCount++;
          case 2:
            devicesListenCount++;
        }
      },
    );
  }

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _cancelStream(interruptions.stream, 0);

  @override
  Stream<void> get becomingNoisyEventStream => _cancelStream(noisy.stream, 1);

  @override
  Stream<AudioDevicesChangedEvent> get devicesChangedEventStream =>
      _cancelStream(devices.stream, 2);

  Stream<T> _cancelStream<T>(Stream<T> stream, int index) {
    return _CancelFailingStream<T>(
      stream,
      onCancel: () {
        cancelCount++;
        if (cancelFailures.contains(index)) {
          throw StateError('cancel-$index');
        }
      },
    );
  }

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    configurations.add(configuration);
  }

  @override
  Future<bool> setActive(bool active) async {
    activeRequests.add(active);
    return true;
  }
}

final class _CancelFailingStream<T> extends Stream<T> {
  _CancelFailingStream(this._delegate, {required this.onCancel});

  final Stream<T> _delegate;
  final void Function() onCancel;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _CancelFailingSubscription<T>(
      _delegate.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
      onCancel,
    );
  }
}

final class _CancelFailingSubscription<T> implements StreamSubscription<T> {
  _CancelFailingSubscription(this._delegate, this._onCancel);

  final StreamSubscription<T> _delegate;
  final void Function() _onCancel;

  @override
  Future<void> cancel() async {
    await _delegate.cancel();
    _onCancel();
  }

  @override
  void onData(void Function(T data)? handleData) =>
      _delegate.onData(handleData);

  @override
  void onError(Function? handleError) => _delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);

  @override
  void resume() => _delegate.resume();

  @override
  bool get isPaused => _delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _delegate.asFuture(futureValue);
}
