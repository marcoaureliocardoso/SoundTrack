import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/playback/application/fade_driver.dart';

void main() {
  group('TimerFadeScheduler', () {
    test('emits one immediately for a zero duration', () async {
      final fractions = await const TimerFadeScheduler()
          .fractions(Duration.zero)
          .toList();

      expect(fractions, [1]);
    });

    test('keeps producing fractions while the listener is paused', () async {
      final stopwatch = Stopwatch()..start();
      final fractions = <double>[];
      final done = Completer<void>();
      late final StreamSubscription<double> subscription;

      subscription = const TimerFadeScheduler()
          .fractions(const Duration(milliseconds: 400))
          .listen((fraction) {
            fractions.add(fraction);
            if (fractions.length == 1) {
              subscription.pause(
                Future<void>.delayed(const Duration(milliseconds: 450)),
              );
            }
          }, onDone: done.complete);

      await done.future.timeout(const Duration(seconds: 2));
      stopwatch.stop();

      expect(fractions, hasLength(8));
      expect(fractions.last, 1);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(milliseconds: 700)),
        reason: 'scheduler timing must not include listener backpressure',
      );
    });
  });

  group('FadeDriver', () {
    test('interpolates every scheduled fraction', () async {
      final scheduler = _ManualFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final applied = <double>[];

      final fade = driver.run(
        from: 0.2,
        to: 0.8,
        duration: const Duration(seconds: 1),
        apply: (value) async => applied.add(value),
      );
      scheduler.emit(0.25);
      scheduler.emit(1);
      await scheduler.close();
      await fade;

      expect(applied, closeToList([0.35, 0.8]));
    });

    test('starting a new fade cancels the previous generation', () async {
      final scheduler = _QueuedFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final applied = <double>[];
      var current = 0.0;

      final first = driver.run(
        from: current,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          current = value;
          applied.add(value);
        },
      );
      scheduler.first.emit(0.4);
      await _flushEventQueue();
      expect(current, closeTo(0.4, 0.000001));

      final second = driver.run(
        from: current,
        to: 0,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          current = value;
          applied.add(value);
        },
      );
      scheduler.first.emit(0.8);
      scheduler.second.emit(0.5);
      scheduler.second.emit(1);
      await scheduler.first.close();
      await scheduler.second.close();
      await Future.wait([first, second]);

      expect(applied, closeToList([0.4, 0.2, 0]));
      expect(applied, isNot(contains(closeTo(0.8, 0.000001))));
    });

    test('cancel prevents subsequent fractions from being applied', () async {
      final scheduler = _ManualFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final applied = <double>[];

      final fade = driver.run(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async => applied.add(value),
      );
      scheduler.emit(0.5);
      await _flushEventQueue();

      driver.cancel();
      scheduler.emit(1);
      await scheduler.close();
      await fade;

      expect(applied, [0.5]);
    });

    test('serializes apply callbacks across generations', () async {
      final scheduler = _QueuedFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final firstApplyStarted = Completer<void>();
      final releaseFirstApply = Completer<void>();
      final applied = <String>[];
      var activeCallbacks = 0;
      var maxActiveCallbacks = 0;

      final first = driver.run(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          activeCallbacks++;
          if (activeCallbacks > maxActiveCallbacks) {
            maxActiveCallbacks = activeCallbacks;
          }
          firstApplyStarted.complete();
          await releaseFirstApply.future;
          applied.add('A:$value');
          activeCallbacks--;
        },
      );
      scheduler.first.emit(0.5);
      await firstApplyStarted.future;

      final second = driver.run(
        from: 0.5,
        to: 0,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          activeCallbacks++;
          if (activeCallbacks > maxActiveCallbacks) {
            maxActiveCallbacks = activeCallbacks;
          }
          applied.add('B:$value');
          activeCallbacks--;
        },
      );
      scheduler.second.emit(1);
      await _flushEventQueue();

      final firstClose = scheduler.first.close();
      final secondClose = scheduler.second.close();
      releaseFirstApply.complete();
      await Future.wait([
        first,
        second,
        firstClose,
        secondClose,
      ]).timeout(const Duration(seconds: 1));

      expect(maxActiveCallbacks, 1);
      expect(applied, ['A:0.5', 'B:0.0']);
    });

    test('skips stale apply work that has not started', () async {
      final scheduler = _ThreeFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final firstApplyStarted = Completer<void>();
      final releaseFirstApply = Completer<void>();
      final applied = <String>[];

      final first = driver.run(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async {
          firstApplyStarted.complete();
          await releaseFirstApply.future;
          applied.add('A');
        },
      );
      scheduler.first.emit(0.5);
      await firstApplyStarted.future;

      final second = driver.run(
        from: 0.5,
        to: 0.25,
        duration: const Duration(seconds: 1),
        apply: (value) async => applied.add('B'),
      );
      scheduler.second.emit(1);
      await _flushEventQueue();

      final third = driver.run(
        from: 0.5,
        to: 0,
        duration: const Duration(seconds: 1),
        apply: (value) async => applied.add('C'),
      );
      scheduler.third.emit(1);
      await _flushEventQueue();

      final closes = [
        scheduler.first.close(),
        scheduler.second.close(),
        scheduler.third.close(),
      ];
      releaseFirstApply.complete();
      await Future.wait([
        first,
        second,
        third,
        ...closes,
      ]).timeout(const Duration(seconds: 1));

      expect(applied, ['A', 'C']);
    });

    test('cancel completes a fade whose scheduler stays silent', () async {
      final scheduler = _ManualFadeScheduler();
      final driver = FadeDriver(scheduler: scheduler);
      final fade = driver.run(
        from: 0,
        to: 1,
        duration: const Duration(seconds: 1),
        apply: (value) async {},
      );

      driver.cancel();

      try {
        await expectLater(
          fade.timeout(const Duration(milliseconds: 200)),
          completes,
        );
        expect(scheduler.hasListener, isFalse);
      } finally {
        await scheduler.close();
      }
    });
  });
}

Matcher closeToList(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (actual, expected) => (actual - expected).abs() < 0.000001,
  'approximately equals',
);

Future<void> _flushEventQueue() => Future<void>.delayed(Duration.zero);

class _ManualFadeScheduler implements FadeScheduler {
  final _controller = StreamController<double>();

  bool get hasListener => _controller.hasListener;

  @override
  Stream<double> fractions(Duration duration) => _controller.stream;

  void emit(double fraction) => _controller.add(fraction);

  Future<void> close() => _controller.close();
}

class _QueuedFadeScheduler implements FadeScheduler {
  final first = _ManualFadeScheduler();
  final second = _ManualFadeScheduler();
  var _calls = 0;

  @override
  Stream<double> fractions(Duration duration) {
    _calls++;
    return _calls == 1 ? first.fractions(duration) : second.fractions(duration);
  }
}

class _ThreeFadeScheduler implements FadeScheduler {
  final first = _ManualFadeScheduler();
  final second = _ManualFadeScheduler();
  final third = _ManualFadeScheduler();
  var _calls = 0;

  @override
  Stream<double> fractions(Duration duration) {
    _calls++;
    return switch (_calls) {
      1 => first.fractions(duration),
      2 => second.fractions(duration),
      _ => third.fractions(duration),
    };
  }
}
