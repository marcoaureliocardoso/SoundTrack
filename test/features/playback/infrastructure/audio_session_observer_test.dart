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

  test('forwards interruption types and activates focus before end', () async {
    final backend = _FakeAudioSessionBackend();
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(
      backend,
      (event) async => events.add(event),
    );
    await observer.start();

    backend.interruptions.add(
      AudioInterruptionEvent(true, AudioInterruptionType.pause),
    );
    backend.interruptions.add(
      AudioInterruptionEvent(false, AudioInterruptionType.pause),
    );
    await _flush();

    expect(events.first, isA<PlaybackInterruptionStarted>());
    expect((events.last as PlaybackInterruptionEnded).focusGranted, isTrue);
    expect(backend.activeRequests, [true]);
    await observer.dispose();
  });

  test('focus failure is contained and forwarded as denied', () async {
    final backend = _FakeAudioSessionBackend()
      ..activeError = StateError('focus');
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(
      backend,
      (event) async => events.add(event),
    );
    await observer.start();

    backend.interruptions.add(
      AudioInterruptionEvent(false, AudioInterruptionType.unknown),
    );
    await _flush();

    expect((events.single as PlaybackInterruptionEnded).focusGranted, isFalse);
    await observer.dispose();
  });

  test('noisy and device events become typed route changes', () async {
    final backend = _FakeAudioSessionBackend();
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(
      backend,
      (event) async => events.add(event),
    );
    await observer.start();

    backend.noisy.add(null);
    backend.devices.add(AudioDevicesChangedEvent());
    await _flush();

    expect(events, everyElement(isA<PlaybackRouteChanged>()));
    await observer.dispose();
  });

  test('stream and callback errors are contained', () async {
    final backend = _FakeAudioSessionBackend();
    var callbacks = 0;
    final observer = AudioSessionObserver(backend, (_) async {
      callbacks++;
      throw StateError('consumer');
    });
    await observer.start();

    backend.noisy.addError(StateError('stream'));
    backend.noisy.add(null);
    await _flush();

    expect(callbacks, 1);
    await observer.dispose();
  });

  test('dispose cancels subscriptions and is idempotent', () async {
    final backend = _FakeAudioSessionBackend();
    final events = <PlaybackSessionEvent>[];
    final observer = AudioSessionObserver(
      backend,
      (event) async => events.add(event),
    );
    await observer.start();

    await Future.wait([observer.dispose(), observer.dispose()]);
    backend.noisy.add(null);
    await _flush();

    expect(events, isEmpty);
    expect(backend.cancelCount, 3);
    await backend.close();
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FakeAudioSessionBackend implements AudioSessionBackend {
  final interruptions = StreamController<AudioInterruptionEvent>.broadcast();
  final noisy = StreamController<void>.broadcast();
  final devices = StreamController<AudioDevicesChangedEvent>.broadcast();
  final configurations = <AudioSessionConfiguration>[];
  final activeRequests = <bool>[];

  Object? activeError;
  var interruptionListenCount = 0;
  var noisyListenCount = 0;
  var devicesListenCount = 0;
  var cancelCount = 0;

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      _counted(interruptions.stream, () => interruptionListenCount++);

  @override
  Stream<void> get becomingNoisyEventStream =>
      _counted(noisy.stream, () => noisyListenCount++);

  @override
  Stream<AudioDevicesChangedEvent> get devicesChangedEventStream =>
      _counted(devices.stream, () => devicesListenCount++);

  Stream<T> _counted<T>(Stream<T> source, void Function() onListen) {
    return source
        .transform(StreamTransformer<T, T>.fromHandlers())
        .asBroadcastStream(
          onListen: (_) => onListen(),
          onCancel: (_) => cancelCount++,
        );
  }

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    configurations.add(configuration);
  }

  @override
  Future<bool> setActive(bool active) async {
    activeRequests.add(active);
    final error = activeError;
    if (error != null) {
      throw error;
    }
    return true;
  }

  Future<void> close() =>
      Future.wait([interruptions.close(), noisy.close(), devices.close()]);
}
